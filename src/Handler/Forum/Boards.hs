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
import Text.Read (readMaybe)

getBoardsR :: Handler Html
getBoardsR = do
    boards <- runDB $ selectList [] [Asc BoardName]
    now <- liftIO getCurrentTime
    let boardIds = map entityKey boards
    threads <-
        if P.null boardIds
            then pure []
            else runDB $ selectList [ThreadBoard <-. boardIds] [Desc ThreadCreatedAt]
    let authorIds = L.nub $ map (threadAuthor . entityVal) threads
    users <-
        if P.null authorIds
            then pure []
            else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        authorHandle uid = T.toLower $ T.filter (/= ' ') (authorName uid)
        addLatestByBoard acc ent@(Entity _ thread) =
            Map.insertWith (\new old -> P.take 2 (old P.++ new)) (threadBoard thread) [ent] acc
        latestThreadsByBoard = P.foldl' addLatestByBoard Map.empty threads
        latestThreadsFor boardId = Map.findWithDefault [] boardId latestThreadsByBoard
        relativeTime ts =
            let minutes = floor (diffUTCTime now ts / 60) :: Int
                hours = minutes `div` 60
                days = hours `div` 24
            in if minutes < 60 then T.pack (show minutes) <> " min ago"
               else if hours < 24 then T.pack (show hours) <> " hours ago"
               else if days < 30 then T.pack (show days) <> " days ago"
               else T.pack (formatTime defaultTimeLocale "%b %e, %Y" ts)
    previewLimit <- getPreviewLimit
    let threadPreview = buildPreview previewLimit . threadContent
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Boards"
        $(widgetFile "forum/boards-index")

getPreviewLimit :: Handler Int
getPreviewLimit = do
    mSetting <- runDB $ getBy $ UniqueSiteSetting "thread_preview_chars"
    case mSetting of
        Nothing -> pure 200
        Just (Entity _ s) ->
            case readMaybe (T.unpack (siteSettingValue s)) of
                Just n | n > 0 -> pure n
                _ -> pure 200

buildPreview :: Int -> Text -> Text
buildPreview n raw =
    let plain = stripTags raw
        trimmed = T.take n plain
    in if T.length plain > n then trimmed <> "…" else trimmed

stripTags :: Text -> Text
stripTags = T.pack . go False . T.unpack
  where
    go _ [] = []
    go True ('>':xs) = go False xs
    go True (_:xs) = go True xs
    go False ('<':xs) = go True xs
    go False (x:xs) = x : go False xs
