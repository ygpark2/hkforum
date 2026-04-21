{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Feed where

import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as T
import Forum.Tag (loadPostTagsMap, syncPostTags)
import Handler.Api.Common
import Handler.Api.Posts (getApiPostR)
import Import
import SiteSettings
import qualified Prelude as P

getApiBoardsR :: Handler Value
getApiBoardsR = do
    ensureApiReadAllowed
    boards <- runDB $ selectList [] [Asc BoardName]
    returnJson $ object ["items" .= map boardSummaryValue boards]

getApiFeedR :: Handler Value
getApiFeedR = do
    ensureApiReadAllowed
    (page, size, offset) <- paginationParams
    settingMap <- loadSettingMap
    mViewer <- maybeApiAuth
    let mViewerId = entityKey <$> mViewer
        mViewerRegion = mViewer >>= (userRegionPair . entityVal)
        feedFetchLimit = max 100 ((page + 1) * size * 8)
        globalLocalRegionFilterEnabled = siteSettingBool "local_region_filter_enabled" True settingMap
    allRecentPosts <- runDB $ selectList [] [Desc PostCreatedAt, LimitTo feedFetchLimit]
    let allPostIds = map entityKey allRecentPosts
        allAuthorIds = L.nub $ map (postAuthor . entityVal) allRecentPosts
    allUsers <- if P.null allAuthorIds then pure [] else runDB $ selectList [UserId <-. allAuthorIds] []
    let allUserMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) allUsers
        authorHandleOf uid =
            case Map.lookup uid allUserMap of
                Nothing -> ""
                Just user ->
                    T.toLower $ T.filter (/= ' ') $ fromMaybe (userIdent user) (userName user)
    comments <- if P.null allPostIds then pure [] else runDB $ selectList [CommentPost <-. allPostIds] []
    likes <- if P.null allPostIds then pure [] else runDB $ selectList [PostLikePost <-. allPostIds] []
    reactions <- if P.null allPostIds then pure [] else runDB $ selectList [PostReactionPost <-. allPostIds] []
    views <- if P.null allPostIds then pure [] else runDB $ selectList [PostViewPost <-. allPostIds] []
    tagsByPost <- runDB $ loadPostTagsMap allPostIds

    mTab <- lookupGetParam "tab"
    mTag <- lookupGetParam "tag"
    mSort <- lookupGetParam "sort"
    mUnread <- lookupGetParam "unread"
    mReplies <- lookupGetParam "replies"
    mReactions <- lookupGetParam "reactions"
    mSites <- lookupGetParam "sites"
    mMedia <- lookupGetParam "media"
    mAuthor <- lookupGetParam "author"
    mLang <- lookupGetParam "lang"
    mContent <- lookupGetParam "q"
    mPostType <- lookupGetParam "postType"

    let feedTab = parseFeedTab mTab
        mTagFilter = normalizeTagFilter mTag
        sortByTrending = normalizeSortTrending mSort
        filterUnread = parseBoolFlag mUnread
        filterReplies = parseBoolFlag mReplies
        filterReactions = parseBoolFlag mReactions
        filterSites = parseBoolFlag mSites
        filterMedia = parseBoolFlag mMedia
        mAuthorFilter = normalizeSearchFilter mAuthor
        languageFilters = normalizeCsvFilters mLang
        mContentFilter = normalizeSearchFilter mContent
        mPostTypeFilter = parsePostTypeFilter mPostType

    viewedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if (feedTab == FeedUnread || filterUnread) && not (P.null allPostIds)
                then runDB $ selectList [PostViewViewer ==. Just viewerId, PostViewPost <-. allPostIds] []
                else pure []
    blockedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null allPostIds
                then pure []
                else runDB $ selectList [PostBlockUser ==. viewerId, PostBlockPost <-. allPostIds] []
    blockedUserRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            runDB $
                selectList
                    [ FilterOr
                        [ UserBlockBlocker ==. viewerId
                        , UserBlockBlocked ==. viewerId
                        ]
                    ]
                    []
    followingRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if feedTab == FeedFollowing
                then runDB $ selectList [UserFollowFollower ==. viewerId] []
                else pure []
    likedInterestRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if feedTab == FeedInterests
                then runDB $ selectList [PostLikeUser ==. viewerId] [Desc PostLikeCreatedAt, LimitTo 400]
                else pure []
    bookmarkedInterestRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if feedTab == FeedInterests
                then runDB $ selectList [PostBookmarkUser ==. viewerId] [Desc PostBookmarkCreatedAt, LimitTo 400]
                else pure []
    likedInterestTags <- runDB $ loadPostTagsMap $ map (postLikePost . entityVal) likedInterestRows
    bookmarkedInterestTags <- runDB $ loadPostTagsMap $ map (postBookmarkPost . entityVal) bookmarkedInterestRows

    let commentCountMap =
            P.foldl'
                (\acc (Entity _ c) -> Map.insertWith (+) (commentPost c) (1 :: Int) acc)
                Map.empty
                comments
        likeCountMap =
            P.foldl'
                (\acc (Entity _ l) -> Map.insertWith (+) (postLikePost l) (1 :: Int) acc)
                Map.empty
                likes
        reactionCountMap =
            P.foldl'
                (\acc (Entity _ r) ->
                    Map.insertWith
                        (Map.unionWith (+))
                        (postReactionPost r)
                        (Map.singleton (postReactionEmoji r) (1 :: Int))
                        acc
                )
                Map.empty
                reactions
        viewCountMap =
            P.foldl'
                (\acc (Entity _ v) -> Map.insertWith (+) (postViewPost v) (1 :: Int) acc)
                Map.empty
                views
        viewedSet = Set.fromList $ map (postViewPost . entityVal) viewedRows
        blockedSet = Set.fromList $ map (postBlockPost . entityVal) blockedRows
        blockedAuthorSet =
            case mViewerId of
                Nothing -> Set.empty
                Just viewerId ->
                    Set.fromList
                        [ if userBlockBlocker row == viewerId then userBlockBlocked row else userBlockBlocker row
                        | Entity _ row <- blockedUserRows
                        ]
        followingSet = Set.fromList $ map (userFollowFollowing . entityVal) followingRows
        interestTagScore =
            addTagWeights 2 (Map.elems bookmarkedInterestTags) $
                addTagWeights 1 (Map.elems likedInterestTags) Map.empty
        commentCountFor pid = Map.findWithDefault 0 pid commentCountMap
        likeCountFor pid = Map.findWithDefault 0 pid likeCountMap
        reactionCountFor pid = P.sum $ Map.elems (Map.findWithDefault Map.empty pid reactionCountMap)
        viewCountFor pid = Map.findWithDefault 0 pid viewCountMap
        tagsFor pid = Map.findWithDefault [] pid tagsByPost
        trendScore pid = (4 * likeCountFor pid) + (3 * commentCountFor pid) + min 20 (viewCountFor pid)
        interestScore pid = P.sum $ map (\tag -> Map.findWithDefault 0 tag interestTagScore) (tagsFor pid)
        postHasTag pid tag = tag `elem` tagsFor pid
        hasUrlInText txt =
            let lowered = T.toLower txt
            in "http://" `T.isInfixOf` lowered || "https://" `T.isInfixOf` lowered
        hasMediaInText txt =
            let lowered = T.toLower txt
            in "!["
                `T.isInfixOf` lowered
                || any (`T.isInfixOf` lowered) [".png", ".jpg", ".jpeg", ".gif", ".webp", ".mp4"]
        postText post = T.toLower $ postTitle post <> " " <> postContent post
        matchesAuthor post =
            case mAuthorFilter of
                Nothing -> True
                Just needle -> needle `T.isInfixOf` authorHandleOf (postAuthor post)
        matchesLanguages pid =
            P.null languageFilters || any (`elem` tagsFor pid) languageFilters
        matchesContent post =
            case mContentFilter of
                Nothing -> True
                Just needle -> needle `T.isInfixOf` postText post
        matchesSites post = not filterSites || hasUrlInText (postContent post)
        matchesMedia post = not filterMedia || hasMediaInText (postContent post)
        matchesReplies pid = not filterReplies || commentCountFor pid > 0
        matchesReactions pid = not filterReactions || reactionCountFor pid > 0
        matchesUnread pid =
            if not filterUnread
                then True
                else case mViewerId of
                    Nothing -> False
                    Just _ -> not (Set.member pid viewedSet)
        matchesPostType post =
            case mPostTypeFilter of
                Nothing -> True
                Just PostTypeText -> not (hasUrlInText (postContent post))
                Just PostTypeLink -> hasUrlInText (postContent post)
                Just PostTypeMedia -> hasMediaInText (postContent post)
        matchesAll pid post =
            not (Set.member pid blockedSet)
                && not (Set.member (postAuthor post) blockedAuthorSet)
                && matchesUnread pid
                && matchesReplies pid
                && matchesReactions pid
                && matchesSites post
                && matchesMedia post
                && matchesAuthor post
                && matchesLanguages pid
                && matchesContent post
                && matchesPostType post
        unreadPosts =
            case mViewerId of
                Nothing -> []
                Just _ ->
                    filter (\(Entity pid _) -> not (Set.member pid viewedSet)) allRecentPosts
        followingPosts =
            case mViewerId of
                Nothing -> []
                Just viewerId ->
                    filter (\(Entity _ post) -> postAuthor post == viewerId || Set.member (postAuthor post) followingSet) allRecentPosts
        localPosts =
            if not globalLocalRegionFilterEnabled
                then []
                else case mViewerRegion of
                    Nothing -> []
                    Just (countryCodeValue, stateValue) ->
                        filter
                            (\(Entity _ post) ->
                                postCountryCode post == Just countryCodeValue
                                    && postState post == Just stateValue
                            )
                            allRecentPosts
        interestsPosts =
            case mViewerId of
                Nothing -> []
                Just _ -> filter (\(Entity pid _) -> interestScore pid > 0) allRecentPosts
        rankedInterestsPosts =
            L.sortBy
                (\(Entity pidA a) (Entity pidB b) ->
                    compare (interestScore pidB, postCreatedAt b) (interestScore pidA, postCreatedAt a)
                )
                interestsPosts
        unsortedBasePosts =
            case feedTab of
                FeedUnread -> unreadPosts
                FeedEverything -> allRecentPosts
                FeedLocal -> localPosts
                FeedTrends -> allRecentPosts
                FeedFollowing -> followingPosts
                FeedInterests -> rankedInterestsPosts
        filteredPosts =
            case mTagFilter of
                Nothing -> unsortedBasePosts
                Just tag -> filter (\(Entity pid _) -> postHasTag pid tag) unsortedBasePosts
        fullyFilteredPosts =
            filter (\(Entity pid post) -> matchesAll pid post) filteredPosts
        sortedPosts =
            if feedTab == FeedTrends || sortByTrending
                then
                    L.sortBy
                        (\(Entity pidA a) (Entity pidB b) ->
                            compare (trendScore pidB, postCreatedAt b) (trendScore pidA, postCreatedAt a)
                        )
                        fullyFilteredPosts
                else fullyFilteredPosts
        pagedPosts = P.take (size + 1) $ P.drop offset sortedPosts
        hasNext = P.length pagedPosts > size
        pagePosts = P.take size pagedPosts
    items <- buildPostSummaryValues mViewerId pagePosts
    returnJson $
        object
            [ "items" .= items
            , "page" .= page
            , "size" .= size
            , "hasNext" .= hasNext
            ]

