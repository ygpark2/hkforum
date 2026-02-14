{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}
module Handler.Forum.Boards (getBoardsR, postBoardsR) where

import Import
import Text.Blaze (preEscapedText)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (diffUTCTime, defaultTimeLocale, formatTime)
import qualified Prelude as P
import Text.Read (readMaybe)

getBoardsR :: Handler Html
getBoardsR = do
    threads <- runDB $ selectList [] [Desc ThreadCreatedAt]
    now <- liftIO getCurrentTime
    let threadIds = map entityKey threads
    threadPosts <-
        if P.null threadIds
            then pure []
            else runDB $ selectList [PostThread <-. threadIds] [Asc PostCreatedAt]
    maybeAuthValue <- maybeAuthId
    (mutedThreadIds, blockedThreadIds, blockedPostIds) <- case maybeAuthValue of
        Nothing -> pure ([], [], [])
        Just userId -> do
            muted <- runDB $ selectList [ThreadMuteUser ==. userId] []
            blockedThreads <- runDB $ selectList [ThreadBlockUser ==. userId] []
            blockedPosts <- runDB $ selectList [PostBlockUser ==. userId] []
            pure (map (threadMuteThread . entityVal) muted
                 , map (threadBlockThread . entityVal) blockedThreads
                 , map (postBlockPost . entityVal) blockedPosts)
    let postAuthorIds = map (postAuthor . entityVal) threadPosts
        authorIds = L.nub $ map (threadAuthor . entityVal) threads P.++ postAuthorIds
    users <- if P.null authorIds
        then return []
        else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        authorHandle uid = T.toLower $ T.filter (/= ' ') (authorName uid)
        authorInitial uid =
            let name = authorName uid
            in if T.null name then "?" else T.toUpper $ T.take 1 name
        threadsForFeed = P.filter (\(Entity tid _) ->
            tid `P.notElem` blockedThreadIds && tid `P.notElem` mutedThreadIds) threads
        filteredThreadIds = map entityKey threadsForFeed
        filteredPosts = P.filter (\(Entity pid _) -> pid `P.notElem` blockedPostIds) threadPosts
        filteredPostsByThread = P.filter (\(Entity _ p) -> postThread p `P.elem` filteredThreadIds) filteredPosts
        postMetaMap =
            P.foldl
                (\acc ent@(Entity _ p) ->
                    let tid = postThread p
                    in Map.alter (applyPost ent) tid acc
                )
                Map.empty
                filteredPostsByThread
        applyPost ent Nothing = Just (1 :: Int, ent, ent)
        applyPost ent (Just (n, firstE, _lastE)) = Just (n + 1, firstE, ent)
        postMetaFor tid = Map.lookup tid postMetaMap
        relativeTime ts =
            let minutes = floor (diffUTCTime now ts / 60) :: Int
                hours = minutes `div` 60
                days = hours `div` 24
            in if minutes < 60 then T.pack (show minutes) <> " min ago"
               else if hours < 24 then T.pack (show hours) <> " hours ago"
               else if days < 30 then T.pack (show days) <> " days ago"
               else T.pack (formatTime defaultTimeLocale "%b %e, %Y" ts)
    isAdminUser <- case maybeAuthValue of
        Nothing -> pure False
        Just userId -> do
            mUser <- runDB $ get userId
            pure $ maybe False (\user -> userRole user == T.pack "admin") mUser
    ads <- runDB $ selectList [AdIsActive ==. True, AdPosition ==. T.pack "sidebar-right"] [Asc AdSortOrder, Desc AdCreatedAt]
    req <- getRequest
    let mCsrfToken = reqToken req
    previewLimit <- getPreviewLimit
    let postPreview = buildPreview previewLimit . postContent
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum - Home"
        $(widgetFile "forum/boards")

postBoardsR :: Handler Html
postBoardsR = do
    userId <- requireAuthId
    boardId <- runInputPost $ ireq hiddenField "boardId"
    title <- runInputPost $ ireq textField "title"
    content <- runInputPost $ ireq textField "content"
    now <- liftIO getCurrentTime
    _ <- runDB $ insert Thread
        { threadTitle = title
        , threadContent = content
        , threadAuthor = userId
        , threadBoard = boardId
        , threadCreatedAt = now
        , threadUpdatedAt = now
        }
    runDB $ update boardId [BoardThreadCount +=. 1]
    redirect $ BoardR boardId

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
