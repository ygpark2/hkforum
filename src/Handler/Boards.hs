{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}
module Handler.Boards (getBoardsR) where

import Import
import qualified Data.Text as T
import Text.Blaze (preEscapedText)

getBoardsR :: Handler Html
getBoardsR = do
    boards <- runDB $ selectList [] [Asc BoardName]
    maybeAuth <- maybeAuthId
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum - Home"
        $(widgetFile "boards")