getApiBoardPostsR :: BoardId -> Handler Value
getApiBoardPostsR boardId = do
    ensureApiReadAllowed
    _ <- requireDbEntity boardId "board_not_found" "Board not found."
    (page, size, offset) <- paginationParams
    mViewer <- maybeApiAuth
    posts <- case activeRegionFilter mViewer of
        RegionFilterUnavailable -> pure []
        RegionFilterDisabled ->
            runDB $ selectList [PostBoard ==. boardId] [Desc PostCreatedAt, OffsetBy offset, LimitTo (size + 1)]
        RegionFilterEnabled countryCodeValue stateValue ->
            runDB $
                selectList
                    [ PostBoard ==. boardId
                    , PostCountryCode ==. Just countryCodeValue
                    , PostState ==. Just stateValue
                    ]
                    [Desc PostCreatedAt, OffsetBy offset, LimitTo (size + 1)]
    blockedUserRows <- case entityKey <$> mViewer of
        Nothing -> pure []
        Just viewerId ->
            runDB $
                selectList
                    [ FilterOr
                        [ UserBlockBlocker ==. viewerId
                        , UserBlockBlocked ==. viewerId
                        ]
                    ]
                    []
    let blockedAuthorSet =
            case entityKey <$> mViewer of
                Nothing -> Set.empty
                Just viewerId ->
                    Set.fromList
                        [ if userBlockBlocker row == viewerId then userBlockBlocked row else userBlockBlocker row
                        | Entity _ row <- blockedUserRows
                        ]
        visiblePosts = filter (\(Entity _ post) -> not (Set.member (postAuthor post) blockedAuthorSet)) posts
        hasNext = P.length visiblePosts > size
        pagePosts = P.take size visiblePosts
    items <- buildPostSummaryValues (entityKey <$> mViewer) pagePosts
    returnJson $
        object
            [ "items" .= items
            , "page" .= page
            , "size" .= size
            , "hasNext" .= hasNext
            ]

