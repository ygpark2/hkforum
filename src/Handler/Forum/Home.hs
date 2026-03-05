{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Home (getHomeR, postHomeR) where

import Import
import Forum.Tag (loadPostTagsMap, parseTagList, syncPostTags)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as T
import Data.Time (diffUTCTime)
import Text.Blaze (preEscapedText)
import qualified Prelude as P

reactionEmojiOptions :: [Text]
reactionEmojiOptions =
    ["👍", "👎", "🎉", "😀", "😮", "❤️", "🚀", "👏", "🤯", "💸", "💯", "😂", "😢", "🤮"]

data FeedTab
    = FeedUnread
    | FeedEverything
    | FeedTrends
    | FeedFollowing
    | FeedInterests
    deriving (Eq)

data PostTypeFilter
    = PostTypeText
    | PostTypeLink
    | PostTypeMedia
    deriving (Eq)

getHomeR :: Handler Html
getHomeR = do
    now <- liftIO getCurrentTime
    mViewerId <- maybeAuthId
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
    let mTagFilter = normalizeTagFilter mTag
        hasTagFilter = isJust mTagFilter
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
        hasAdvancedFilters =
            filterUnread
                || filterReplies
                || filterReactions
                || filterSites
                || filterMedia
                || isJust mAuthorFilter
                || not (P.null languageFilters)
                || isJust mContentFilter
                || isJust mPostTypeFilter
    let feedTab = parseFeedTab mTab
    boards <- runDB $ selectList [] [Asc BoardName]
    allRecentPosts <- runDB $ selectList [] [Desc PostCreatedAt, LimitTo 300]
    let allPostIds = map entityKey allRecentPosts
        allAuthorIds = L.nub $ map (postAuthor . entityVal) allRecentPosts
        boardMap = Map.fromList $ map (\(Entity bid b) -> (bid, b)) boards
    allUsers <- if P.null allAuthorIds
        then pure []
        else runDB $ selectList [UserId <-. allAuthorIds] []
    let allUserMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) allUsers
        authorNameOf uid = Map.findWithDefault ("Unknown" :: Text) uid allUserMap
        authorHandleOf uid = T.toLower $ T.filter (/= ' ') (authorNameOf uid)
    comments <- if P.null allPostIds
        then pure []
        else runDB $ selectList [CommentPost <-. allPostIds] []
    likes <- if P.null allPostIds
        then pure []
        else runDB $ selectList [PostLikePost <-. allPostIds] []
    reactions <- if P.null allPostIds
        then pure []
        else runDB $ selectList [PostReactionPost <-. allPostIds] []
    views <- if P.null allPostIds
        then pure []
        else runDB $ selectList [PostViewPost <-. allPostIds] []
    tagsByPost <- runDB $ loadPostTagsMap allPostIds
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
        followingSet = Set.fromList $ map (userFollowFollowing . entityVal) followingRows
        interestTagScore =
            addTagWeights 2 (Map.elems bookmarkedInterestTags) $
                addTagWeights 1 (Map.elems likedInterestTags) Map.empty
        commentCountFor pid = Map.findWithDefault 0 pid commentCountMap
        likeCountFor pid = Map.findWithDefault 0 pid likeCountMap
        reactionCountFor pid = P.sum $ Map.elems (Map.findWithDefault Map.empty pid reactionCountMap)
        reactionSummaryFor pid =
            let cntMap = Map.findWithDefault Map.empty pid reactionCountMap
                known = mapMaybe (\emoji -> fmap (\cnt -> (emoji, cnt)) (Map.lookup emoji cntMap)) reactionEmojiOptions
                extras =
                    L.sortBy (\(a, _) (b, _) -> compare a b) $
                        filter (\(emoji, _) -> not (emoji `elem` reactionEmojiOptions)) (Map.toList cntMap)
            in known P.++ extras
        viewCountFor pid = Map.findWithDefault 0 pid viewCountMap
        tagsFor pid = Map.findWithDefault [] pid tagsByPost
        trendScore pid =
            (4 * likeCountFor pid) + (3 * commentCountFor pid) + min 20 (viewCountFor pid)
        interestScore pid =
            P.sum $ map (\tag -> Map.findWithDefault 0 tag interestTagScore) (tagsFor pid)
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
        isVisibleByBlock pid = not (Set.member pid blockedSet)
        matchesAll pid post =
            isVisibleByBlock pid
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
                Nothing -> allRecentPosts
                Just _ ->
                    filter (\(Entity pid _) -> not (Set.member pid viewedSet)) allRecentPosts
        followingPosts =
            case mViewerId of
                Nothing -> []
                Just viewerId ->
                    filter
                        (\(Entity _ p) -> postAuthor p == viewerId || Set.member (postAuthor p) followingSet)
                        allRecentPosts
        interestsPosts =
            case mViewerId of
                Nothing -> []
                Just _ ->
                    filter (\(Entity pid _) -> interestScore pid > 0) allRecentPosts
        rankedInterestsPosts =
            L.sortBy
                (\(Entity pidA a) (Entity pidB b) ->
                    compare
                        (interestScore pidB, postCreatedAt b)
                        (interestScore pidA, postCreatedAt a)
                )
                interestsPosts
        unsortedBasePosts =
            case feedTab of
                FeedUnread -> unreadPosts
                FeedEverything -> allRecentPosts
                FeedTrends -> allRecentPosts
                FeedFollowing -> followingPosts
                FeedInterests -> rankedInterestsPosts
        filteredPosts =
            case mTagFilter of
                Nothing -> unsortedBasePosts
                Just tag ->
                    filter (\(Entity pid _) -> postHasTag pid tag) unsortedBasePosts
        fullyFilteredPosts =
            filter (\(Entity pid post) -> matchesAll pid post) filteredPosts
        sortedPosts =
            if feedTab == FeedTrends || sortByTrending
                then L.sortBy
                    (\(Entity pidA a) (Entity pidB b) ->
                        compare
                            (trendScore pidB, postCreatedAt b)
                            (trendScore pidA, postCreatedAt a)
                    )
                    fullyFilteredPosts
                else fullyFilteredPosts
        posts = P.take 100 sortedPosts
        selectedPostIds = map entityKey posts
        feedEmptyMessage =
            case mTagFilter of
                Just tag -> "No posts for #" <> tag <> "."
                Nothing ->
                    if filterUnread && isNothing mViewerId
                        then "Login to use unread filter."
                        else if hasAdvancedFilters
                            then "No posts matched current tab filters."
                            else case feedTab of
                                FeedEverything -> ("No posts yet." :: Text)
                                FeedUnread ->
                                    case mViewerId of
                                        Nothing -> "Login to use unread feed."
                                        Just _ -> "No unread posts."
                                FeedTrends -> "No trending posts yet."
                                FeedFollowing ->
                                    case mViewerId of
                                        Nothing -> "Login to see posts from users you follow."
                                        Just _ ->
                                            if Set.null followingSet
                                                then "Follow users to populate this tab."
                                                else "No posts from followed users yet."
                                FeedInterests ->
                                    case mViewerId of
                                        Nothing -> "Login to see your interest feed."
                                        Just _ ->
                                            if Map.null interestTagScore
                                                then "Like or bookmark tagged posts to build interests."
                                                else "No posts matched your interests yet."
    let authorName = authorNameOf
        authorHandle = authorHandleOf
        boardLabel bid = maybe ("Unknown board" :: Text) boardName (Map.lookup bid boardMap)
        relativeTime ts =
            let minutes = floor (diffUTCTime now ts / 60) :: Int
                hours = minutes `div` 60
                days = hours `div` 24
            in if minutes < 60 then tshow minutes <> " min ago"
               else if hours < 24 then tshow hours <> " hours ago"
               else if days < 30 then tshow days <> " days ago"
               else tshow $ formatTime defaultTimeLocale "%b %e, %Y" ts
    bookmarkedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null selectedPostIds
                then pure []
                else runDB $ selectList [PostBookmarkUser ==. viewerId, PostBookmarkPost <-. selectedPostIds] []
    viewerReactionRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null selectedPostIds
                then pure []
                else runDB $ selectList [PostReactionUser ==. viewerId, PostReactionPost <-. selectedPostIds] []
    watchedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null selectedPostIds
                then pure []
                else runDB $ selectList [PostWatchUser ==. viewerId, PostWatchPost <-. selectedPostIds] []
    let bookmarkSet = Set.fromList $ map (postBookmarkPost . entityVal) bookmarkedRows
        viewerReactionMap = Map.fromList $ map (\(Entity _ r) -> (postReactionPost r, postReactionEmoji r)) viewerReactionRows
        watchSet = Set.fromList $ map (postWatchPost . entityVal) watchedRows
        isBookmarked pid = Set.member pid bookmarkSet
        isWatching pid = Set.member pid watchSet
        viewerReactionFor pid = Map.lookup pid viewerReactionMap
        bookmarkState pid = if isBookmarked pid then ("true" :: Text) else "false"
        watchState pid = if isWatching pid then ("true" :: Text) else "false"
        watchIcon pid = if isWatching pid then ("🙈" :: Text) else "👁"
        watchLabel pid = if isWatching pid then ("Not watching" :: Text) else "Watch"
        feedTabs = [FeedUnread, FeedEverything, FeedTrends, FeedFollowing, FeedInterests]
        isActiveTab tab = tab == feedTab
        tabClass tab =
            if isActiveTab tab && not hasTagFilter
                then ("border-b-2 border-slate-900 pb-1 text-slate-900" :: Text)
                else "transition hover:text-slate-800"
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Home"
        $(widgetFile "forum/boards")

