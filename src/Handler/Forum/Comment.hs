{-# LANGUAGE OverloadedStrings #-}
module Handler.Forum.Comment (postPostCommentR, postCommentEditR, postCommentDeleteR) where

import Import
import SiteSettings
import qualified Data.Set as Set
import qualified Data.Text as T

postPostCommentR :: PostId -> Handler Html
postPostCommentR postId = do
    userId <- requireAuthId
    post <- runDB $ get404 postId
    settingRows <- runDB $ selectList [] []
    let settingMap = siteSettingMapFromEntities settingRows
        maxCommentLength = max 1 (siteSettingInt "max_comment_length" 2000 settingMap)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    mParentCommentId <- runInputPost $ iopt hiddenField "parentCommentId"
    contentRaw <- runInputPost $ ireq textField "content"
    let content = T.strip contentRaw
    when (T.null content) $ invalidArgs ["content is required"]
    when (T.length content > maxCommentLength) $
        invalidArgs ["content exceeds the configured maximum length"]
    when (textContainsBlockedTerm blockedWords content) $
        invalidArgs ["content contains blocked terms"]
    mParentComment <- case mParentCommentId of
        Nothing -> pure Nothing
        Just parentCommentId -> do
            parentComment <- runDB $ get404 parentCommentId
            when (commentPost parentComment /= postId) $
                invalidArgs ["parentCommentId is invalid for this post"]
            pure $ Just (parentCommentId, parentComment)
    now <- liftIO getCurrentTime
    commentId <- runDB $ insert Comment
        { commentContent = content
        , commentAuthor = userId
        , commentPost = postId
        , commentParentComment = fst <$> mParentComment
        , commentCreatedAt = now
        }
    case mParentComment of
        Just (_, parentComment) ->
            when (commentAuthor parentComment /= userId) $ do
                runDB $ insert_ Notification
                    { notificationUser = commentAuthor parentComment
                    , notificationActor = Just userId
                    , notificationKind = "reply"
                    , notificationPost = Just postId
                    , notificationComment = Just commentId
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
        Nothing ->
            when (postAuthor post /= userId) $ do
                runDB $ insert_ Notification
                    { notificationUser = postAuthor post
                    , notificationActor = Just userId
                    , notificationKind = "comment"
                    , notificationPost = Just postId
                    , notificationComment = Just commentId
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
    watcherRows <- runDB $ selectList [PostWatchPost ==. postId] []
    let directRecipient =
            case mParentComment of
                Just (_, parentComment) | commentAuthor parentComment /= userId -> Just (commentAuthor parentComment)
                _ | postAuthor post /= userId -> Just (postAuthor post)
                _ -> Nothing
        excludeSet = Set.fromList $ userId : maybeToList directRecipient
        watcherUserSet = Set.fromList [postWatchUser w | Entity _ w <- watcherRows]
        watcherRecipients =
            Set.toList $
                Set.difference
                    watcherUserSet
                    excludeSet
    forM_ watcherRecipients $ \recipientId ->
        runDB $ insert_ Notification
            { notificationUser = recipientId
            , notificationActor = Just userId
            , notificationKind = "watch-comment"
            , notificationPost = Just postId
            , notificationComment = Just commentId
            , notificationIsRead = False
            , notificationCreatedAt = now
            }
    runDB $ update (postBoard post) [BoardCommentCount +=. 1]
    redirect $ PostR postId

postCommentEditR :: CommentId -> Handler Html
postCommentEditR commentId = do
    userId <- requireAuthId
    comment <- runDB $ get404 commentId
    settingRows <- runDB $ selectList [] []
    let settingMap = siteSettingMapFromEntities settingRows
        maxCommentLength = max 1 (siteSettingInt "max_comment_length" 2000 settingMap)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    if commentAuthor comment /= userId
        then permissionDenied (T.pack "Not allowed")
        else do
            contentRaw <- runInputPost $ ireq textField (T.pack "content")
            let content = T.strip contentRaw
            when (T.null content) $ invalidArgs ["content is required"]
            when (T.length content > maxCommentLength) $
                invalidArgs ["content exceeds the configured maximum length"]
            when (textContainsBlockedTerm blockedWords content) $
                invalidArgs ["content contains blocked terms"]
            runDB $ update commentId [CommentContent =. content]
            redirect $ PostR (commentPost comment)

postCommentDeleteR :: CommentId -> Handler Html
postCommentDeleteR commentId = do
    userId <- requireAuthId
    comment <- runDB $ get404 commentId
    if commentAuthor comment /= userId
        then permissionDenied (T.pack "Not allowed")
        else do
            post <- runDB $ get404 (commentPost comment)
            runDB $ updateWhere [CommentParentComment ==. Just commentId] [CommentParentComment =. Nothing]
            runDB $ delete commentId
            runDB $ update (postBoard post) [BoardCommentCount -=. 1]
            redirect $ PostR (commentPost comment)
