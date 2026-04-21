{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Posts where

import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as T
import Forum.Tag (loadPostTagsMap, syncPostTags)
import Handler.Api.Common
import Import
import SiteSettings
import qualified Prelude as P

getApiPostR :: PostId -> Handler Value
getApiPostR postId = do
    ensureApiReadAllowed
    mViewerId <- maybeApiAuthId
    post <- requireDbEntity postId "post_not_found" "Post not found."
    now <- liftIO getCurrentTime
    runDB $ insert_ PostView
        { postViewPost = postId
        , postViewViewer = mViewerId
        , postViewIpAddress = Nothing
        , postViewUserAgent = Nothing
        , postViewCreatedAt = now
        }
    board <- requireDbEntity (postBoard (entityVal post)) "board_not_found" "Board not found."
    comments <- runDB $ selectList [CommentPost ==. postId] [Asc CommentCreatedAt]
    likes <- runDB $ count [PostLikePost ==. postId]
    views <- runDB $ count [PostViewPost ==. postId]
    tagsByPost <- runDB $ loadPostTagsMap [postId]
    reactionRows <- runDB $ selectList [PostReactionPost ==. postId] []
    let tags = Map.findWithDefault [] postId tagsByPost
        authorIds = L.nub $ postAuthor (entityVal post) : map (commentAuthor . entityVal) comments
    users <- if P.null authorIds then pure [] else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) users
        commentsValue = map (commentValue userMap) comments
    isLiked <- case mViewerId of
        Nothing -> pure False
        Just viewerId -> isJust <$> runDB (getBy $ UniquePostLike viewerId postId)
    isBookmarked <- case mViewerId of
        Nothing -> pure False
        Just viewerId -> isJust <$> runDB (getBy $ UniquePostBookmark viewerId postId)
    isWatching <- case mViewerId of
        Nothing -> pure False
        Just viewerId -> isJust <$> runDB (getBy $ UniquePostWatch viewerId postId)
    viewerReaction <- case mViewerId of
        Nothing -> pure Nothing
        Just viewerId ->
            fmap (postReactionEmoji . entityVal) <$> runDB (getBy $ UniquePostReaction viewerId postId)
    returnJson $
        object
            [ "data" .= object
                [ "post" .= postSummaryValue
                    userMap
                    (Map.singleton (entityKey board) (entityVal board))
                    (Map.singleton postId likes)
                    (Map.singleton postId (P.length comments))
                    (Map.singleton postId views)
                    (Map.singleton postId reactionRows)
                    (Map.singleton postId tags)
                    (if isLiked then Just (Set.singleton postId) else Nothing)
                    (if isBookmarked then Just (Set.singleton postId) else Nothing)
                    (if isWatching then Just (Set.singleton postId) else Nothing)
                    (case viewerReaction of
                        Nothing -> Nothing
                        Just emoji -> Just (Map.singleton postId emoji))
                    post
                , "reactions" .= reactionSummaryValue reactionRows
                , "comments" .= commentsValue
                ]
            ]

patchApiPostR :: PostId -> Handler Value
patchApiPostR postId = do
    viewerId <- requireApiAuthId
    post <- requireDbEntity postId "post_not_found" "Post not found."
    let currentPost = entityVal post
    when (postAuthor currentPost /= viewerId) $
        jsonError status403 "forbidden" "Not allowed."
    settingMap <- loadSettingMap
    payload <- requireCheckJsonBody :: Handler UpdatePostPayload
    let title = T.strip (updatePostTitle payload)
        content = T.strip (updatePostContent payload)
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
    now <- liftIO getCurrentTime
    runDB $
        update postId
            [ PostTitle =. title
            , PostContent =. content
            , PostUpdatedAt =. now
            ]
    forM_ (updatePostTags payload) $ \tags ->
        runDB $ syncPostTags postId (normalizeApiTags (Just tags))
    getApiPostR postId

deleteApiPostR :: PostId -> Handler Value
deleteApiPostR postId = do
    viewerId <- requireApiAuthId
    post <- requireDbEntity postId "post_not_found" "Post not found."
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    let currentPost = entityVal post
        canDelete = postAuthor currentPost == viewerId || userRole (entityVal viewer) == ("admin" :: Text)
    unless canDelete $
        jsonError status403 "forbidden" "Not allowed."
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
        update (postBoard currentPost)
            [ BoardPostCount -=. 1
            , BoardCommentCount -=. commentCount
            ]
    returnJson $ object ["message" .= ("Post deleted." :: Text)]

getApiPostCommentsR :: PostId -> Handler Value
getApiPostCommentsR postId = do
    ensureApiReadAllowed
    _ <- requireDbEntity postId "post_not_found" "Post not found."
    comments <- runDB $ selectList [CommentPost ==. postId] [Asc CommentCreatedAt]
    let authorIds = L.nub $ map (commentAuthor . entityVal) comments
    users <- if P.null authorIds then pure [] else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) users
    returnJson $ object ["items" .= map (commentValue userMap) comments]