addTagWeights :: Int -> [[Text]] -> Map.Map Text Int -> Map.Map Text Int
addTagWeights weight tagGroups initial =
    P.foldl'
        (\acc tags ->
            P.foldl'
                (\inner tag -> Map.insertWith (+) tag weight inner)
                acc
                tags
        )
        initial
        tagGroups

parseFeedTab :: Maybe Text -> FeedTab
parseFeedTab mRaw =
    case fmap (T.toLower . T.strip) mRaw of
        Just "unread" -> FeedUnread
        Just "everything" -> FeedEverything
        Just "trends" -> FeedTrends
        Just "following" -> FeedFollowing
        Just "interests" -> FeedInterests
        _ -> FeedEverything

feedTabParam :: FeedTab -> Text
feedTabParam tab =
    case tab of
        FeedUnread -> "unread"
        FeedEverything -> "everything"
        FeedTrends -> "trends"
        FeedFollowing -> "following"
        FeedInterests -> "interests"

feedTabLabel :: FeedTab -> Text
feedTabLabel tab =
    case tab of
        FeedUnread -> "Unread"
        FeedEverything -> "Everything"
        FeedTrends -> "Trends"
        FeedFollowing -> "Following"
        FeedInterests -> "Interests"

normalizeTagFilter :: Maybe Text -> Maybe Text
normalizeTagFilter Nothing = Nothing
normalizeTagFilter (Just raw) =
    let cleaned = T.toLower $ T.dropWhile (== '#') $ T.strip raw
    in if T.null cleaned then Nothing else Just cleaned