postApiBoardPostsR :: BoardId -> Handler Value
postApiBoardPostsR boardId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    _ <- requireDbEntity boardId "board_not_found" "Board not found."
    settingMap <- loadSettingMap
    payload <- requireCheckJsonBody :: Handler PostPayload
    let title = T.strip (postPayloadTitle payload)
        content = T.strip (postPayloadContent payload)
        tags = normalizeApiTags (postPayloadTags payload)
        maxPostTitleLength = max 1 (siteSettingInt "max_post_title_length" 120 settingMap)
        maxPostBodyLength = max 1 (siteSettingInt "max_post_body_length" 10000 settingMap)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    when (T.null title) $ jsonError status400 "invalid_title" "Title is required."
    when (T.null content) $ jsonError status400 "invalid_content" "Content is required."
    when (T.length title > maxPostTitleLength) $
        jsonError status400 "invalid_title" "Title exceeds the configured maximum length."
    when (T.length content > maxPostBodyLength) $
        jsonError status400 "invalid_content" "Content exceeds the configured maximum length."
    when (textContainsBlockedTerm blockedWords (title <> " " <> content)) $
        jsonError status400 "blocked_terms" "Content contains blocked terms."
    (mLatitudeValue, mLongitudeValue) <- requireCoordinatePairJson (postPayloadLatitude payload) (postPayloadLongitude payload)
    let (mCountryCodeValue, mStateValue) = userRegionFields (entityVal viewer)
    now <- liftIO getCurrentTime
    postId <- runDB $ insert Post
        { postTitle = title
        , postContent = content
        , postAuthor = viewerId
        , postBoard = boardId
        , postCountryCode = mCountryCodeValue
        , postState = mStateValue
        , postLatitude = mLatitudeValue
        , postLongitude = mLongitudeValue
        , postCreatedAt = now
        , postUpdatedAt = now
        }
    runDB $ syncPostTags postId tags
    runDB $ update boardId [BoardPostCount +=. 1]
    getApiPostR postId
