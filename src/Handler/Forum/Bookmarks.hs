{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Bookmarks (getBookmarksR) where

import Import
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (diffUTCTime)
import qualified Prelude as P
import Text.Blaze (preEscapedText)
import Text.Read (readMaybe)

getBookmarksR :: Handler Html
getBookmarksR = do
    userId <- requireAuthId
    req <- getRequest
    let mCsrfToken = reqToken req
    bookmarks <- runDB $ selectList [ThreadBookmarkUser ==. userId] [Desc ThreadBookmarkCreatedAt]
    now <- liftIO getCurrentTime
    let bookmarkedThreadIds = map (threadBookmarkThread . entityVal) bookmarks
    threads <-
        if P.null bookmarkedThreadIds
            then pure []
            else runDB $ selectList [ThreadId <-. bookmarkedThreadIds] []
    let threadMap = Map.fromList $ map (\(Entity tid t) -> (tid, t)) threads
        bookmarkThreads = mapMaybe toThreadEntity bookmarks
        toThreadEntity (Entity _ bookmark) =
            let tid = threadBookmarkThread bookmark
            in fmap (Entity tid) (Map.lookup tid threadMap)
    boards <-
        if P.null bookmarkThreads
            then pure []
            else runDB $ selectList [BoardId <-. L.nub (map (threadBoard . entityVal) bookmarkThreads)] []
    let boardMap = Map.fromList $ map (\(Entity bid board) -> (bid, boardName board)) boards
    users <-
        if P.null bookmarkThreads
            then pure []
            else runDB $ selectList [UserId <-. L.nub (map (threadAuthor . entityVal) bookmarkThreads)] []
    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        authorHandle uid = T.toLower $ T.filter (/= ' ') (authorName uid)
        authorInitial uid =
            let n = authorName uid
            in if T.null n then "?" else T.toUpper (T.take 1 n)
        boardLabel bid = Map.findWithDefault ("general" :: Text) bid boardMap
    posts <-
        if P.null bookmarkedThreadIds
            then pure []
            else runDB $ selectList [PostThread <-. bookmarkedThreadIds] []
    let replyCountMap =
            P.foldl
                (\acc (Entity _ post) ->
                    Map.insertWith (+) (postThread post) (1 :: Int) acc
                )
                Map.empty
                posts
        replyCountFor tid = Map.findWithDefault 0 tid replyCountMap
        likeCountFor tid = max 1 ((replyCountFor tid `div` 2) + 1)
        smileCountFor tid = replyCountFor tid `mod` 3
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
        setTitle $ preEscapedText "HKForum | Bookmarks"
        $(widgetFile "forum/bookmarks")

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
