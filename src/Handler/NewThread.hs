{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Handler.NewThread (getNewThreadR, postNewThreadR) where

import Import
import Text.Blaze (preEscapedText)

getNewThreadR :: BoardId -> Handler Html
getNewThreadR boardId = do
    _ <- requireAuth
    board <- runDB $ get404 boardId
    (widget, enctype) <- generateFormPost newThreadForm
    defaultLayout $ do
        setTitle $ preEscapedText "New Thread"
        toWidget $ preEscapedText "<h1>New Thread</h1>"

postNewThreadR :: BoardId -> Handler Html
postNewThreadR boardId = do
    userId <- requireAuthId
    board <- runDB $ get404 boardId
    ((result, widget), enctype) <- runFormPost newThreadForm
    case result of
        FormSuccess (title, content) -> do
            now <- liftIO getCurrentTime
            threadId <- runDB $ insert Thread
                { threadTitle = title
                , threadContent = unTextarea content
                , threadAuthor = userId
                , threadBoard = boardId
                , threadCreatedAt = now
                , threadUpdatedAt = now
                }
            redirect $ ThreadR threadId
        _ -> defaultLayout $ do
            setTitle $ preEscapedText "New Thread"
            toWidget $ preEscapedText "<h1>New Thread</h1>"

newThreadForm :: Form (Text, Textarea)
newThreadForm = renderDivs $ (,)
    <$> areq textField "Title" Nothing
    <*> areq textareaField "Content" Nothing