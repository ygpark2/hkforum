{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}
module Handler.Boards (getBoardsR, postBoardsR) where

import Import
import Text.Blaze (preEscapedText)
import qualified Data.Text as T
import qualified Prelude as P
import Database.Persist.Sql (fromSqlKey)

getBoardsR :: Handler Html
getBoardsR = do
    boards <- runDB $ selectList [] [Asc BoardName]
    threads <- runDB $ selectList [] [Desc ThreadCreatedAt]
    maybeAuthValue <- maybeAuthId
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum - Home"
        $(widgetFile "boards")

postBoardsR :: Handler Html
postBoardsR = do
    userId <- requireAuthId
    boardId <- runInputPost $ ireq hiddenField "boardId"
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

