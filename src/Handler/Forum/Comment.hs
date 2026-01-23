{-# LANGUAGE OverloadedStrings #-}
module Handler.Forum.Comment (postPostCommentR, postCommentEditR, postCommentDeleteR) where

import Import
import qualified Data.Text as T
import Data.Time (getCurrentTime)

postPostCommentR :: PostId -> Handler Html
postPostCommentR postId = do
    userId <- requireAuthId
    post <- runDB $ get404 postId
    content <- runInputPost $ ireq textField "content"
    now <- liftIO getCurrentTime
    _ <- runDB $ insert Comment
        { commentContent = content
        , commentAuthor = userId
        , commentPost = postId
        , commentCreatedAt = now
        }
    thread <- runDB $ get404 (postThread post)
    runDB $ update (threadBoard thread) [BoardCommentCount +=. 1]
    redirect $ ThreadR (postThread post)

postCommentEditR :: CommentId -> Handler Html
postCommentEditR commentId = do
    userId <- requireAuthId
    comment <- runDB $ get404 commentId
    if commentAuthor comment /= userId
        then permissionDenied (T.pack "Not allowed")
        else do
            content <- runInputPost $ ireq textField (T.pack "content")
            runDB $ update commentId [CommentContent =. content]
            post <- runDB $ get404 (commentPost comment)
            redirect $ ThreadR (postThread post)

postCommentDeleteR :: CommentId -> Handler Html
postCommentDeleteR commentId = do
    userId <- requireAuthId
    comment <- runDB $ get404 commentId
    if commentAuthor comment /= userId
        then permissionDenied (T.pack "Not allowed")
        else do
            post <- runDB $ get404 (commentPost comment)
            runDB $ delete commentId
            thread <- runDB $ get404 (postThread post)
            runDB $ update (threadBoard thread) [BoardCommentCount -=. 1]
            redirect $ ThreadR (postThread post)
