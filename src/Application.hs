{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE TemplateHaskell, ViewPatterns, RecordWildCards #-}
module Application
    ( getApplicationDev
    , appMain
    , develMain
    , makeFoundation
    -- * for DevelMain
    , getApplicationRepl
    , shutdownApp
    -- * for GHCI
    , handler
    , db
    ) where

import Control.Monad.Logger                 (LoggingT, liftLoc, runLoggingT)
import Company.Categories                   (CompanyMinorCategory, companyMinorCategoryCode,
                                             companyMinorCategoryMajorCode,
                                             companyMinorCategoryMajorName, companyMinorCategoryName,
                                             companyMinorCategorySortOrder,
                                             loadAllCompanyMinorCategories)
import Location.Regions                     (CountrySeed (..), CountryStateSeed (..),
                                             countrySeedsForSuffixes,
                                             countryStateSeedsForSuffixes)
import Data.Int                             (Int64)
import Database.Persist.Sql                 (Single (..), rawExecute, rawSql)
import Database.Persist.Sqlite              (createSqlitePool, runSqlPool,
                                             sqlDatabase, sqlPoolSize)
import Import hiding ((.), (++))
import qualified Prelude as P
import Yesod.Auth.HashDB                    (setPassword)
import Language.Haskell.TH.Syntax           (qLocation)
import Network.Wai.Handler.Warp             (Settings, defaultSettings,
                                             defaultShouldDisplayException,
                                             runSettings, setHost,
                                             setOnException, setPort, getPort)
import Network.Wai.Middleware.RequestLogger (Destination (Logger),
                                             IPAddrSource (..),
                                             OutputFormat (..), destination,
                                             mkRequestLogger, outputFormat)
import qualified Data.Text as T
import System.Directory                    (createDirectoryIfMissing, doesFileExist,
                                             makeAbsolute)
import System.Environment                  (setEnv)
import System.FilePath                     (takeDirectory)
import System.Log.FastLogger                (defaultBufSize, newStdoutLoggerSet,
                                             toLogStr)

-- Import all relevant handler modules here.
-- Don't forget to add new modules to your cabal file!
import Handler.Common
import Handler.Forum.Boards
import Handler.Company.Companies
import Handler.Home
import Handler.Job.Jobs
import Handler.Map
import Handler.Chat.Chats
import Handler.Notification.Notifications
import Handler.Forum.Bookmarks
import Handler.Forum.Settings
import Handler.User.User
import Handler.Forum.Board
import Handler.Forum.Comment
import Handler.Forum.Post
import Handler.Upload
import Handler.Register
import Handler.Admin
import Handler.User.Profile
import Storage (mkStorage, storageBackendType)

-- This line actually creates our YesodDispatch instance. It is the second half
-- of the call to mkYesodData which occurs in Foundation.hs. Please see the
-- comments there for more details.
mkYesodDispatch "App" resourcesApp

-- | This function allocates resources (such as a database connection pool),
-- performs initialization and returns a foundation datatype value. This is also
-- the place to put your migrate statements to have automatic database
-- migrations handled by Yesod.
makeFoundation :: AppSettings -> IO App
makeFoundation appSettings = do
    -- Some basic initializations: HTTP connection manager, logger, and static
    -- subsite.
    appHttpManager <- newManager
    appLogger <- newStdoutLoggerSet defaultBufSize >>= makeYesodLogger
    appStatic <-
        (if appMutableStatic appSettings then staticDevel else static)
        (appStaticDir appSettings)
    appStorage <- mkStorage appSettings
    let appStorageBackendType = storageBackendType appStorage

    -- We need a log function to create a connection pool. We need a connection
    -- pool to create our foundation. And we need our foundation to get a
    -- logging function. To get out of this loop, we initially create a
    -- temporary foundation without a real connection pool, get a log function
    -- from there, and then create the real foundation.
    let mkFoundation appConnPool = App {..}
        -- The App {..} syntax is an example of record wild cards. For more
        -- information, see:
        -- https://ocharles.org.uk/blog/posts/2014-12-04-record-wildcards.html
        tempFoundation = mkFoundation $ error "connPool forced in tempFoundation"
        logFunc = messageLoggerSource tempFoundation appLogger

    let rawDbPath = unpack $ sqlDatabase $ appDatabaseConf appSettings
    absDbPath <- makeAbsolute rawDbPath
    let dbDir = takeDirectory absDbPath
        dbConf = (appDatabaseConf appSettings) { sqlDatabase = pack absDbPath }
    when (dbDir /= "." && dbDir /= "") $
        createDirectoryIfMissing True dbDir
    flip runLoggingT logFunc $
        $(logInfo) $ "Using SQLite database at: " <> pack absDbPath

    -- Create the database connection pool
    pool <- flip runLoggingT logFunc $ createSqlitePool
        (sqlDatabase dbConf)
        (sqlPoolSize dbConf)

    companyMinorCategories <- loadAllCompanyMinorCategories
    let locationSeedSuffixes = appLocationRegionSeedSuffixes appSettings
    countries <-
        case countrySeedsForSuffixes locationSeedSuffixes of
            Left err -> error (unpack err)
            Right values -> pure values
    states <-
        case countryStateSeedsForSuffixes locationSeedSuffixes of
            Left err -> error (unpack err)
            Right values -> pure values

    -- Perform database migration using our application's logging settings.
    runLoggingT
        ( runSqlPool
            (prepareCompanyGroupSchemaForCodeNotNull companyMinorCategories >> runMigration migrateAll >> seedDefaults companyMinorCategories countries states)
            pool
        )
        logFunc

    -- Return the foundation
    return $ mkFoundation pool

seedDefaults :: [CompanyMinorCategory] -> [CountrySeed] -> [CountryStateSeed] -> SqlPersistT (LoggingT IO) ()
seedDefaults companyMinorCategories countries states = do
    void $ insertBy $ Board "general" (Just "General discussion") 0 0
    adminId <- seedAdmin
    seedCountries countries
    seedCountryStates states
    seedSystemCompanyGroups companyMinorCategories adminId
    ensureAllCompanyGroupsHaveCodes

seedCountries :: [CountrySeed] -> SqlPersistT (LoggingT IO) ()
seedCountries countries =
    forM_ countries $ \country ->
        void $
            upsertBy
            (UniqueCountryCode (countrySeedCode country))
            (Country
                (countrySeedCode country)
                (countrySeedName country)
                (countrySeedLocalName country)
                (countrySeedSortOrder country)
            )
            [ CountryName =. countrySeedName country
            , CountryLocalName =. countrySeedLocalName country
            , CountrySortOrder =. countrySeedSortOrder country
            ]

seedCountryStates :: [CountryStateSeed] -> SqlPersistT (LoggingT IO) ()
seedCountryStates states =
    forM_ states $ \stateSeed ->
        void $
            upsertBy
            (UniqueCountryStateCode (countryStateSeedCountryCode stateSeed) (countryStateSeedCode stateSeed))
            (CountryState
                (countryStateSeedCountryCode stateSeed)
                (countryStateSeedCode stateSeed)
                (countryStateSeedName stateSeed)
                (countryStateSeedLocalName stateSeed)
                (countryStateSeedType stateSeed)
                (countryStateSeedSortOrder stateSeed)
            )
            [ CountryStateName =. countryStateSeedName stateSeed
            , CountryStateLocalName =. countryStateSeedLocalName stateSeed
            , CountryStateStateType =. countryStateSeedType stateSeed
            , CountryStateSortOrder =. countryStateSeedSortOrder stateSeed
            ]

prepareCompanyGroupSchemaForCodeNotNull :: [CompanyMinorCategory] -> SqlPersistT (LoggingT IO) ()
prepareCompanyGroupSchemaForCodeNotNull companyMinorCategories = do
    tableRows <- rawSql "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'company_group'" []
    when (not (null (tableRows :: [Single Text]))) $ do
        columns <- rawSql "SELECT name FROM pragma_table_info('company_group')" []
        let columnNames = map unSingle (columns :: [Single Text])
            hasColumn columnName = columnName `elem` columnNames
        unless (hasColumn "code") $
            rawExecute "ALTER TABLE company_group ADD COLUMN code VARCHAR NULL" []
        unless (hasColumn "major_code") $
            rawExecute "ALTER TABLE company_group ADD COLUMN major_code VARCHAR NULL" []
        unless (hasColumn "sort_order") $
            rawExecute "ALTER TABLE company_group ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0" []
        unless (hasColumn "is_system") $
            rawExecute "ALTER TABLE company_group ADD COLUMN is_system BOOLEAN NOT NULL DEFAULT 0" []
        rawBackfillLegacySystemCompanyGroupCodes companyMinorCategories
        missingRows <- rawSql "SELECT name FROM company_group WHERE code IS NULL OR TRIM(code) = '' ORDER BY name" []
        unless (null (missingRows :: [Single Text])) $
            error $
                "CompanyGroup code is required before NOT NULL migration. Missing codes for: "
                    <> unpack (T.intercalate ", " (map unSingle (missingRows :: [Single Text])))

seedAdmin :: SqlPersistT (LoggingT IO) UserId
seedAdmin = do
    mUser <- getBy $ UniqueUser "ygpark2"
    case mUser of
        Just (Entity userId _) -> do
            update userId [UserRole =. "admin"]
            pure userId
        Nothing -> do
            user <- liftIO $ setPassword "1234" (User "ygpark2" Nothing "admin" Nothing Nothing Nothing Nothing False Nothing Nothing)
            insert user

seedSystemCompanyGroups :: [CompanyMinorCategory] -> UserId -> SqlPersistT (LoggingT IO) ()
seedSystemCompanyGroups companyMinorCategories adminId = do
    now <- liftIO getCurrentTime
    backfillLegacySystemCompanyGroupCodes companyMinorCategories
    forM_ companyMinorCategories $ \minor ->
        upsertSystemCompanyGroup adminId now minor

backfillLegacySystemCompanyGroupCodes :: [CompanyMinorCategory] -> SqlPersistT (LoggingT IO) ()
backfillLegacySystemCompanyGroupCodes companyMinorCategories =
    forM_ companyMinorCategories $ \minor -> do
        let name = companyMinorCategoryName minor
            code = companyMinorCategoryCode minor
        existingRows <- selectList [CompanyGroupName ==. name, CompanyGroupCode ==. ""] []
        forM_ existingRows $ \(Entity companyGroupId _) ->
            update companyGroupId
                [ CompanyGroupCode =. code
                , CompanyGroupMajorCode =. Just (companyMinorCategoryMajorCode minor)
                , CompanyGroupSortOrder =. companyMinorCategorySortOrder minor
                , CompanyGroupIsSystem =. True
                ]

ensureAllCompanyGroupsHaveCodes :: SqlPersistT (LoggingT IO) ()
ensureAllCompanyGroupsHaveCodes = do
    badRows <- selectList [CompanyGroupCode ==. ""] [Asc CompanyGroupName]
    unless (null badRows) $
        error $
            "CompanyGroup code is required. Missing codes for: "
                <> unpack (T.intercalate ", " (map (companyGroupName P.. entityVal) badRows))

rawBackfillLegacySystemCompanyGroupCodes :: [CompanyMinorCategory] -> SqlPersistT (LoggingT IO) ()
rawBackfillLegacySystemCompanyGroupCodes companyMinorCategories =
    forM_ companyMinorCategories $ \minor ->
        rawExecute
            "UPDATE company_group SET code = ?, major_code = ?, sort_order = ?, is_system = 1 WHERE name = ? AND (code IS NULL OR TRIM(code) = '')"
            [ toPersistValue (companyMinorCategoryCode minor)
            , toPersistValue (companyMinorCategoryMajorCode minor)
            , toPersistValue (fromIntegral (companyMinorCategorySortOrder minor) :: Int64)
            , toPersistValue (companyMinorCategoryName minor)
            ]

upsertSystemCompanyGroup :: UserId -> UTCTime -> CompanyMinorCategory -> SqlPersistT (LoggingT IO) ()
upsertSystemCompanyGroup adminId now minor = do
    let code = companyMinorCategoryCode minor
        name = companyMinorCategoryName minor
        description = Just ("대분류: " <> companyMinorCategoryMajorName minor)
        applySystemCategoryUpdate companyGroupId =
            update companyGroupId
                [ CompanyGroupName =. name
                , CompanyGroupDescription =. description
                , CompanyGroupCode =. code
                , CompanyGroupMajorCode =. Just (companyMinorCategoryMajorCode minor)
                , CompanyGroupSortOrder =. companyMinorCategorySortOrder minor
                , CompanyGroupIsSystem =. True
                ]
    mExisting <- getBy $ UniqueCompanyGroupCode code
    case mExisting of
        Just (Entity companyGroupId _) -> do
            applySystemCategoryUpdate companyGroupId
        Nothing ->
            void $ insert $
                CompanyGroup
                    name
                    description
                    adminId
                    now
                    code
                    (Just (companyMinorCategoryMajorCode minor))
                    (companyMinorCategorySortOrder minor)
                    True


-- | Convert our foundation to a WAI Application by calling @toWaiAppPlain@ and
-- applying some additional middlewares.
makeApplication :: App -> IO Application
makeApplication foundation = do
    logWare <- mkRequestLogger def
        { outputFormat =
            if appDetailedRequestLogging $ appSettings foundation
                then Detailed True
                else Apache
                        (if appIpFromHeader $ appSettings foundation
                            then FromFallback
                            else FromSocket)
        , destination = Logger $ loggerSet $ appLogger foundation
        }

    -- Create the WAI application and apply middlewares
    appPlain <- toWaiAppPlain foundation
    return $ logWare $ defaultMiddlewaresNoLogging appPlain

-- | Warp settings for the given foundation value.
warpSettings :: App -> Settings
warpSettings foundation =
      setPort (appPort $ appSettings foundation)
    $ setHost (appHost $ appSettings foundation)
    $ setOnException (\_req e ->
        when (defaultShouldDisplayException e) $ messageLoggerSource
            foundation
            (appLogger foundation)
            $(qLocation >>= liftLoc)
            "yesod"
            LevelError
            (toLogStr $ "Exception from Warp: " P.++ show e))
      defaultSettings

-- | For yesod devel, return the Warp settings and WAI Application.
getApplicationDev :: IO (Settings, Application)
getApplicationDev = do
    settings <- getAppSettings
    foundation <- makeFoundation settings
    wsettings <- getDevSettings $ warpSettings foundation
    app <- makeApplication foundation
    return (wsettings, app)

getAppSettings :: IO AppSettings
getAppSettings = do
    loadDotenv
    loadYamlSettings [configSettingsYml] [] useEnv

-- | main function for use by yesod devel
develMain :: IO ()
develMain = develMainHelper getApplicationDev

-- | The @main@ function for an executable running this site.
appMain :: IO ()
appMain = do
    loadDotenv
    -- Get the settings from all relevant sources
    settings <- loadYamlSettingsArgs
        -- fall back to compile-time values, set to [] to require values at runtime
        [configSettingsYmlValue]

        -- allow environment variables to override
        useEnv

    -- Generate the foundation from the settings
    foundation <- makeFoundation settings

    -- Generate a WAI Application from the foundation
    app <- makeApplication foundation

    -- Run the application with Warp
    runSettings (warpSettings foundation) app

loadDotenv :: IO ()
loadDotenv = do
    exists <- doesFileExist ".env"
    when exists $ do
        contents <- readFile ".env"
        forM_ (T.lines $ decodeUtf8 contents) $ \rawLine -> do
            let line = T.strip rawLine
            when (not (T.null line) && T.head line /= '#') $ do
                let line' =
                        if "export " `T.isPrefixOf` line
                            then T.drop 7 line
                            else line
                    (key, rest) = T.breakOn "=" line'
                    value = T.drop 1 rest
                when (not (T.null key) && not (T.null rest)) $
                    setEnv (T.unpack key) (T.unpack $ stripQuotes $ T.strip value)
  where
    stripQuotes s =
        case T.uncons s of
            Just ('"', xs) | not (T.null xs) && T.last xs == '"' -> T.init xs
            Just ('\'', xs) | not (T.null xs) && T.last xs == '\'' -> T.init xs
            _ -> s


--------------------------------------------------------------
-- Functions for DevelMain.hs (a way to run the app from GHCi)
--------------------------------------------------------------
getApplicationRepl :: IO (Int, App, Application)
getApplicationRepl = do
    settings <- getAppSettings
    foundation <- makeFoundation settings
    wsettings <- getDevSettings $ warpSettings foundation
    app1 <- makeApplication foundation
    return (getPort wsettings, foundation, app1)

shutdownApp :: App -> IO ()
shutdownApp _ = return ()


---------------------------------------------
-- Functions for use in development with GHCi
---------------------------------------------

-- | Run a handler
handler :: Handler a -> IO a
handler h = getAppSettings >>= makeFoundation >>= flip unsafeHandler h

-- | Run DB queries
db :: ReaderT SqlBackend (HandlerFor App) a -> IO a
db = handler P.. runDB
