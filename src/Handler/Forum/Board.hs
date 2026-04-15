{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Board (getBoardR, postBoardR) where

import Import
import Forum.Tag (loadPostTagsMap, parseTagList, syncPostTags)
import SiteSettings
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as T
import Text.Blaze (preEscapedText)
import qualified Prelude as P

getBoardR :: BoardId -> Handler Html
getBoardR boardId = do
    board <- runDB $ get404 boardId
    settingRows <- runDB $ selectList [] []
    let settingMap = siteSettingMapFromEntities settingRows
        postsPerPage = max 1 (siteSettingInt "posts_per_page" 100 settingMap)
        globalLocalRegionFilterEnabled = siteSettingBool "local_region_filter_enabled" True settingMap
    mViewer <- maybeAuth
    let mViewerId = entityKey <$> mViewer
        localRegionFilterEnabled = globalLocalRegionFilterEnabled && maybe False (userLocalRegionOnly . entityVal) mViewer
        mActiveLocalRegion = mViewer >>= (userRegionPair . entityVal)
        localRegionNotice =
            if localRegionFilterEnabled
                then
                    case mActiveLocalRegion of
                        Just (countryCodeValue, stateValue) ->
                            Just ("내 지역 필터 적용 중: " <> stateValue <> ", " <> countryCodeValue)
                        Nothing ->
                            Just ("프로필에 국가와 주를 저장해야 내 지역 필터를 사용할 수 있습니다." :: Text)
                else Nothing
    posts <-
        case (localRegionFilterEnabled, mActiveLocalRegion) of
            (True, Nothing) -> pure []
            (True, Just (countryCodeValue, stateValue)) ->
                runDB $ selectList [PostBoard ==. boardId, PostCountryCode ==. Just countryCodeValue, PostState ==. Just stateValue] [Desc PostCreatedAt, LimitTo postsPerPage]
            (False, _) ->
                runDB $ selectList [PostBoard ==. boardId] [Desc PostCreatedAt, LimitTo postsPerPage]
    let authorIds = L.nub $ map (postAuthor . entityVal) posts
    users <- if P.null authorIds
        then pure []
        else runDB $ selectList [UserId <-. authorIds] []
    comments <- if P.null posts
        then pure []
        else runDB $ selectList [CommentPost <-. map entityKey posts] []
    let postIds = map entityKey posts
    likes <- if P.null postIds
        then pure []
        else runDB $ selectList [PostLikePost <-. postIds] []
    views <- if P.null postIds
        then pure []
        else runDB $ selectList [PostViewPost <-. postIds] []
    tagsByPost <- runDB $ loadPostTagsMap postIds
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        commentCountMap =
            P.foldl'
                (\acc (Entity _ c) -> Map.insertWith (+) (commentPost c) (1 :: Int) acc)
                Map.empty
                comments
        likeCountMap =
            P.foldl'
                (\acc (Entity _ l) -> Map.insertWith (+) (postLikePost l) (1 :: Int) acc)
                Map.empty
                likes
        viewCountMap =
            P.foldl'
                (\acc (Entity _ v) -> Map.insertWith (+) (postViewPost v) (1 :: Int) acc)
                Map.empty
                views
        commentCountFor pid = Map.findWithDefault 0 pid commentCountMap
        likeCountFor pid = Map.findWithDefault 0 pid likeCountMap
        viewCountFor pid = Map.findWithDefault 0 pid viewCountMap
        tagsFor pid = Map.findWithDefault [] pid tagsByPost
    bookmarkedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null postIds
                then pure []
                else runDB $ selectList [PostBookmarkUser ==. viewerId, PostBookmarkPost <-. postIds] []
    likedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null postIds
                then pure []
                else runDB $ selectList [PostLikeUser ==. viewerId, PostLikePost <-. postIds] []
    let likeSet = Set.fromList $ map (postLikePost . entityVal) likedRows
        bookmarkSet = Set.fromList $ map (postBookmarkPost . entityVal) bookmarkedRows
        isLiked pid = Set.member pid likeSet
        isBookmarked pid = Set.member pid bookmarkSet
        likeState pid = if isLiked pid then ("true" :: Text) else "false"
        likeIcon pid = if isLiked pid then ("♥" :: Text) else "♡"
        likeLabel pid = if isLiked pid then ("Liked" :: Text) else "Like"
        bookmarkState pid = if isBookmarked pid then ("true" :: Text) else "false"
    req <- getRequest
    let mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText $ boardName board <> " - HKForum"
        $(widgetFile "forum/board")

postBoardR :: BoardId -> Handler Html
postBoardR boardId = do
    userId <- requireAuthId
    user <- runDB $ get404 userId
    settingRows <- runDB $ selectList [] []
    let settingMap = siteSettingMapFromEntities settingRows
        maxPostTitleLength = max 1 (siteSettingInt "max_post_title_length" 120 settingMap)
        maxPostBodyLength = max 1 (siteSettingInt "max_post_body_length" 10000 settingMap)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    _ <- runDB $ get404 boardId
    titleRaw <- runInputPost $ ireq textField "title"
    mTags <- runInputPost $ iopt textField "tags"
    mLatitude <- runInputPost $ iopt doubleField "latitude"
    mLongitude <- runInputPost $ iopt doubleField "longitude"
    contentRaw <- runInputPost $ ireq textField "content"
    let title = T.strip titleRaw
        content = T.strip contentRaw
    when (T.null title) $ invalidArgs ["title is required"]
    when (T.null content) $ invalidArgs ["content is required"]
    when (T.length title > maxPostTitleLength) $
        invalidArgs ["title exceeds the configured maximum length"]
    when (T.length content > maxPostBodyLength) $
        invalidArgs ["content exceeds the configured maximum length"]
    when (textContainsBlockedTerm blockedWords (title <> " " <> content)) $
        invalidArgs ["content contains blocked terms"]
    (mLatitudeValue, mLongitudeValue) <- requireCoordinatePair mLatitude mLongitude
    let (mCountryCodeValue, mStateValue) = userRegionFields user
    now <- liftIO getCurrentTime
    postId <- runDB $ insert Post
        { postTitle = title
        , postContent = content
        , postAuthor = userId
        , postBoard = boardId
        , postCountryCode = mCountryCodeValue
        , postState = mStateValue
        , postLatitude = mLatitudeValue
        , postLongitude = mLongitudeValue
        , postCreatedAt = now
        , postUpdatedAt = now
        }
    runDB $ syncPostTags postId (parseTagList mTags)
    runDB $ update boardId [BoardPostCount +=. 1]
    redirect $ BoardR boardId

requireCoordinatePair :: Maybe Double -> Maybe Double -> Handler (Maybe Double, Maybe Double)
requireCoordinatePair Nothing Nothing = pure (Nothing, Nothing)
requireCoordinatePair (Just lat) (Just lng) = pure (Just lat, Just lng)
requireCoordinatePair _ _ = invalidArgs ["latitude and longitude must be provided together"]

normalizeRegionField :: Maybe Text -> Maybe Text
normalizeRegionField Nothing = Nothing
normalizeRegionField (Just raw) =
    let trimmed = T.strip raw
    in if T.null trimmed then Nothing else Just trimmed

userRegionFields :: User -> (Maybe Text, Maybe Text)
userRegionFields user = (normalizeRegionField (userCountryCode user), normalizeRegionField (userState user))

userRegionPair :: User -> Maybe (Text, Text)
userRegionPair user =
    case userRegionFields user of
        (Just countryCodeValue, Just stateValue) -> Just (countryCodeValue, stateValue)
        _ -> Nothing
