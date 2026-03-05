{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Boards (getBoardsR) where

import Import
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (diffUTCTime)
import qualified Prelude as P
import Text.Blaze (preEscapedText)

getBoardsR :: Handler Html
getBoardsR = do
    boards <- runDB $ selectList [] [Asc BoardName]
    now <- liftIO getCurrentTime
    let boardIds = map entityKey boards
    posts <- if P.null boardIds
        then pure []
        else runDB $ selectList [PostBoard <-. boardIds] [Desc PostCreatedAt]
    let authorIds = L.nub $ map (postAuthor . entityVal) posts
    users <- if P.null authorIds
        then pure []
        else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        authorHandle uid = T.toLower $ T.filter (/= ' ') (authorName uid)
        addLatestByBoard acc ent@(Entity _ post) =
            Map.insertWith (\new old -> P.take 2 (old P.++ new)) (postBoard post) [ent] acc
        latestPostsByBoard = P.foldl' addLatestByBoard Map.empty posts
        latestPostsFor boardId = Map.findWithDefault [] boardId latestPostsByBoard
        relativeTime ts =
            let minutes = floor (diffUTCTime now ts / 60) :: Int
                hours = minutes `div` 60
                days = hours `div` 24
            in if minutes < 60 then tshow minutes <> " min ago"
               else if hours < 24 then tshow hours <> " hours ago"
               else if days < 30 then tshow days <> " days ago"
               else tshow $ formatTime defaultTimeLocale "%b %e, %Y" ts
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Boards"
        $(widgetFile "forum/boards-index")
