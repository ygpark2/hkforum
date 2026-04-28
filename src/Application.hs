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
                                             companyMinorCategoryName,
                                             companyMinorCategorySortOrder,
                                             loadAllCompanyMinorCategories)
import Database.Persist.Postgresql          (createPostgresqlPool)
import Database.Persist.Sql                 (Single (..), rawExecute, rawSql,
                                             runSqlPool)
import Database.Persist.Sqlite              (SqliteConf (..), createSqlitePool)
import Import hiding ((.), (++))
import qualified Prelude as P
import Language.Haskell.TH.Syntax           (qLocation)
import Network.Wai.Handler.Warp             (Settings, defaultSettings,
                                             defaultShouldDisplayException,
                                             runSettings, setHost,
                                             setOnException, setPort, getPort)
import qualified Network.Wai               as Wai
import Network.Wai.Middleware.RequestLogger (Destination (Logger),
                                             IPAddrSource (..),
                                             OutputFormat (..), destination,
                                             mkRequestLogger, outputFormat)
import qualified Data.Text as T
import System.Directory                    (createDirectoryIfMissing, doesFileExist,
                                             makeAbsolute)
import System.Environment                  (lookupEnv, setEnv)
import System.FilePath                     (takeDirectory, takeExtension)
import System.Log.FastLogger                (defaultBufSize, newStdoutLoggerSet,
                                             toLogStr)

-- Import all relevant handler modules here.
-- Don't forget to add new modules to your cabal file!
import Handler.Upload
import Handler.Root
import Handler.Api
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

    pool <-
        case appDatabaseConf appSettings of
            AppDatabaseSqlite sqliteConf -> do
                let rawDbPath = unpack $ sqlDatabase sqliteConf
                absDbPath <- makeAbsolute rawDbPath
                let dbDir = takeDirectory absDbPath
                    dbText = pack absDbPath
                when (dbDir /= "." && dbDir /= "") $
                    createDirectoryIfMissing True dbDir
                flip runLoggingT logFunc $
                    $(logInfo) $ "Using SQLite database at: " <> pack absDbPath
                flip runLoggingT logFunc $
                    createSqlitePool dbText (sqlPoolSize sqliteConf)
            AppDatabasePostgres postgresConf -> do
                flip runLoggingT logFunc $
                    $(logInfo) $ "Using PostgreSQL database with pool size " <> tshow (appPostgresPoolSize postgresConf)
                flip runLoggingT logFunc $
                    createPostgresqlPool (Import.encodeUtf8 $ appPostgresConnStr postgresConf) (appPostgresPoolSize postgresConf)

    companyMinorCategories <- loadAllCompanyMinorCategories
    -- Perform database migration using our application's logging settings.
    runLoggingT
        ( runSqlPool
            ( prepareCompanyGroupSchemaForCodeNotNull (appDatabaseConf appSettings) companyMinorCategories
                >> runMigration migrateAll
                >> migrateLegacySiteTemplate
                >> ensureOperationalIndexes
            )
            pool
        )
        logFunc

    -- Return the foundation
    return $ mkFoundation pool

migrateLegacySiteTemplate :: SqlPersistT (LoggingT IO) ()
migrateLegacySiteTemplate =
    updateWhere
        [ SiteSettingKey ==. "site_template"
        , SiteSettingValue ==. "anz"
        ]
        [ SiteSettingValue =. "base"
        ]

ensureOperationalIndexes :: SqlPersistT (LoggingT IO) ()
ensureOperationalIndexes = do
    rawExecute "CREATE INDEX IF NOT EXISTS idx_job_created_at ON job (created_at)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_job_deadline ON job (deadline)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_job_company_ref ON job (company_ref)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_job_employment_type ON job (employment_type)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_job_workplace_type ON job (workplace_type)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_job_seniority ON job (seniority)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_job_skill_name ON job_skill (name)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_job_application_job_status ON job_application (job, status)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_job_application_applicant ON job_application (applicant)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_job_application_created_at ON job_application (created_at)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_listing_created_at ON real_estate_listing (created_at)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_listing_type ON real_estate_listing (listing_type)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_property_type ON real_estate_listing (property_type)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_status ON real_estate_listing (status)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_country_state ON real_estate_listing (country_code, state)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_price ON real_estate_listing (price)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_bedrooms ON real_estate_listing (bedrooms)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_feature_name ON real_estate_feature (name)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_inquiry_listing_status ON real_estate_inquiry (listing, status)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_report_listing_status ON real_estate_report (listing, status)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_report_created_at ON real_estate_report (created_at)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_real_estate_agent_profile_user ON real_estate_agent_profile (user)" []
    rawExecute "CREATE INDEX IF NOT EXISTS idx_company_name ON company (name)" []

