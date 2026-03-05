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
    , getAdminModerationR
    , postAdminModerationActionR
    , getAdminModerationLogsR
    ) where

import Import
import qualified Prelude as P
import Text.Blaze (preEscapedText)
import Yesod.Auth.HashDB (setPassword)
import qualified Data.Text as T
import qualified Data.Map.Strict as Map
import qualified Data.List as L
import qualified Data.Text.Encoding as TextEncoding
import Data.ByteString.Builder (toLazyByteString)
import qualified Data.ByteString.Lazy as LBS
import Database.Persist.Sql (fromSqlKey, toSqlKey)
import Text.Read (readMaybe)

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
            void $ runDB $ insert $ Board name (fmap unTextarea description) 0 0
            setMessage "Board created."
    redirect AdminBoardsR

postAdminBoardR :: BoardId -> Handler Html
postAdminBoardR boardId = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            postCount <- runDB $ count [PostBoard ==. boardId]
            if postCount > 0
                then setMessage "Board has posts and cannot be deleted."
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

getAdminModerationR :: Handler Html
getAdminModerationR = do
    req <- getRequest
    let mCsrfToken = reqToken req
    q <- fromMaybe "" <$> lookupGetParam "q"
    userQuery <- fromMaybe "" <$> lookupGetParam "user"
    typeQuery <- fromMaybe "" <$> lookupGetParam "type"
    pageParam <- lookupGetParam "page"
    perPageParam <- lookupGetParam "per_page"
    postFlags <- runDB $ selectList [] [Desc PostFlagCreatedAt]
    postBlocks <- runDB $ selectList [] [Desc PostBlockCreatedAt]

    let userIds =
            L.nub $
                map (postFlagUser . entityVal) postFlags
                    P.++ map (postBlockUser . entityVal) postBlocks
        postIds =
            L.nub $
                map (postFlagPost . entityVal) postFlags
                    P.++ map (postBlockPost . entityVal) postBlocks

    users <- if P.null userIds
        then pure []
        else runDB $ selectList [UserId <-. userIds] []
    posts <- if P.null postIds
        then pure []
        else runDB $ selectList [PostId <-. postIds] []

    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        postMap = Map.fromList $ map (\(Entity pid p) -> (pid, p)) posts
        userIdentFor uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        postTitleFor pid = maybe ("Unknown" :: Text) postTitle (Map.lookup pid postMap)
        postPreview = buildPreview 160 . postContent
        flagPosts =
            map
                (\(Entity fid f) ->
                    let pid = postFlagPost f
                        preview = maybe ("Unknown" :: Text) postPreview (Map.lookup pid postMap)
                    in ( fid
                       , userIdentFor (postFlagUser f)
                       , postTitleFor pid
                       , preview
                       , formatTime defaultTimeLocale "%F %R" (postFlagCreatedAt f)
                       )
                )
                postFlags
        blockPosts =
            map
                (\(Entity bid f) ->
                    let pid = postBlockPost f
                        preview = maybe ("Unknown" :: Text) postPreview (Map.lookup pid postMap)
                    in ( bid
                       , userIdentFor (postBlockUser f)
                       , postTitleFor pid
                       , preview
                       , formatTime defaultTimeLocale "%F %R" (postBlockCreatedAt f)
                       )
                )
                postBlocks

    let page = max 1 $ fromMaybe 1 (pageParam >>= (\t -> readMaybe (T.unpack t)))
        perPageRaw = fromMaybe 10 (perPageParam >>= (\t -> readMaybe (T.unpack t)))
        perPage = max 5 (min 50 perPageRaw)
    let qLower = T.toLower q
        userLower = T.toLower userQuery
        typeLower = T.toLower typeQuery
        matchesText txt = T.null qLower || T.isInfixOf qLower (T.toLower txt)
        matchesUser txt = T.null userLower || T.isInfixOf userLower (T.toLower txt)
        matchesType key = T.null typeLower || typeLower == key
        applyFiltersPost rows =
            P.filter (\(_, u, t, p, _) -> matchesUser u && (matchesText t || matchesText p)) rows
        flagPostsFiltered =
            if matchesType "post-flag" then applyFiltersPost flagPosts else []
        blockPostsFiltered =
            if matchesType "post-block" then applyFiltersPost blockPosts else []
        paginate rows =
            let total = length rows
                totalPages = max 1 $ ceiling (fromIntegral total / (fromIntegral perPage :: Double))
                start = (page - 1) * perPage
                pageRows = take perPage (drop start rows)
            in (pageRows, totalPages)
        (flagPostsPage, flagPostsPages) = paginate flagPostsFiltered
        (blockPostsPage, blockPostsPages) = paginate blockPostsFiltered
        listTypeOptions :: [(Text, Text)]
        listTypeOptions =
            [ ("", "All")
            , ("post-flag", "Post Flags")
            , ("post-block", "Post Blocks")
            ]
        baseParams =
            [ ("q", if T.null q then Nothing else Just q)
            , ("user", if T.null userQuery then Nothing else Just userQuery)
            , ("type", if T.null typeQuery then Nothing else Just typeQuery)
            , ("per_page", Just (T.pack (show perPage)))
            ]
        queryBase =
            TextEncoding.decodeUtf8
                $ LBS.toStrict
                $ toLazyByteString
                $ renderQueryText True baseParams
        pagePrefix =
            if T.null queryBase
                then "?page="
                else queryBase <> "&page="
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Moderation"
        let adminBody = $(widgetFile "admin/admin-moderation")
            activeKey = ("moderation" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminModerationLogsR :: Handler Html
getAdminModerationLogsR = do
    q <- fromMaybe "" <$> lookupGetParam "q"
    userQuery <- fromMaybe "" <$> lookupGetParam "user"
    typeQuery <- fromMaybe "" <$> lookupGetParam "type"
    pageParam <- lookupGetParam "page"
    perPageParam <- lookupGetParam "per_page"
    let page = max 1 $ fromMaybe 1 (pageParam >>= (\t -> readMaybe (T.unpack t)))
        perPageRaw = fromMaybe 20 (perPageParam >>= (\t -> readMaybe (T.unpack t)))
        perPage = max 5 (min 50 perPageRaw)
        qLower = T.toLower q
        userLower = T.toLower userQuery
        typeLower = T.toLower typeQuery
        matchesText txt = T.null qLower || T.isInfixOf qLower (T.toLower txt)
        matchesUser txt = T.null userLower || T.isInfixOf userLower (T.toLower txt)
        matchesType key = T.null typeLower || typeLower == key

    logs <- runDB $ selectList [] [Desc ModerationLogCreatedAt]
    let actorIds = L.nub $ map (moderationLogActor . entityVal) logs
    users <- if P.null actorIds
        then pure []
        else runDB $ selectList [UserId <-. actorIds] []
    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        actorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        filteredLogs =
            P.filter
                (\(Entity _ l) ->
                    matchesUser (actorName (moderationLogActor l))
                        && matchesType (moderationLogTargetType l)
                        && (matchesText (moderationLogTargetId l) || matchesText (moderationLogAction l))
                )
                logs
        postIds =
            L.nub
                [ toSqlKey pid
                | Entity _ l <- filteredLogs
                , moderationLogTargetType l `elem` ["post-flag", "post-block"]
                , Just pid <- [readMaybe (T.unpack (moderationLogTargetId l)) :: Maybe Int64]
                ]
    postsById <- if P.null postIds then pure [] else runDB $ selectList [PostId <-. postIds] []
    let postMap = Map.fromList $ map (\(Entity pid p) -> (pid, p)) postsById
        total = length filteredLogs
        totalPages = max 1 $ ceiling (fromIntegral total / (fromIntegral perPage :: Double))
        start = (page - 1) * perPage
        pageLogs = take perPage (drop start filteredLogs)
        logRows =
            map
                (\(Entity _ l) ->
                    let targetType = moderationLogTargetType l
                        targetId = moderationLogTargetId l
                        route =
                            case readMaybe (T.unpack targetId) :: Maybe Int64 of
                                Just pid
                                    | targetType `elem` ["post-flag", "post-block"]
                                        && Map.member (toSqlKey pid) postMap ->
                                            Just (PostR (toSqlKey pid))
                                _ -> Nothing
                    in ( targetType
                       , targetId
                       , moderationLogAction l
                       , actorName (moderationLogActor l)
                       , formatTime defaultTimeLocale "%F %R" (moderationLogCreatedAt l)
                       , route
                       )
                )
                pageLogs
        listTypeOptions :: [(Text, Text)]
        listTypeOptions =
            [ ("", "All")
            , ("post-flag", "Post Flags")
            , ("post-block", "Post Blocks")
            ]
        baseParams =
            [ ("q", if T.null q then Nothing else Just q)
            , ("user", if T.null userQuery then Nothing else Just userQuery)
            , ("type", if T.null typeQuery then Nothing else Just typeQuery)
            , ("per_page", Just (T.pack (show perPage)))
            ]
        queryBase =
            TextEncoding.decodeUtf8
                $ LBS.toStrict
                $ toLazyByteString
                $ renderQueryText True baseParams
        pagePrefix =
            if T.null queryBase
                then "?page="
                else queryBase <> "&page="

    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Moderation Logs"
        let adminBody = $(widgetFile "admin/admin-moderation-logs")
            activeKey = ("moderation-logs" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

postAdminModerationActionR :: Handler Html
postAdminModerationActionR = do
    action <- runInputPost $ ireq textField "action"
    actor <- requireAuthId
    now <- liftIO getCurrentTime
    case action of
        "post-flag-delete" -> do
            flagId <- runInputPost $ ireq hiddenField "id"
            mFlag <- runDB $ get flagId
            runDB $ delete flagId
            let targetId = maybe "unknown" (T.pack . show . fromSqlKey . postFlagPost) mFlag
            runDB $ insert_ $ ModerationLog actor "post-flag" targetId "delete" now
            setMessage "Post flag removed."
        "post-block-delete" -> do
            blockId <- runInputPost $ ireq hiddenField "id"
            mBlock <- runDB $ get blockId
            runDB $ delete blockId
            let targetId = maybe "unknown" (T.pack . show . fromSqlKey . postBlockPost) mBlock
            runDB $ insert_ $ ModerationLog actor "post-block" targetId "delete" now
            setMessage "Post block removed."
        _ -> setMessage "Unknown action."
    redirect AdminModerationR

buildPreview :: Int -> Text -> Text
buildPreview n raw =
    let plain = stripTags raw
        trimmed = T.take n plain
    in if T.length plain > n then trimmed <> "…" else trimmed

stripTags :: Text -> Text
stripTags = T.pack . go False . T.unpack
  where
    go _ [] = []
    go True ('>':xs) = go False xs
    go True (_:xs) = go True xs
    go False ('<':xs) = go True xs
    go False (x:xs) = x : go False xs

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
                    postCount <- runDB $ count [PostAuthor ==. userId]
                    commentCount <- runDB $ count [CommentAuthor ==. userId]
                    if postCount + commentCount > 0
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
    mLink <- runInputPost $ iopt textField "link"
    isActive <- runInputPost $ ireq checkBoxField "isActive"
    position <- runInputPost $ ireq textField "position"
    sortOrder <- runInputPost $ ireq intField "sortOrder"
    now <- liftIO getCurrentTime
    _ <- runDB $ insert $ Ad
        { adTitle = title
        , adBody = body
        , adLink = mLink
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
            mLink <- runInputPost $ iopt textField "link"
            isActive <- runInputPost $ ireq checkBoxField "isActive"
            position <- runInputPost $ ireq textField "position"
            sortOrder <- runInputPost $ ireq intField "sortOrder"
            now <- liftIO getCurrentTime
            runDB $ update adId
                [ AdTitle =. title
                , AdBody =. body
                , AdLink =. mLink
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
