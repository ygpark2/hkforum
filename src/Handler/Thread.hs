{-# LANGUAGE TemplateHaskell #-}
module Handler.Thread (getThreadR) where

import Import
import qualified Data.Text as T
import Text.Blaze (preEscapedText)
import qualified Prelude as P

getThreadR :: ThreadId -> Handler Html
getThreadR threadId = do
    thread <- runDB $ get404 threadId
    posts <- runDB $ selectList [PostThread ==. threadId] [Asc PostCreatedAt]
    board <- runDB $ get404 (threadBoard thread)
    maybeAuth <- maybeAuthId
    defaultLayout $ do
        setTitle $ preEscapedText $ threadTitle thread <> T.pack " - HKForum"
        toWidget $ preEscapedText $ T.pack "<h1>Thread</h1>"