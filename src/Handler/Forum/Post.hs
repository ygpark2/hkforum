{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Post
    ( postThreadPostR
    , postPostEditR
    , postPostDeleteR
    , postPostBlockR
    , postPostFlagR
    ) where

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
