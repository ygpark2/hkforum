{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Handler.Board (getBoardR, postBoardR) where

import Import
import Data.Time (getCurrentTime)
import Yesod.Form (fsLabel)
import qualified Data.Text as T
import Text.Blaze (preEscapedText)
import qualified Prelude as P

getBoardR :: BoardId -> Handler Html
getBoardR boardId = do
    board <- runDB $ get404 boardId
    boards <- runDB $ selectList [] [Asc BoardName]
    threads <- runDB $ selectList [ThreadBoard ==. boardId] [Desc ThreadCreatedAt]
    maybeAuth <- maybeAuthId
    defaultLayout $ do
        setTitle $ preEscapedText $ boardName board <> T.pack " - HKForum"
        toWidget $ preEscapedText $ T.pack "<h1>Board</h1>"

postBoardR :: BoardId -> Handler Html
postBoardR boardId = do
    userId <- requireAuthId
    board <- runDB $ get404 boardId
    title <- runInputPost $ ireq textField "title"
    content <- runInputPost $ ireq textareaField "content"
    now <- liftIO getCurrentTime
    _ <- runDB $ insert Thread
        { threadTitle = title
        , threadContent = unTextarea content
        , threadAuthor = userId
        , threadBoard = boardId
        , threadCreatedAt = now
        , threadUpdatedAt = now
        }
    redirect $ BoardR boardId