prepareCompanyGroupSchemaForCodeNotNull :: AppDatabaseConf -> [CompanyMinorCategory] -> SqlPersistT (LoggingT IO) ()
prepareCompanyGroupSchemaForCodeNotNull (AppDatabaseSqlite _) companyMinorCategories = do
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
prepareCompanyGroupSchemaForCodeNotNull (AppDatabasePostgres _) companyMinorCategories = do
    tableRows <- rawSql "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'company_group'" []
    when (not (null (tableRows :: [Single Text]))) $ do
        columns <- rawSql "SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'company_group'" []
        let columnNames = map unSingle (columns :: [Single Text])
            hasColumn columnName = columnName `elem` columnNames
        unless (hasColumn "code") $
            rawExecute "ALTER TABLE company_group ADD COLUMN code VARCHAR NULL" []
        unless (hasColumn "major_code") $
            rawExecute "ALTER TABLE company_group ADD COLUMN major_code VARCHAR NULL" []
        unless (hasColumn "sort_order") $
            rawExecute "ALTER TABLE company_group ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0" []
        unless (hasColumn "is_system") $
            rawExecute "ALTER TABLE company_group ADD COLUMN is_system BOOLEAN NOT NULL DEFAULT FALSE" []
        rawBackfillLegacySystemCompanyGroupCodes companyMinorCategories
        missingRows <- rawSql "SELECT name FROM company_group WHERE code IS NULL OR TRIM(code) = '' ORDER BY name" []
        unless (null (missingRows :: [Single Text])) $
            error $
                "CompanyGroup code is required before NOT NULL migration. Missing codes for: "
                    <> unpack (T.intercalate ", " (map unSingle (missingRows :: [Single Text])))

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
    return $ logWare $ defaultMiddlewaresNoLogging $ frontendFallbackApp foundation appPlain

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
    envExists <- doesFileExist ".env"
    when envExists $ do
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
                when (not (T.null key) && not (T.null rest)) $ do
                    let envKey = T.unpack key
                    existing <- lookupEnv envKey
                    when (isNothing existing) $
                        setEnv envKey (T.unpack $ stripQuotes $ T.strip value)
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

frontendFallbackApp :: App -> Wai.Application -> Wai.Application
frontendFallbackApp foundation appPlain req respond
    | isFrontendAssetRequest req = do
        let assetPath =
                P.foldl
                    (</>)
                    (appStaticDir settings </> "app")
                    (map unpack (Wai.pathInfo req))
        assetExists <- doesFileExist assetPath
        if assetExists
            then
                respond $
                    Wai.responseFile
                        status200
                        [(hContentType, mimeTypeFor assetPath)]
                        assetPath
                        Nothing
            else appPlain req respond
    | shouldServeFrontendShell req = do
        let appHtmlPath = appStaticDir settings </> "app" </> "app.html"
        appHtmlExists <- doesFileExist appHtmlPath
        if appHtmlExists
            then
                respond $
                    Wai.responseFile
                        status200
                        [ (hContentType, "text/html; charset=utf-8")
                        , (hCacheControl, "no-store")
                        ]
                        appHtmlPath
                        Nothing
            else appPlain req respond
    | otherwise = appPlain req respond
  where
    settings = appSettings foundation

isFrontendAssetRequest :: Wai.Request -> Bool
isFrontendAssetRequest req =
    Wai.requestMethod req `elem` ["GET", "HEAD"]
        && case Wai.pathInfo req of
            ("_app":_) -> True
            _ -> False

shouldServeFrontendShell :: Wai.Request -> Bool
shouldServeFrontendShell req =
    Wai.requestMethod req `elem` ["GET", "HEAD"]
        && case Wai.pathInfo req of
            [] -> True
            ("_app":_) -> False
            ("api":_) -> False
            ("auth":_) -> False
            ("files":_) -> False
            ("static":_) -> False
            ["favicon.ico"] -> False
            ["robots.txt"] -> False
            _ -> True

mimeTypeFor :: FilePath -> ByteString
mimeTypeFor filePath =
    case takeExtension filePath of
        ".js" -> "application/javascript; charset=utf-8"
        ".css" -> "text/css; charset=utf-8"
        ".json" -> "application/json; charset=utf-8"
        ".map" -> "application/json; charset=utf-8"
        ".svg" -> "image/svg+xml"
        ".png" -> "image/png"
        ".jpg" -> "image/jpeg"
        ".jpeg" -> "image/jpeg"
        ".webp" -> "image/webp"
        ".woff" -> "font/woff"
        ".woff2" -> "font/woff2"
        _ -> "application/octet-stream"