postApiPostCommentsR :: PostId -> Handler Value
postApiPostCommentsR postId = do
    viewerId <- requireApiAuthId
    post <- requireDbEntity postId "post_not_found" "Post not found."
    settingMap <- loadSettingMap
    payload <- requireCheckJsonBody :: Handler CommentPayload
    let content = T.strip (commentPayloadContent payload)
        maxCommentLength = max 1 (siteSettingInt "max_comment_length" 2000 settingMap)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    when (T.null content) $ jsonError status400 "invalid_content" "Content is required."
    when (T.length content > maxCommentLength) $
        jsonError status400 "invalid_content" "Content exceeds the configured maximum length."
    when (textContainsBlockedTerm blockedWords content) $
        jsonError status400 "blocked_terms" "Content contains blocked terms."
    mParentComment <- case commentPayloadParentCommentId payload of
        Nothing -> pure Nothing
        Just parentCommentId -> do
            parentComment <- requireDbEntity parentCommentId "comment_not_found" "Comment not found."
            when (commentPost (entityVal parentComment) /= postId) $
                jsonError status400 "invalid_parent_comment" "parentCommentId is invalid for this post."
            pure $ Just parentComment
    now <- liftIO getCurrentTime
    commentId <- runDB $ insert Comment
        { commentContent = content
        , commentAuthor = viewerId
        , commentPost = postId
        , commentParentComment = entityKey <$> mParentComment
        , commentCreatedAt = now
        }
    let currentPost = entityVal post
    case mParentComment of
        Just parentComment ->
            when (commentAuthor (entityVal parentComment) /= viewerId) $
                runDB $ insert_ Notification
                    { notificationUser = commentAuthor (entityVal parentComment)
                    , notificationActor = Just viewerId
                    , notificationKind = "reply"
                    , notificationPost = Just postId
                    , notificationComment = Just commentId
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
        Nothing ->
            when (postAuthor currentPost /= viewerId) $
                runDB $ insert_ Notification
                    { notificationUser = postAuthor currentPost
                    , notificationActor = Just viewerId
                    , notificationKind = "comment"
                    , notificationPost = Just postId
                    , notificationComment = Just commentId
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
    watcherRows <- runDB $ selectList [PostWatchPost ==. postId] []
    let directRecipient =
            case mParentComment of
                Just parentComment | commentAuthor (entityVal parentComment) /= viewerId -> Just (commentAuthor (entityVal parentComment))
                _ | postAuthor currentPost /= viewerId -> Just (postAuthor currentPost)
                _ -> Nothing
        excludeSet = Set.fromList $ viewerId : maybeToList directRecipient
        watcherUserSet = Set.fromList [postWatchUser watch | Entity _ watch <- watcherRows]
        watcherRecipients = Set.toList $ Set.difference watcherUserSet excludeSet
    forM_ watcherRecipients $ \recipientId ->
        runDB $ insert_ Notification
            { notificationUser = recipientId
            , notificationActor = Just viewerId
            , notificationKind = "watch-comment"
            , notificationPost = Just postId
            , notificationComment = Just commentId
            , notificationIsRead = False
            , notificationCreatedAt = now
            }
    runDB $ update (postBoard currentPost) [BoardCommentCount +=. 1]
    created <- requireDbEntity commentId "comment_not_found" "Comment not found."
    author <- requireDbEntity viewerId "user_not_found" "User not found."
    sendResponseStatus status201 $
        object
            [ "comment" .= commentValue (Map.singleton viewerId (entityVal author)) created
            ]

patchApiCommentR :: CommentId -> Handler Value
patchApiCommentR commentId = do
    viewerId <- requireApiAuthId
    comment <- requireDbEntity commentId "comment_not_found" "Comment not found."
    when (commentAuthor (entityVal comment) /= viewerId) $
        jsonError status403 "forbidden" "Not allowed."
    settingMap <- loadSettingMap
    payload <- requireCheckJsonBody :: Handler UpdateCommentPayload
    let content = T.strip (updateCommentContent payload)
        maxCommentLength = max 1 (siteSettingInt "max_comment_length" 2000 settingMap)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    when (T.null content) $ jsonError status400 "invalid_content" "Content is required."
    when (T.length content > maxCommentLength) $
        jsonError status400 "invalid_content" "Content exceeds the configured maximum length."
    when (textContainsBlockedTerm blockedWords content) $
        jsonError status400 "blocked_terms" "Content contains blocked terms."
    runDB $ update commentId [CommentContent =. content]
    updated <- requireDbEntity commentId "comment_not_found" "Comment not found."
    author <- requireDbEntity viewerId "user_not_found" "User not found."
    returnJson $
        object
            [ "comment" .= commentValue (Map.singleton viewerId (entityVal author)) updated
            ]

deleteApiCommentR :: CommentId -> Handler Value
deleteApiCommentR commentId = do
    viewerId <- requireApiAuthId
    comment <- requireDbEntity commentId "comment_not_found" "Comment not found."
    when (commentAuthor (entityVal comment) /= viewerId) $
        jsonError status403 "forbidden" "Not allowed."
    post <- requireDbEntity (commentPost (entityVal comment)) "post_not_found" "Post not found."
    runDB $ updateWhere [CommentParentComment ==. Just commentId] [CommentParentComment =. Nothing]
    runDB $ delete commentId
    runDB $ update (postBoard (entityVal post)) [BoardCommentCount -=. 1]
    returnJson $ object ["message" .= ("Comment deleted." :: Text)]

postApiPostLikeR :: PostId -> Handler Value
postApiPostLikeR postId = do
    viewerId <- requireApiAuthId
    post <- requireDbEntity postId "post_not_found" "Post not found."
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostLike viewerId postId
    case existing of
        Nothing -> do
            runDB $ insert_ $ PostLike viewerId postId now
            when (postAuthor (entityVal post) /= viewerId) $
                runDB $ insert_ Notification
                    { notificationUser = postAuthor (entityVal post)
                    , notificationActor = Just viewerId
                    , notificationKind = "post-like"
                    , notificationPost = Just postId
                    , notificationComment = Nothing
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
            likeCount <- runDB $ count [PostLikePost ==. postId]
            returnJson $
                object
                    [ "message" .= ("Liked post" :: Text)
                    , "state" .= ("liked" :: Text)
                    , "count" .= likeCount
                    ]
        Just (Entity likeId _) -> do
            runDB $ delete likeId
            likeCount <- runDB $ count [PostLikePost ==. postId]
            returnJson $
                object
                    [ "message" .= ("Unliked post" :: Text)
                    , "state" .= ("unliked" :: Text)
                    , "count" .= likeCount
                    ]

postApiPostBookmarkR :: PostId -> Handler Value
postApiPostBookmarkR postId = do
    viewerId <- requireApiAuthId
    post <- requireDbEntity postId "post_not_found" "Post not found."
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostBookmark viewerId postId
    case existing of
        Nothing -> do
            runDB $ insert_ $ PostBookmark viewerId postId now
            when (postAuthor (entityVal post) /= viewerId) $
                runDB $ insert_ Notification
                    { notificationUser = postAuthor (entityVal post)
                    , notificationActor = Just viewerId
                    , notificationKind = "post-bookmark"
                    , notificationPost = Just postId
                    , notificationComment = Nothing
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
            returnJson $
                object
                    [ "message" .= ("Bookmarked post" :: Text)
                    , "state" .= ("bookmarked" :: Text)
                    ]
        Just (Entity bookmarkId _) -> do
            runDB $ delete bookmarkId
            returnJson $
                object
                    [ "message" .= ("Removed bookmark" :: Text)
                    , "state" .= ("unbookmarked" :: Text)
                    ]

postApiPostWatchR :: PostId -> Handler Value
postApiPostWatchR postId = do
    viewerId <- requireApiAuthId
    _ <- requireDbEntity postId "post_not_found" "Post not found."
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostWatch viewerId postId
    case existing of
        Nothing -> do
            runDB $ insert_ $ PostWatch viewerId postId now
            returnJson $
                object
                    [ "message" .= ("Watching post" :: Text)
                    , "state" .= ("watching" :: Text)
                    ]
        Just (Entity watchId _) -> do
            runDB $ delete watchId
            returnJson $
                object
                    [ "message" .= ("Not watching post" :: Text)
                    , "state" .= ("not-watching" :: Text)
                    ]

postApiPostReactR :: PostId -> Handler Value
postApiPostReactR postId = do
    viewerId <- requireApiAuthId
    payload <- requireCheckJsonBody :: Handler ReactionPayload
    _ <- requireDbEntity postId "post_not_found" "Post not found."
    let emoji = T.strip (reactionPayloadEmoji payload)
    unless (emoji `elem` reactionEmojiOptions) $
        jsonError status400 "invalid_emoji" "emoji is invalid"
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostReaction viewerId postId
    (messageText, selectedEmoji) <- case existing of
        Nothing -> do
            runDB $ insert_ $ PostReaction viewerId postId emoji now
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
    returnJson $
        object
            [ "message" .= messageText
            , "selected" .= selectedEmoji
            , "reactions" .= reactionSummaryValue rows
            ]

postApiPostFlagR :: PostId -> Handler Value
postApiPostFlagR postId = do
    viewerId <- requireApiAuthId
    _ <- requireDbEntity postId "post_not_found" "Post not found."
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostFlag viewerId postId
    case existing of
        Nothing -> do
            runDB $ insert_ $ PostFlag viewerId postId now
            returnJson $ object ["message" .= ("Flagged post" :: Text)]
        Just _ ->
            returnJson $ object ["message" .= ("Already flagged" :: Text)]

postApiPostBlockR :: PostId -> Handler Value
postApiPostBlockR postId = do
    viewerId <- requireApiAuthId
    _ <- requireDbEntity postId "post_not_found" "Post not found."
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniquePostBlock viewerId postId
    case existing of
        Nothing -> do
            runDB $ insert_ $ PostBlock viewerId postId now
            returnJson $ object ["message" .= ("Blocked post" :: Text)]
        Just _ ->
            returnJson $ object ["message" .= ("Already blocked" :: Text)]
