{-# LANGUAGE TemplateHaskell, QuasiQuotes, OverloadedStrings, MultiParamTypeClasses, TypeFamilies, GADTs, ViewPatterns #-}
module Foundation where

import Import.NoFoundation hiding ((.), (++))
import qualified Prelude as P
import Auth.Jwt (bearerTokenFromHeader, verifyJwt)
import Database.Persist.Sql (ConnectionPool, runSqlPool, toSqlKey)
import Text.Jasmine         (minifym)
import Yesod.Auth.HashDB     (HashDBUser(..), authHashDB)
import Yesod.Auth.OAuth2.Google (oauth2Google)
import Auth.OAuth2Providers  (oauth2Kakao, oauth2Naver)
import Yesod.Default.Util   (addStaticContentExternal)
import SiteSettings
import Storage              (Storage, StorageBackendType(..))

import Yesod.Core.Types     (Logger)
import qualified Yesod.Core.Unsafe as Unsafe

-- | The foundation datatype for your application. This can be a good place to
-- keep settings and values requiring initialization before your application
-- starts running, such as database connections. Every handler will have
-- access to the data present here.
data App = App
    { appSettings    :: AppSettings
    , appStatic      :: Static -- ^ Settings for static file serving.
    , appConnPool    :: ConnectionPool -- ^ Database connection pool.
    , appHttpManager :: Manager
    , appLogger      :: Logger
    , appStorage     :: Storage App
    , appStorageBackendType :: StorageBackendType
    }

instance HasHttpManager App where
    getHttpManager = appHttpManager

-- This is where we define all of the routes in our application. For a full
-- explanation of the syntax, please see:
-- http://www.yesodweb.com/book/routing-and-handlers
--
-- Note that this is really half the story; in Application.hs, mkYesodDispatch
-- generates the rest of the code. Please see the linked documentation for an
-- explanation for this split.
--
-- This function also generates the following type synonyms:
-- type Handler = HandlerT App IO
-- type Widget = WidgetT App IO ()
mkYesodData "App" $(parseRoutesFile "config/routes")

-- | A convenient synonym for creating forms.
type Form x = Html -> MForm (HandlerT App IO) (FormResult x, Widget)

-- Please see the documentation for the Yesod typeclass. There are a number
-- of settings which can be configured by overriding methods here.
instance Yesod App where
    -- Controls the base of generated URLs. For more information on modifying,
    -- see: https://github.com/yesodweb/yesod/wiki/Overriding-approot
    approot = ApprootMaster $ appRoot P.. appSettings

    defaultLayout widget = do
        mmsg <- getMessage
        pc <- widgetToPageContent $ do
            widget
        withUrlRenderer
            [hamlet|
$doctype 5
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>HKForum
        ^{pageHead pc}
    <body>
        $maybe msg <- mmsg
            <p>#{msg}
        ^{pageBody pc}
|]

    -- Store session data on the client in encrypted cookies,
    -- default session idle timeout is 120 minutes
    makeSessionBackend _ = Just <$> defaultClientSessionBackend
        120    -- timeout in minutes
        "config/client_session_key.aes"

    -- The page to be redirected to when authentication is required.
    authRoute _ = Just (AuthR LoginR)

    isAuthorized route _ = do
        settingRows <- runDB $ selectList [] []
        mUserId <- maybeSessionOrJwtAuthId
        mViewer <-
            case mUserId of
                Nothing -> pure Nothing
                Just userId -> runDB $ get userId
        let settingMap = siteSettingMapFromEntities settingRows
            maintenanceMode = siteSettingBool "maintenance_mode" False settingMap
            maintenanceMessage = siteSettingText "maintenance_message" "The site is temporarily in maintenance mode." settingMap
            viewerIsAdmin = maybe False (\user -> userRole user == ("admin" :: Text)) mViewer
        if maintenanceMode && not viewerIsAdmin && not (isMaintenanceExemptRoute route)
            then return $ Unauthorized maintenanceMessage
            else return Authorized

    -- This function creates static content files in the static folder
    -- and names them based on a hash of their content. This allows
    -- expiration dates to be set far in the future without worry of
    -- users receiving stale content.
    addStaticContent ext mime content = do
        master <- getYesod
        let staticDir = appStaticDir $ appSettings master
        addStaticContentExternal
            minifym
            genFileName
            staticDir
            (StaticR P.. flip StaticRoute [])
            ext
            mime
            content
      where
        -- Generate a unique filename based on the content itself
        genFileName lbs = "autogen-" P.++ base64md5 lbs

    makeLogger = return P.. appLogger

-- How to run database actions.
instance YesodPersist App where
    type YesodPersistBackend App = SqlBackend
    runDB action = do
        master <- getYesod
        runSqlPool action $ appConnPool master
instance YesodPersistRunner App where
    getDBRunner = defaultGetDBRunner appConnPool

instance YesodAuth App where
    type AuthId App = UserId
    loginDest _ = RootR
    logoutDest _ = RootR
    redirectToReferer _ = False
    authHttpManager = getYesod >>= return P.. getHttpManager

    authLayout widget = do
        liftHandler $ defaultLayout widget

    authPlugins app =
        [authHashDB (Just P.. UniqueUser)]
        P.++ oauthPlugin oauth2Google appGoogleClientId appGoogleClientSecret
        P.++ oauthPlugin oauth2Kakao appKakaoClientId appKakaoClientSecret
        P.++ oauthPlugin oauth2Naver appNaverClientId appNaverClientSecret
      where
        settings = appSettings app
        oauthPlugin plugin getId getSecret =
            case (getId settings, getSecret settings) of
                (Just clientId, Just clientSecret) -> [plugin clientId clientSecret]
                _ -> []

    authenticate creds = liftHandler $ runDB $ do
        let ident =
                if credsPlugin creds == "hashdb"
                    then credsIdent creds
                    else credsPlugin creds <> ":" <> credsIdent creds
        mUser <- getBy $ UniqueUser ident
        case mUser of
            Just (Entity userId _) -> return $ Authenticated userId
            Nothing ->
                Authenticated <$> insert
                    (User ident Nothing "user" Nothing Nothing Nothing Nothing False Nothing Nothing Nothing)

instance YesodAuthPersist App where
    type AuthEntity App = User

instance HashDBUser User where
    userPasswordHash = userPassword
    setPasswordHash p u = u { userPassword = Just p }

isMaintenanceExemptRoute :: Route App -> Bool
isMaintenanceExemptRoute route = case route of
    AuthR _ -> True
    RootR -> True
    FaviconR -> True
    RobotsR -> True
    _ -> False


-- This instance is required to use forms. You can modify renderMessage to
-- achieve customized and internationalized form validation messages.
instance RenderMessage App FormMessage where
    renderMessage _ _ = defaultFormMessage

unsafeHandler :: App -> Handler a -> IO a
unsafeHandler = Unsafe.fakeHandlerGetLogger appLogger

maybeSessionOrJwtAuthId :: Handler (Maybe UserId)
maybeSessionOrJwtAuthId = do
    mSessionUserId <- maybeAuthId
    case mSessionUserId of
        Just userId -> pure (Just userId)
        Nothing -> do
            settings <- appSettings <$> getYesod
            mAuthorization <- lookupHeader "Authorization"
            now <- liftIO getCurrentTime
            case bearerTokenFromHeader mAuthorization of
                Right (Just token) ->
                    pure $ toSqlKey <$> either (const Nothing) Just (verifyJwt settings now token)
                _ -> pure Nothing

-- Note: Some functionality previously present in the scaffolding has been
-- moved to documentation in the Wiki. Following are some hopefully helpful
-- links:
--
-- https://github.com/yesodweb/yesod/wiki/Sending-email
-- https://github.com/yesodweb/yesod/wiki/Serve-static-files-from-a-separate-domain
-- https://github.com/yesodweb/yesod/wiki/i18n-messages-in-the-scaffolding
