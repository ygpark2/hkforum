{-# LANGUAGE TemplateHaskell, QuasiQuotes, OverloadedStrings, MultiParamTypeClasses, TypeFamilies, GADTs, ViewPatterns #-}
module Foundation where

import Import.NoFoundation hiding ((.), (++))
import qualified Prelude as P
import Database.Persist.Sql (ConnectionPool, runSqlPool)
import qualified Data.Text as T
import qualified Data.Set as Set
import Text.Hamlet          (hamletFile)
import Text.Jasmine         (minifym)
import Yesod.Auth.HashDB     (HashDBUser(..), authHashDB)
import Yesod.Auth.OAuth2.Google (oauth2Google)
import Auth.OAuth2Providers  (oauth2Kakao, oauth2Naver)
import Yesod.Default.Util   (addStaticContentExternal)
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
        master <- getYesod
        mmsg <- getMessage
        mSiteTitle <- runDB $ getBy $ UniqueSiteSetting "site_title"
        mSiteSubtitle <- runDB $ getBy $ UniqueSiteSetting "site_subtitle"
        let siteTitle = maybe "HKForum" (siteSettingValue P.. entityVal) mSiteTitle
            siteSubtitle = maybe "x.com inspired discussion hub" (siteSettingValue P.. entityVal) mSiteSubtitle
        mRoute <- getCurrentRoute
        req <- getRequest
        let layoutCsrfToken = reqToken req
        let showSidebarLayout = case mRoute of
                Just AdminR -> False
                Just AdminBoardsR -> False
                Just AdminBoardNewR -> False
                Just (AdminBoardR _) -> False
                Just AdminUsersR -> False
                Just AdminUserNewR -> False
                Just (AdminUserR _) -> False
                Just AdminSettingsR -> False
                Just AdminSettingNewR -> False
                Just (AdminSettingR _) -> False
                Just AdminAdsR -> False
                Just AdminAdNewR -> False
                Just (AdminAdR _) -> False
                _ -> True
        layoutBoards <- if showSidebarLayout
            then runDB $ selectList [] [Asc BoardName]
            else pure []
        layoutMaybeAuth <- if showSidebarLayout
            then maybeAuthId
            else pure Nothing
        layoutViewer <- if showSidebarLayout
            then case layoutMaybeAuth of
                Nothing -> pure Nothing
                Just viewerId -> runDB $ get viewerId
            else pure Nothing
        layoutSuggestedUsers <- if showSidebarLayout
            then case layoutMaybeAuth of
                Nothing -> runDB $ selectList [] [Asc UserIdent, LimitTo 5]
                Just viewerId -> runDB $ selectList [UserId !=. viewerId] [Asc UserIdent, LimitTo 5]
            else pure []
        let suggestedIds = map entityKey layoutSuggestedUsers
        layoutFollowingRows <- if showSidebarLayout
            then case layoutMaybeAuth of
                Nothing -> pure []
                Just viewerId ->
                    if P.null suggestedIds
                        then pure []
                        else runDB $ selectList [UserFollowFollower ==. viewerId, UserFollowFollowing <-. suggestedIds] []
            else pure []
        let layoutFollowingSet = Set.fromList $ map (userFollowFollowing P.. entityVal) layoutFollowingRows
            layoutIsFollowing uid = Set.member uid layoutFollowingSet
            layoutFollowState uid = if layoutIsFollowing uid then ("true" :: Text) else "false"
            layoutFollowLabel uid = if layoutIsFollowing uid then ("Following" :: Text) else "Follow"
        layoutUnreadNotificationCount <- if showSidebarLayout
            then case layoutMaybeAuth of
                Nothing -> pure (0 :: Int)
                Just viewerId -> runDB $ count [NotificationUser ==. viewerId, NotificationIsRead ==. False]
            else pure (0 :: Int)
        pc <- widgetToPageContent $ do
            $(widgetFile "layout/default-layout")
        withUrlRenderer $(hamletFile "templates/layout/default-layout-wrapper.hamlet")

    -- Store session data on the client in encrypted cookies,
    -- default session idle timeout is 120 minutes
    makeSessionBackend _ = Just <$> defaultClientSessionBackend
        120    -- timeout in minutes
        "config/client_session_key.aes"

    -- The page to be redirected to when authentication is required.
    authRoute _ = Just $ AuthR LoginR

    -- Routes not requiring authentication.
    isAuthorized (AuthR _) _ = return Authorized
    isAuthorized FaviconR _ = return Authorized
    isAuthorized RobotsR _ = return Authorized
    isAuthorized JobsR isWrite =
        if isWrite
            then do
                mUserId <- maybeAuthId
                case mUserId of
                    Nothing -> return AuthenticationRequired
                    Just _ -> return Authorized
            else return Authorized
    isAuthorized ChatsR _ = return Authorized
    isAuthorized ChatsNewR isWrite =
        if isWrite
            then do
                mUserId <- maybeAuthId
                case mUserId of
                    Nothing -> return AuthenticationRequired
                    Just _ -> return Authorized
            else return Authorized
    isAuthorized (ChatRoomR _) _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized (JobCloseR _) _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized NotificationsR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized NotificationsReadAllR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized BookmarksR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized (UserFollowR _) _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized (PostLikeR _) _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized (PostReactR _) _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized (PostBookmarkR _) _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized (PostWatchR _) _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized (PostFlagR _) _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized (PostBlockR _) _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized ProfileR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized SettingsR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized SettingsAccountR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized SettingsConnectionsR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized SettingsBlockedAccountsR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized SettingsSecurityEventsR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    isAuthorized SettingsAboutR _ = do
        mUserId <- maybeAuthId
        case mUserId of
            Nothing -> return AuthenticationRequired
            Just _ -> return Authorized
    -- Admin-only routes.
    isAuthorized AdminR _ = isAdmin
    isAuthorized AdminBoardsR _ = isAdmin
    isAuthorized AdminBoardNewR _ = isAdmin
    isAuthorized (AdminBoardR _) _ = isAdmin
    isAuthorized AdminUsersR _ = isAdmin
    isAuthorized AdminUserNewR _ = isAdmin
    isAuthorized (AdminUserR _) _ = isAdmin
    isAuthorized AdminSettingsR _ = isAdmin
    isAuthorized AdminSettingNewR _ = isAdmin
    isAuthorized (AdminSettingR _) _ = isAdmin
    isAuthorized AdminAdsR _ = isAdmin
    isAuthorized AdminAdNewR _ = isAdmin
    isAuthorized (AdminAdR _) _ = isAdmin
    isAuthorized AdminModerationR _ = isAdmin
    isAuthorized AdminModerationActionR _ = isAdmin
    isAuthorized AdminModerationLogsR _ = isAdmin
    -- Default to Authorized for now.
    isAuthorized _ _ = return Authorized

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
    loginDest _ = HomeR
    logoutDest _ = HomeR
    redirectToReferer _ = False
    authHttpManager = getYesod >>= return P.. getHttpManager
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
            Nothing -> Authenticated <$> insert (User ident Nothing "user" Nothing Nothing)

instance YesodAuthPersist App where
    type AuthEntity App = User

instance HashDBUser User where
    userPasswordHash = userPassword
    setPasswordHash p u = u { userPassword = Just p }

isAdmin :: Handler AuthResult
isAdmin = do
    mUserId <- maybeAuthId
    case mUserId of
        Nothing -> return AuthenticationRequired
        Just userId -> do
            mUser <- runDB $ get userId
            case mUser of
                Nothing -> return AuthenticationRequired
                Just user ->
                    if userRole user == "admin"
                        then return Authorized
                        else return $ Unauthorized "Admin only"


-- This instance is required to use forms. You can modify renderMessage to
-- achieve customized and internationalized form validation messages.
instance RenderMessage App FormMessage where
    renderMessage _ _ = defaultFormMessage

unsafeHandler :: App -> Handler a -> IO a
unsafeHandler = Unsafe.fakeHandlerGetLogger appLogger

-- Note: Some functionality previously present in the scaffolding has been
-- moved to documentation in the Wiki. Following are some hopefully helpful
-- links:
--
-- https://github.com/yesodweb/yesod/wiki/Sending-email
-- https://github.com/yesodweb/yesod/wiki/Serve-static-files-from-a-separate-domain
-- https://github.com/yesodweb/yesod/wiki/i18n-messages-in-the-scaffolding
