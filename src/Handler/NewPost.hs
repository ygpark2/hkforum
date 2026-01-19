{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Handler.NewPost (getNewPostR, postNewPostR) where

import Import
import Text.Blaze (preEscapedText)

getNewPostR :: ThreadId -> Handler Html
getNewPostR threadId = do
    _ <- requireAuth
    thread <- runDB $ get404 threadId
    (widget, enctype) <- generateFormPost newPostForm
    defaultLayout $ do
        setTitle $ preEscapedText "New Post"
        toWidget $ preEscapedText "<h1>New Post</h1>"

postNewPostR :: ThreadId -> Handler Html
postNewPostR threadId = do
    userId <- requireAuthId
    thread <- runDB $ get404 threadId
    ((result, widget), enctype) <- runFormPost newPostForm
    case result of
        FormSuccess content -> do
            now <- liftIO getCurrentTime
            _ <- runDB $ insert Post
                { postContent = unTextarea content
                , postAuthor = userId
                , postThread = threadId
                , postCreatedAt = now
                , postUpdatedAt = now
                }
            redirect $ ThreadR threadId
        _ -> defaultLayout $ do
            setTitle $ preEscapedText "New Post"
            toWidget $ preEscapedText "<h1>New Post</h1>"

newPostForm :: Form Textarea
newPostForm = renderDivs $ areq textareaField "Content" Nothing