parseBoolFlag :: Maybe Text -> Bool
parseBoolFlag mRaw =
    case fmap (T.toLower . T.strip) mRaw of
        Just "1" -> True
        Just "true" -> True
        Just "yes" -> True
        Just "on" -> True
        _ -> False

normalizeSortTrending :: Maybe Text -> Bool
normalizeSortTrending mRaw =
    case fmap (T.toLower . T.strip) mRaw of
        Just "trending" -> True
        _ -> False

normalizeSearchFilter :: Maybe Text -> Maybe Text
normalizeSearchFilter Nothing = Nothing
normalizeSearchFilter (Just raw) =
    let cleaned = T.toLower $ T.strip raw
    in if T.null cleaned then Nothing else Just cleaned

normalizeCsvFilters :: Maybe Text -> [Text]
normalizeCsvFilters Nothing = []
normalizeCsvFilters (Just raw) =
    P.filter (not . T.null) $
        map (T.toLower . T.strip) (T.splitOn "," raw)

parsePostTypeFilter :: Maybe Text -> Maybe PostTypeFilter
parsePostTypeFilter mRaw =
    case fmap (T.toLower . T.strip) mRaw of
        Just "text" -> Just PostTypeText
        Just "link" -> Just PostTypeLink
        Just "media" -> Just PostTypeMedia
        _ -> Nothing

postHomeR :: Handler Html
postHomeR = do
    userId <- requireAuthId
    boardId <- runInputPost $ ireq hiddenField "boardId"
    mTitle <- runInputPost $ iopt textField "title"
    mTags <- runInputPost $ iopt textField "tags"
    contentRaw <- runInputPost $ ireq textField "content"
    _ <- runDB $ get404 boardId
    let content = T.strip contentRaw
        title =
            case fmap (T.strip) mTitle of
                Just t | not (T.null t) -> t
                _ ->
                    let firstLine = T.takeWhile (/= '\n') content
                    in if T.null firstLine then "Untitled" else T.take 80 firstLine
    when (T.null content) $ invalidArgs ["content is required"]
    now <- liftIO getCurrentTime
    postId <- runDB $ insert Post
        { postTitle = title
        , postContent = content
        , postAuthor = userId
        , postBoard = boardId
        , postCreatedAt = now
        , postUpdatedAt = now
        }
    runDB $ syncPostTags postId (parseTagList mTags)
    runDB $ update boardId [BoardPostCount +=. 1]
    redirect HomeR
