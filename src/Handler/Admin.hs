{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Handler.Admin
    ( getAdminR
    , getAdminBoardsR
    , getAdminBoardNewR
    , getAdminBoardR
    , postAdminBoardsR
    , postAdminBoardR
    , getAdminUsersR
    , getAdminUserNewR
    , getAdminUserR
    , postAdminUsersR
    , postAdminUserR
    , getAdminSettingsR
    , getAdminSettingNewR
    , getAdminSettingR
    , postAdminSettingsR
    , getAdminAdsR
    , getAdminAdNewR
    , getAdminAdR
    , postAdminAdsR
    , postAdminAdR
    ) where

import Import
import Prelude hiding (null)
import qualified Prelude as P
import Data.Time (getCurrentTime)
import Text.Blaze (preEscapedText)
import Yesod.Auth.HashDB (setPassword)
import qualified Data.Text as T

getAdminR :: Handler Html
getAdminR = do
    defaultLayout $ do
        setTitle $ preEscapedText "Admin"
        let adminBody = $(widgetFile "admin/admin")
            activeKey = ("overview" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminBoardsR :: Handler Html
getAdminBoardsR = do
    boards <- runDB $ selectList [] [Asc BoardName]
    req <- getRequest
    let mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Boards"
        let adminBody = $(widgetFile "admin/admin-boards")
            activeKey = ("boards" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminBoardNewR :: Handler Html
getAdminBoardNewR = do
    req <- getRequest
    let mCsrfToken = reqToken req
        mBoard = (Nothing :: Maybe (Entity Board))
        isNew = True
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New Board"
        let adminBody = $(widgetFile "admin/admin-board-detail")
            activeKey = ("boards" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminBoardR :: BoardId -> Handler Html
getAdminBoardR boardId = do
    board <- runDB $ get404 boardId
    req <- getRequest
    let mCsrfToken = reqToken req
        mBoard = Just (Entity boardId board)
        isNew = False
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit Board"
        let adminBody = $(widgetFile "admin/admin-board-detail")
            activeKey = ("boards" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

postAdminBoardsR :: Handler Html
postAdminBoardsR = do
    name <- runInputPost $ ireq textField "name"
    description <- runInputPost $ iopt textareaField "description"
    mExisting <- runDB $ getBy $ UniqueBoard name
    case mExisting of
        Just _ -> setMessage "Board already exists."
        Nothing -> do
            void $ runDB $ insert $ Board name (fmap unTextarea description) 0 0 0
            setMessage "Board created."
    redirect AdminBoardsR

postAdminBoardR :: BoardId -> Handler Html
postAdminBoardR boardId = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            threadCount <- runDB $ count [ThreadBoard ==. boardId]
            if threadCount > 0
                then setMessage "Board has threads and cannot be deleted."
                else do
                    runDB $ delete boardId
                    setMessage "Board deleted."
            redirect AdminBoardsR
        "update" -> do
            name <- runInputPost $ ireq textField "name"
            description <- runInputPost $ iopt textareaField "description"
            mExisting <- runDB $ getBy $ UniqueBoard name
            case mExisting of
                Just (Entity existingId _) | existingId /= boardId ->
                    setMessage "Board name already exists."
                _ -> do
                    runDB $ update boardId
                        [ BoardName =. name
                        , BoardDescription =. fmap unTextarea description
                        ]
                    setMessage "Board updated."
            redirect AdminBoardsR
        _ -> do
            setMessage "Unknown action."
            redirect AdminBoardsR

getAdminUsersR :: Handler Html
getAdminUsersR = do
    users <- runDB $ selectList [] [Asc UserIdent]
    mUserId <- maybeAuthId
    req <- getRequest
    let mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Users"
        let adminBody = $(widgetFile "admin/admin-users")
            activeKey = ("users" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminUserNewR :: Handler Html
getAdminUserNewR = do
    req <- getRequest
    let mCsrfToken = reqToken req
        mUser = (Nothing :: Maybe (Entity User))
        isNew = True
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New User"
        let adminBody = $(widgetFile "admin/admin-user-detail")
            activeKey = ("users" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminUserR :: UserId -> Handler Html
getAdminUserR userId = do
    user <- runDB $ get404 userId
    req <- getRequest
    let mCsrfToken = reqToken req
        mUser = Just (Entity userId user)
        isNew = False
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit User"
        let adminBody = $(widgetFile "admin/admin-user-detail")
            activeKey = ("users" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminSettingsR :: Handler Html
getAdminSettingsR = do
    settings <- runDB $ selectList [] [Asc SiteSettingKey]
    mSiteTitle <- runDB $ getBy $ UniqueSiteSetting "site_title"
    mSiteSubtitle <- runDB $ getBy $ UniqueSiteSetting "site_subtitle"
    req <- getRequest
    let mCsrfToken = reqToken req
        siteTitleValue = maybe "HKForum" (siteSettingValue P.. entityVal) mSiteTitle
        siteSubtitleValue = maybe "x.com inspired discussion hub" (siteSettingValue P.. entityVal) mSiteSubtitle
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Settings"
        let adminBody = $(widgetFile "admin/admin-settings")
            activeKey = ("settings" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminSettingNewR :: Handler Html
getAdminSettingNewR = do
    req <- getRequest
    let mCsrfToken = reqToken req
        mSetting = (Nothing :: Maybe (Entity SiteSetting))
        isNew = True
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New Setting"
        let adminBody = $(widgetFile "admin/admin-setting-detail")
            activeKey = ("settings" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminSettingR :: SiteSettingId -> Handler Html
getAdminSettingR settingId = do
    setting <- runDB $ get404 settingId
    req <- getRequest
    let mCsrfToken = reqToken req
        mSetting = Just (Entity settingId setting)
        isNew = False
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit Setting"
        let adminBody = $(widgetFile "admin/admin-setting-detail")
            activeKey = ("settings" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminAdsR :: Handler Html
getAdminAdsR = do
    ads <- runDB $ selectList [] [Asc AdSortOrder, Desc AdCreatedAt]
    req <- getRequest
    let mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Ads"
        let adminBody = $(widgetFile "admin/admin-ads")
            activeKey = ("ads" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminAdNewR :: Handler Html
getAdminAdNewR = do
    req <- getRequest
    let mCsrfToken = reqToken req
        mAd = (Nothing :: Maybe (Entity Ad))
        isNew = True
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New Ad"
        let adminBody = $(widgetFile "admin/admin-ad-detail")
            activeKey = ("ads" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminAdR :: AdId -> Handler Html
getAdminAdR adId = do
    ad <- runDB $ get404 adId
    req <- getRequest
    let mCsrfToken = reqToken req
        mAd = Just (Entity adId ad)
        isNew = False
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit Ad"
        let adminBody = $(widgetFile "admin/admin-ad-detail")
            activeKey = ("ads" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

postAdminUsersR :: Handler Html
postAdminUsersR = do
    ident <- runInputPost $ ireq textField "ident"
    password <- runInputPost $ ireq passwordField "password"
    role <- normalizeRole <$> runInputPost (ireq textField "role")
    name <- runInputPost $ iopt textField "name"
    description <- runInputPost $ iopt textField "description"
    mExisting <- runDB $ getBy $ UniqueUser ident
    case mExisting of
        Just _ -> setMessage "User already exists."
        Nothing -> do
            user <- liftIO $ setPassword password (User ident Nothing role name description)
            void $ runDB $ insert user
            setMessage "User created."
    redirect AdminUsersR

postAdminUserR :: UserId -> Handler Html
postAdminUserR userId = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            mCurrent <- maybeAuthId
            if Just userId == mCurrent
                then setMessage "You cannot delete your own account."
                else do
                    threadCount <- runDB $ count [ThreadAuthor ==. userId]
                    postCount <- runDB $ count [PostAuthor ==. userId]
                    commentCount <- runDB $ count [CommentAuthor ==. userId]
                    if threadCount + postCount + commentCount > 0
                        then setMessage "User has content and cannot be deleted."
                        else do
                            runDB $ delete userId
                            setMessage "User deleted."
            redirect AdminUsersR
        "update" -> do
            ident <- runInputPost $ ireq textField "ident"
            role <- normalizeRole <$> runInputPost (ireq textField "role")
            name <- runInputPost $ iopt textField "name"
            description <- runInputPost $ iopt textField "description"
            password <- runInputPost $ iopt passwordField "password"
            mExisting <- runDB $ getBy $ UniqueUser ident
            case mExisting of
                Just (Entity existingId _) | existingId /= userId ->
                    setMessage "Username already exists."
                _ -> do
                    user <- runDB $ get404 userId
                    let baseUser = user
                            { userIdent = ident
                            , userRole = role
                            , userName = name
                            , userDescription = description
                            }
                    updatedUser <- case password of
                        Nothing -> pure baseUser
                        Just pwd | T.null pwd -> pure baseUser
                        Just pwd -> liftIO $ setPassword pwd baseUser
                    runDB $ replace userId updatedUser
                    setMessage "User updated."
            redirect AdminUsersR
        _ -> do
            setMessage "Unknown action."
            redirect AdminUsersR

postAdminSettingsR :: Handler Html
postAdminSettingsR = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "site-identity" -> do
            title <- runInputPost $ ireq textField "site_title"
            subtitle <- runInputPost $ ireq textField "site_subtitle"
            _ <- runDB $ upsert (SiteSetting "site_title" title) [SiteSettingValue =. title]
            _ <- runDB $ upsert (SiteSetting "site_subtitle" subtitle) [SiteSettingValue =. subtitle]
            setMessage "Site identity updated."
            redirect AdminSettingsR
        "upsert" -> do
            key <- runInputPost $ ireq textField "key"
            value <- runInputPost $ ireq textField "value"
            if T.null key
                then setMessage "Key is required."
                else do
                    _ <- runDB $ upsert (SiteSetting key value) [SiteSettingValue =. value]
                    setMessage "Setting saved."
            redirect AdminSettingsR
        "delete" -> do
            key <- runInputPost $ ireq textField "key"
            runDB $ deleteBy $ UniqueSiteSetting key
            setMessage "Setting deleted."
            redirect AdminSettingsR
        _ -> do
            setMessage "Unknown action."
            redirect AdminSettingsR

postAdminAdsR :: Handler Html
postAdminAdsR = do
    title <- runInputPost $ ireq textField "title"
    body <- runInputPost $ ireq textField "body"
    link <- runInputPost $ iopt textField "link"
    isActive <- runInputPost $ ireq checkBoxField "isActive"
    position <- runInputPost $ ireq textField "position"
    sortOrder <- runInputPost $ ireq intField "sortOrder"
    now <- liftIO getCurrentTime
    _ <- runDB $ insert $ Ad
        { adTitle = title
        , adBody = body
        , adLink = link
        , adIsActive = isActive
        , adPosition = position
        , adSortOrder = sortOrder
        , adCreatedAt = now
        , adUpdatedAt = now
        }
    setMessage "Ad created."
    redirect AdminAdsR

postAdminAdR :: AdId -> Handler Html
postAdminAdR adId = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            runDB $ delete adId
            setMessage "Ad deleted."
            redirect AdminAdsR
        "update" -> do
            title <- runInputPost $ ireq textField "title"
            body <- runInputPost $ ireq textField "body"
            link <- runInputPost $ iopt textField "link"
            isActive <- runInputPost $ ireq checkBoxField "isActive"
            position <- runInputPost $ ireq textField "position"
            sortOrder <- runInputPost $ ireq intField "sortOrder"
            now <- liftIO getCurrentTime
            runDB $ update adId
                [ AdTitle =. title
                , AdBody =. body
                , AdLink =. link
                , AdIsActive =. isActive
                , AdPosition =. position
                , AdSortOrder =. sortOrder
                , AdUpdatedAt =. now
                ]
            setMessage "Ad updated."
            redirect AdminAdsR
        _ -> do
            setMessage "Unknown action."
            redirect AdminAdsR

normalizeRole :: Text -> Text
normalizeRole role
    | role == "admin" = "admin"
    | otherwise = "user"
