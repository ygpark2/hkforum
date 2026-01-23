{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Post (postThreadPostR, postPostEditR, postPostDeleteR) where

import Import
import qualified Data.Text as T

postThreadPostR :: ThreadId -> Handler Html
postThreadPostR threadId = do
    userId <- requireAuthId
    content <- runInputPost $ ireq textField (T.pack "content")
    now <- liftIO getCurrentTime
    _ <- runDB $ insert Post
        { postContent = content
        , postAuthor = userId
        , postThread = threadId
        , postCreatedAt = now
        , postUpdatedAt = now
        }
    thread <- runDB $ get404 threadId
    runDB $ update (threadBoard thread) [BoardPostCount +=. 1]
    redirect $ ThreadR threadId

postPostEditR :: PostId -> Handler Html
postPostEditR postId = do
    userId <- requireAuthId
    post <- runDB $ get404 postId
    if postAuthor post /= userId
        then permissionDenied (T.pack "Not allowed")
        else do
            content <- runInputPost $ ireq textField (T.pack "content")
            now <- liftIO getCurrentTime
            runDB $ update postId
                [ PostContent =. content
                , PostUpdatedAt =. now
                ]
            redirect $ ThreadR (postThread post)

postPostDeleteR :: PostId -> Handler Html
postPostDeleteR postId = do
    userId <- requireAuthId
    post <- runDB $ get404 postId
    if postAuthor post /= userId
        then permissionDenied (T.pack "Not allowed")
        else do
            commentCount <- runDB $ count [CommentPost ==. postId]
            thread <- runDB $ get404 (postThread post)
            runDB $ deleteWhere [CommentPost ==. postId]
            runDB $ delete postId
            runDB $ update (threadBoard thread)
                [ BoardPostCount -=. 1
                , BoardCommentCount -=. commentCount
                ]
            redirect $ ThreadR (postThread post)
