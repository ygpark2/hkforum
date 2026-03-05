{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Post
    ( getPostR
    , postPostEditR
    , postPostDeleteR
    , postPostBlockR
    , postPostFlagR
    , postPostLikeR
    , postPostReactR
    , postPostBookmarkR
    , postPostWatchR
    ) where

import Import
import Forum.Tag (loadPostTagsMap, parseTagList, syncPostTags)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as T
import Text.Blaze (preEscapedText)
import qualified Prelude as P

reactionEmojiOptions :: [Text]
reactionEmojiOptions =
    ["👍", "👎", "🎉", "😀", "😮", "❤️", "🚀", "👏", "🤯", "💸", "💯", "😂", "😢", "🤮"]

getPostR :: PostId -> Handler Html
getPostR postId = do
    req <- getRequest
    let mCsrfToken = reqToken req
    now <- liftIO getCurrentTime
    mViewerId <- maybeAuthId
    post <- runDB $ get404 postId
    runDB $ insert_ PostView
        { postViewPost = postId
        , postViewViewer = mViewerId
        , postViewIpAddress = Nothing
        , postViewUserAgent = Nothing
        , postViewCreatedAt = now
        }
    board <- runDB $ get404 (postBoard post)
    comments <- runDB $ selectList [CommentPost ==. postId] [Asc CommentCreatedAt]
    likes <- runDB $ count [PostLikePost ==. postId]
    views <- runDB $ count [PostViewPost ==. postId]
    tagsByPost <- runDB $ loadPostTagsMap [postId]
    let tags = Map.findWithDefault [] postId tagsByPost
    let authorIds =
            L.nub $
                postAuthor post : map (commentAuthor . entityVal) comments
    users <- if P.null authorIds
        then pure []
        else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        commentMap = Map.fromList $ map (\(Entity cid c) -> (cid, c)) comments
        childrenMap =
            P.foldl'
                (\acc ent@(Entity _ c) -> Map.insertWith (++) (commentParentComment c) [ent] acc)
                Map.empty
                comments
        orderedComments = flattenComments childrenMap Nothing Set.empty
        commentDepth cid = min 8 (commentDepthById commentMap cid)
        commentIndentStyle cid =
            "margin-left:" <> tshow (commentDepth cid * (18 :: Int)) <> "px;"
        commentCardClass cid =
            let depth = commentDepth cid
                tone
                    | depth <= 0 = "border-slate-200 bg-slate-50/70"
                    | depth == 1 = "border-slate-300 bg-white"
                    | otherwise = "border-slate-300 bg-slate-100/60"
            in T.unwords ["rounded-xl border p-3 text-sm text-slate-700", tone]
        parentAuthorName c =
            case commentParentComment c of
                Nothing -> Nothing
                Just parentId -> commentAuthor <$> Map.lookup parentId commentMap
        parentAuthorLabel c = fmap authorName (parentAuthorName c)
    isAdminUser <- case mViewerId of
        Nothing -> pure False
        Just viewerId -> do
            mUser <- runDB $ get viewerId
            pure $ maybe False (\u -> userRole u == ("admin" :: Text)) mUser
    let canManagePost =
            case mViewerId of
                Nothing -> False
                Just viewerId -> viewerId == postAuthor post || isAdminUser
    isLiked <- case mViewerId of
        Nothing -> pure False
        Just viewerId -> isJust <$> runDB (getBy $ UniquePostLike viewerId postId)
    isBookmarked <- case mViewerId of
        Nothing -> pure False
        Just viewerId -> isJust <$> runDB (getBy $ UniquePostBookmark viewerId postId)
    let likeState = if isLiked then ("true" :: Text) else "false"
        likeIcon = if isLiked then ("♥" :: Text) else "♡"
        likeLabel = if isLiked then ("Liked" :: Text) else "Like"
        bookmarkState = if isBookmarked then ("true" :: Text) else "false"
    defaultLayout $ do
        setTitle $ preEscapedText $ postTitle post <> " - HKForum"
        $(widgetFile "forum/post")

flattenComments
    :: Map.Map (Maybe CommentId) [Entity Comment]
    -> Maybe CommentId
    -> Set.Set CommentId
    -> [Entity Comment]
flattenComments childrenMap parentId visited =
    concatMap expand children
  where
    children = Map.findWithDefault [] parentId childrenMap
    expand ent@(Entity cid _) =
        if Set.member cid visited
            then []
            else ent : flattenComments childrenMap (Just cid) (Set.insert cid visited)

commentDepthById :: Map.Map CommentId Comment -> CommentId -> Int
commentDepthById commentMap commentId = go commentId Set.empty 0
  where
    go currentId visited depth =
        if Set.member currentId visited
            then depth
            else case Map.lookup currentId commentMap of
                Nothing -> depth
                Just comment ->
                    case commentParentComment comment of
                        Nothing -> depth
                        Just parentId -> go parentId (Set.insert currentId visited) (depth + 1)

postPostEditR :: PostId -> Handler Html
postPostEditR postId = do
    userId <- requireAuthId
    post <- runDB $ get404 postId
    if postAuthor post /= userId
        then permissionDenied (T.pack "Not allowed")
        else do
            title <- runInputPost $ ireq textField "title"
            content <- runInputPost $ ireq textField "content"
            mTags <- runInputPost $ iopt textField "tags"
            now <- liftIO getCurrentTime
            runDB $ update postId
                [ PostTitle =. T.strip title
                , PostContent =. T.strip content
                , PostUpdatedAt =. now
                ]
            runDB $ syncPostTags postId (parseTagList mTags)
            redirect $ PostR postId

postPostDeleteR :: PostId -> Handler Html
postPostDeleteR postId = do
    userId <- requireAuthId
    post <- runDB $ get404 postId
    mViewer <- runDB $ get userId
    let canDelete =
            postAuthor post == userId
                || maybe False (\u -> userRole u == ("admin" :: Text)) mViewer
    unless canDelete $
        permissionDenied (T.pack "Not allowed")
    runDB $ do
        commentRows <- selectList [CommentPost ==. postId] []
        let commentIds = map entityKey commentRows
            commentCount = P.length commentRows
        unless (P.null commentIds) $
            deleteWhere [NotificationComment <-. map Just commentIds]
        deleteWhere [NotificationPost ==. Just postId]
        deleteWhere [PostTagMapPost ==. postId]
        deleteWhere [PostViewPost ==. postId]
        deleteWhere [PostReactionPost ==. postId]
        deleteWhere [PostLikePost ==. postId]
        deleteWhere [PostBookmarkPost ==. postId]
        deleteWhere [PostWatchPost ==. postId]
        deleteWhere [PostFlagPost ==. postId]
        deleteWhere [PostBlockPost ==. postId]
        deleteWhere [CommentPost ==. postId]
        delete postId
        update (postBoard post)
            [ BoardPostCount -=. 1
            , BoardCommentCount -=. commentCount
            ]
    redirect $ BoardR (postBoard post)

postPostBlockR :: PostId -> Handler Value
postPostBlockR postId = do
    userId <- requireAuthId
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostBlock userId postId
    case existing of
        Nothing -> do
            runDB $ insert_ $ PostBlock userId postId now
            returnJson $ object ["message" .= ("Blocked post" :: Text)]
        Just _ -> returnJson $ object ["message" .= ("Already blocked" :: Text)]

postPostFlagR :: PostId -> Handler Value
postPostFlagR postId = do
    userId <- requireAuthId
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostFlag userId postId
    case existing of
        Nothing -> do
            runDB $ insert_ $ PostFlag userId postId now
            returnJson $ object ["message" .= ("Flagged post" :: Text)]
        Just _ -> returnJson $ object ["message" .= ("Already flagged" :: Text)]

postPostLikeR :: PostId -> Handler Value
postPostLikeR postId = do
    userId <- requireAuthId
    post <- runDB $ get404 postId
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostLike userId postId
    case existing of
        Nothing -> do
            runDB $ insert_ $ PostLike userId postId now
            when (postAuthor post /= userId) $ do
                runDB $ insert_ Notification
                    { notificationUser = postAuthor post
                    , notificationActor = Just userId
                    , notificationKind = "post-like"
                    , notificationPost = Just postId
                    , notificationComment = Nothing
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
            likeCount <- runDB $ count [PostLikePost ==. postId]
            returnJson $ object
                [ "message" .= ("Liked post" :: Text)
                , "state" .= ("liked" :: Text)
                , "count" .= likeCount
                ]
        Just (Entity likeId _) -> do
            runDB $ delete likeId
            likeCount <- runDB $ count [PostLikePost ==. postId]
            returnJson $ object
                [ "message" .= ("Unliked post" :: Text)
                , "state" .= ("unliked" :: Text)
                , "count" .= likeCount
                ]

postPostBookmarkR :: PostId -> Handler Value
postPostBookmarkR postId = do
    userId <- requireAuthId
    post <- runDB $ get404 postId
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostBookmark userId postId
    case existing of
        Nothing -> do
            runDB $ insert_ $ PostBookmark userId postId now
            when (postAuthor post /= userId) $ do
                runDB $ insert_ Notification
                    { notificationUser = postAuthor post
                    , notificationActor = Just userId
                    , notificationKind = "post-bookmark"
                    , notificationPost = Just postId
                    , notificationComment = Nothing
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
            returnJson $ object
                [ "message" .= ("Bookmarked post" :: Text)
                , "state" .= ("bookmarked" :: Text)
                ]
        Just (Entity bookmarkId _) -> do
            runDB $ delete bookmarkId
            returnJson $ object
                [ "message" .= ("Removed bookmark" :: Text)
                , "state" .= ("unbookmarked" :: Text)
                ]

postPostWatchR :: PostId -> Handler Value
postPostWatchR postId = do
    userId <- requireAuthId
    now <- liftIO getCurrentTime
    _ <- runDB $ get404 postId
    existing <- runDB $ getBy $ UniquePostWatch userId postId
    case existing of
        Nothing -> do
            runDB $ insert_ $ PostWatch userId postId now
            returnJson $ object
                [ "message" .= ("Watching post" :: Text)
                , "state" .= ("watching" :: Text)
                ]
        Just (Entity watchId _) -> do
            runDB $ delete watchId
            returnJson $ object
                [ "message" .= ("Not watching post" :: Text)
                , "state" .= ("not-watching" :: Text)
                ]

postPostReactR :: PostId -> Handler Value
postPostReactR postId = do
    userId <- requireAuthId
    _ <- runDB $ get404 postId
    emojiRaw <- runInputPost $ ireq textField "emoji"
    let emoji = T.strip emojiRaw
    unless (emoji `elem` reactionEmojiOptions) $
        invalidArgs ["emoji is invalid"]
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostReaction userId postId
    (message, selectedEmoji) <- case existing of
        Nothing -> do
            runDB $ insert_ $ PostReaction userId postId emoji now
            pure ("Reaction added" :: Text, Just emoji)
        Just (Entity reactionId reaction) ->
            if postReactionEmoji reaction == emoji
                then do
                    runDB $ delete reactionId
                    pure ("Reaction removed" :: Text, Nothing)
                else do
                    runDB $ update reactionId [PostReactionEmoji =. emoji, PostReactionCreatedAt =. now]
                    pure ("Reaction updated" :: Text, Just emoji)
    rows <- runDB $ selectList [PostReactionPost ==. postId] []
    let summary = reactionSummary rows
    returnJson $ object
        [ "message" .= message
        , "selected" .= selectedEmoji
        , "reactions" .=
            map
                (\(emojiText, cnt) -> object ["emoji" .= emojiText, "count" .= cnt])
                summary
        ]

reactionSummary :: [Entity PostReaction] -> [(Text, Int)]
reactionSummary rows =
    let countMap =
            P.foldl'
                (\acc (Entity _ r) -> Map.insertWith (+) (postReactionEmoji r) (1 :: Int) acc)
                Map.empty
                rows
        known = mapMaybe (\emoji -> fmap (\cnt -> (emoji, cnt)) (Map.lookup emoji countMap)) reactionEmojiOptions
        extras =
            L.sortBy (\(a, _) (b, _) -> compare a b) $
                filter (\(emoji, _) -> not (emoji `elem` reactionEmojiOptions)) (Map.toList countMap)
    in known P.++ extras
