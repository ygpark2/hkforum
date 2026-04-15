{-# LANGUAGE TemplateHaskell, QuasiQuotes, OverloadedStrings, MultiParamTypeClasses, TypeFamilies, GADTs, ViewPatterns #-}
module Foundation where

import Import.NoFoundation hiding ((.), (++))
import qualified Prelude as P
import Database.Persist.Sql (ConnectionPool, runSqlPool)
import qualified Data.Text as T
import qualified Data.Set as Set
import Data.Time (utctDay)
import Text.Hamlet          (hamletFile)
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
        master <- getYesod
        mmsg <- getMessage
        settingRows <- runDB $ selectList [] []
        let settingMap = siteSettingMapFromEntities settingRows
        let siteTitle = siteSettingText "site_title" "HKForum" settingMap
            siteSubtitle = siteSettingText "site_subtitle" "x.com inspired discussion hub" settingMap
            layoutSiteDescription = siteSettingText "site_description" siteSubtitle settingMap
            layoutSiteKeywords = siteSettingText "site_keywords" "" settingMap
            layoutSiteLogoUrl = siteSettingMaybeText "site_logo_url" settingMap
            layoutSiteFaviconUrl = siteSettingMaybeText "site_favicon_url" settingMap
            layoutFooterText = siteSettingText "footer_text" (appCopyright $ appSettings master) settingMap
            layoutDefaultLocale = siteSettingText "default_locale" "en" settingMap
            layoutAllowUserRegistration = siteSettingBool "allow_user_registration" True settingMap
            layoutAllowPostReporting = siteSettingBool "allow_post_reporting" True settingMap
            layoutAllowUserBlocking = siteSettingBool "allow_user_blocking" True settingMap
            layoutShowCompaniesNav = siteSettingBool "companies_enabled" True settingMap
            layoutShowJobsNav = siteSettingBool "jobs_enabled" True settingMap
            layoutMapsEnabled = siteSettingBool "maps_enabled" True settingMap
            layoutAdsEnabled = siteSettingBool "ads_enabled" True settingMap
            layoutAdSlotsSidebarEnabled = siteSettingBool "ad_slots_sidebar_enabled" True settingMap
            layoutMapDefaultLatitude = siteSettingDouble "default_map_latitude" 37.5665 settingMap
            layoutMapDefaultLongitude = siteSettingDouble "default_map_longitude" 126.978 settingMap
            layoutMapDefaultZoom = siteSettingInt "default_map_zoom" 6 settingMap
        mRoute <- getCurrentRoute
        req <- getRequest
        let layoutCsrfToken = reqToken req
        let showSidebarLayout = case mRoute of
                Just route | isAdminConsoleRoute route -> False
                Just RegisterR -> False
                Just (AuthR LoginR) -> False
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
        today <- liftIO $ utctDay <$> getCurrentTime
        layoutSidebarAds <- if showSidebarLayout && layoutAdsEnabled && layoutAdSlotsSidebarEnabled
            then runDB $ selectList
                [ AdPosition ==. "sidebar-right"
                , AdIsActive ==. True
                , FilterOr [AdStartDate ==. Nothing, AdStartDate <=. Just today]
                , FilterOr [AdEndDate ==. Nothing, AdEndDate >=. Just today]
                ]
                [Asc AdSortOrder, Desc AdCreatedAt]
            else pure []
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

    isAuthorized route isWrite = do
        settingRows <- runDB $ selectList [] []
        mUserId <- maybeAuthId
        mViewer <-
            case mUserId of
                Nothing -> pure Nothing
                Just userId -> runDB $ get userId
        let settingMap = siteSettingMapFromEntities settingRows
            maintenanceMode = siteSettingBool "maintenance_mode" False settingMap
            maintenanceMessage = siteSettingText "maintenance_message" "The site is temporarily in maintenance mode." settingMap
            allowAnonymousRead = siteSettingBool "allow_anonymous_read" True settingMap
            allowUserRegistration = siteSettingBool "allow_user_registration" True settingMap
            allowPostReporting = siteSettingBool "allow_post_reporting" True settingMap
            allowUserBlocking = siteSettingBool "allow_user_blocking" True settingMap
            jobsEnabled = siteSettingBool "jobs_enabled" True settingMap
            companiesEnabled = siteSettingBool "companies_enabled" True settingMap
            mapsEnabled = siteSettingBool "maps_enabled" True settingMap
            viewerIsAdmin = maybe False (\user -> userRole user == ("admin" :: Text)) mViewer
            requireAuthenticated =
                case mUserId of
                    Nothing -> AuthenticationRequired
                    Just _ -> Authorized
        if maintenanceMode && not viewerIsAdmin && not (isMaintenanceExemptRoute route)
            then return $ Unauthorized maintenanceMessage
            else
                if not allowAnonymousRead && not isWrite && isAnonymousReadRoute route && isNothing mUserId
                    then return AuthenticationRequired
                    else
                        case route of
                            AuthR _ -> return Authorized
                            FaviconR -> return Authorized
                            RobotsR -> return Authorized
                            HomeR ->
                                if isWrite
                                    then return requireAuthenticated
                                    else return Authorized
                            BoardsR -> return Authorized
                            BoardR _ ->
                                if isWrite
                                    then return requireAuthenticated
                                    else return Authorized
                            PostR _ -> return Authorized
                            JobsR ->
                                if not jobsEnabled
                                    then return $ Unauthorized "Jobs are currently disabled."
                                    else
                                        if isWrite
                                            then return requireAuthenticated
                                            else return Authorized
                            JobCloseR _ ->
                                if not jobsEnabled
                                    then return $ Unauthorized "Jobs are currently disabled."
                                    else return requireAuthenticated
                            CompaniesR ->
                                if not companiesEnabled
                                    then return $ Unauthorized "Companies are currently disabled."
                                    else
                                        if isWrite
                                            then return requireAuthenticated
                                            else return Authorized
                            CompanyCategoriesR ->
                                if not companiesEnabled
                                    then return $ Unauthorized "Companies are currently disabled."
                                    else return requireAuthenticated
                            MapMarkersR ->
                                if mapsEnabled
                                    then return Authorized
                                    else return $ Unauthorized "Maps are currently disabled."
                            ChatsR -> return Authorized
                            ChatsNewR ->
                                if isWrite
                                    then return requireAuthenticated
                                    else return Authorized
                            ChatRoomR _ -> return requireAuthenticated
                            NotificationsR -> return requireAuthenticated
                            NotificationsReadAllR -> return requireAuthenticated
                            BookmarksR -> return requireAuthenticated
                            UserFollowR _ -> return requireAuthenticated
                            PostLikeR _ -> return requireAuthenticated
                            PostReactR _ -> return requireAuthenticated
                            PostBookmarkR _ -> return requireAuthenticated
                            PostWatchR _ -> return requireAuthenticated
                            PostFlagR _ ->
                                if allowPostReporting
                                    then return requireAuthenticated
                                    else return $ Unauthorized "Post reporting is currently disabled."
                            PostBlockR _ ->
                                if allowUserBlocking
                                    then return requireAuthenticated
                                    else return $ Unauthorized "Blocking is currently disabled."
                            RegisterR ->
                                if allowUserRegistration
                                    then return Authorized
                                    else return $ Unauthorized "Registration is currently disabled."
                            ProfileR -> return requireAuthenticated
                            UploadR -> return requireAuthenticated
                            SettingsR -> return requireAuthenticated
                            SettingsAccountR -> return requireAuthenticated
                            SettingsConnectionsR -> return requireAuthenticated
                            SettingsBlockedAccountsR -> return requireAuthenticated
                            SettingsSecurityEventsR -> return requireAuthenticated
                            SettingsAboutR -> return requireAuthenticated
                            -- Admin-only routes.
                            AdminR -> isAdmin
                            AdminBoardsR -> isAdmin
                            AdminBoardNewR -> isAdmin
                            AdminBoardR _ -> isAdmin
                            AdminCompaniesR -> isAdmin
                            AdminCompanyNewR -> isAdmin
                            AdminCompanyR _ -> isAdmin
                            AdminCompanyCategoriesR -> isAdmin
                            AdminCompanyCategoryNewR -> isAdmin
                            AdminCompanyCategoryR _ -> isAdmin
                            AdminUsersR -> isAdmin
                            AdminUserNewR -> isAdmin
                            AdminUserR _ -> isAdmin
                            AdminSettingsR -> isAdmin
                            AdminSettingNewR -> isAdmin
                            AdminSettingR _ -> isAdmin
                            AdminAdsR -> isAdmin
                            AdminAdNewR -> isAdmin
                            AdminAdR _ -> isAdmin
                            AdminModerationR -> isAdmin
                            AdminModerationActionR -> isAdmin
                            AdminModerationLogsR -> isAdmin
                            _ -> return Authorized

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

    authLayout widget = do
        mRoute <- getCurrentRoute
        case mRoute of
            Just (AuthR LoginR) -> liftHandler $ do
                mmsg <- getMessage
                settingRows <- runDB $ selectList [] []
                let settingMap = siteSettingMapFromEntities settingRows
                    authAllowUserRegistration = siteSettingBool "allow_user_registration" True settingMap
                    authSiteTitle = siteSettingText "site_title" "HKForum" settingMap
                defaultLayout $ do
                    setTitle "Login"
                    $(widgetFile "auth/login")
            _ -> liftHandler $ defaultLayout widget

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
                    (User ident Nothing "user" Nothing Nothing Nothing Nothing False Nothing Nothing)

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

isAdminConsoleRoute :: Route App -> Bool
isAdminConsoleRoute route = case route of
    AdminR -> True
    AdminBoardsR -> True
    AdminBoardNewR -> True
    AdminBoardR _ -> True
    AdminCompaniesR -> True
    AdminCompanyNewR -> True
    AdminCompanyR _ -> True
    AdminCompanyCategoriesR -> True
    AdminCompanyCategoryNewR -> True
    AdminCompanyCategoryR _ -> True
    AdminUsersR -> True
    AdminUserNewR -> True
    AdminUserR _ -> True
    AdminSettingsR -> True
    AdminSettingNewR -> True
    AdminSettingR _ -> True
    AdminAdsR -> True
    AdminAdNewR -> True
    AdminAdR _ -> True
    AdminModerationR -> True
    AdminModerationActionR -> True
    AdminModerationLogsR -> True
    _ -> False

isMaintenanceExemptRoute :: Route App -> Bool
isMaintenanceExemptRoute route = case route of
    AuthR _ -> True
    FaviconR -> True
    RobotsR -> True
    AdminR -> True
    AdminBoardsR -> True
    AdminBoardNewR -> True
    AdminBoardR _ -> True
    AdminCompaniesR -> True
    AdminCompanyNewR -> True
    AdminCompanyR _ -> True
    AdminCompanyCategoriesR -> True
    AdminCompanyCategoryNewR -> True
    AdminCompanyCategoryR _ -> True
    AdminUsersR -> True
    AdminUserNewR -> True
    AdminUserR _ -> True
    AdminSettingsR -> True
    AdminSettingNewR -> True
    AdminSettingR _ -> True
    AdminAdsR -> True
    AdminAdNewR -> True
    AdminAdR _ -> True
    AdminModerationR -> True
    AdminModerationActionR -> True
    AdminModerationLogsR -> True
    _ -> False

isAnonymousReadRoute :: Route App -> Bool
isAnonymousReadRoute route = case route of
    HomeR -> True
    BoardsR -> True
    BoardR _ -> True
    PostR _ -> True
    JobsR -> True
    CompaniesR -> True
    MapMarkersR -> True
    _ -> False


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
