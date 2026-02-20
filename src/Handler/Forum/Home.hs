{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}
module Handler.Forum.Home (getHomeR, postHomeR) where

import Import
import Text.Blaze (preEscapedText)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (diffUTCTime)
import qualified Prelude as P
import Text.Read (readMaybe)

getHomeR :: Handler Html
getHomeR = do
    mTabParam <- lookupGetParam "tab"
    mQueryParam <- lookupGetParam "q"
    req <- getRequest
    let mCsrfToken = reqToken req
    boards <- runDB $ selectList [] [Asc BoardName]
    threads <- runDB $ selectList [] [Desc ThreadCreatedAt]
    now <- liftIO getCurrentTime
    let boardMap = Map.fromList $ map (\(Entity bid b) -> (bid, boardName b)) boards
        threadIds = map entityKey threads
    threadPosts <-
        if P.null threadIds
            then pure []
            else runDB $ selectList [PostThread <-. threadIds] [Asc PostCreatedAt]
    maybeAuthValue <- maybeAuthId
    (mutedThreadIds, blockedThreadIds, blockedPostIds, bookmarkedThreadIds) <- case maybeAuthValue of
        Nothing -> pure ([], [], [], [])
        Just userId -> do
            muted <- runDB $ selectList [ThreadMuteUser ==. userId] []
            blockedThreads <- runDB $ selectList [ThreadBlockUser ==. userId] []
            blockedPosts <- runDB $ selectList [PostBlockUser ==. userId] []
            bookmarks <- runDB $ selectList [ThreadBookmarkUser ==. userId] []
            pure (map (threadMuteThread . entityVal) muted
                 , map (threadBlockThread . entityVal) blockedThreads
                 , map (postBlockPost . entityVal) blockedPosts
                 , map (threadBookmarkThread . entityVal) bookmarks)
    let postAuthorIds = map (postAuthor . entityVal) threadPosts
        authorIds = L.nub $ map (threadAuthor . entityVal) threads P.++ postAuthorIds
    users <- if P.null authorIds
        then return []
        else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        authorHandle uid = T.toLower $ T.filter (/= ' ') (authorName uid)
        authorInitial uid =
            let n = authorName uid
            in if T.null n then "?" else T.toUpper (T.take 1 n)
        boardLabel bid = Map.findWithDefault ("general" :: Text) bid boardMap
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
        replyCountFor tid = maybe 0 (\(n, _, _) -> n) (postMetaFor tid)
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
        activeTab :: Text
        activeTab =
            case fmap T.toLower mTabParam of
                Just "everything" -> "everything"
                Just "trends" -> "trends"
                Just "following" -> "following"
                Just "interests" -> "interests"
                _ -> "unread"
        topInterestBoards =
            map entityKey $
                P.take 3 $
                    L.sortBy
                        (\(Entity _ a) (Entity _ b) -> compare (boardThreadCount b, boardPostCount b) (boardThreadCount a, boardPostCount a))
                        boards
        tabThreadsBase =
            case activeTab of
                "everything" -> threadsForFeed
                "trends" ->
                    L.sortBy
                        (\(Entity tidA a) (Entity tidB b) ->
                            compare (replyCountFor tidB, threadCreatedAt b) (replyCountFor tidA, threadCreatedAt a)
                        )
                        threadsForFeed
                "following" ->
                    case maybeAuthValue of
                        Nothing -> []
                        Just uid ->
                            P.filter (\(Entity _ t) -> threadAuthor t == uid) threadsForFeed
                "interests" ->
                    P.filter (\(Entity _ t) -> threadBoard t `P.elem` topInterestBoards) threadsForFeed
                _ ->
                    P.filter
                        (\(Entity _ t) -> diffUTCTime now (threadCreatedAt t) <= 60 * 60 * 24 * 7)
                        threadsForFeed
        mSearchQuery =
            case mQueryParam of
                Nothing -> Nothing
                Just raw ->
                    let q = T.toLower (T.strip raw)
                    in if T.null q then Nothing else Just q
        matchesSearch q (Entity _ t) =
            q `T.isInfixOf`
                T.toLower
                    ( threadTitle t
                        <> " "
                        <> threadContent t
                        <> " "
                        <> boardLabel (threadBoard t)
                        <> " "
                        <> authorName (threadAuthor t)
                    )
        tabThreads =
            case mSearchQuery of
                Nothing -> tabThreadsBase
                Just q -> P.filter (matchesSearch q) tabThreadsBase
        tabTitle :: Text
        tabTitle =
            case activeTab of
                "everything" -> "Everything feed"
                "trends" -> "Trending posts"
                "following" -> "Following feed"
                "interests" -> "Interests feed"
                _ -> "You're all caught up"
        tabSubtitle :: Text
        tabSubtitle =
            case activeTab of
                "everything" -> "No post in everything yet."
                "trends" -> "No trending post yet."
                "following" -> "Follow users to see posts here."
                "interests" -> "No interest-matched post yet."
                _ -> "Nice work!"
    previewLimit <- getPreviewLimit
    let threadPreview = buildPreview previewLimit . threadContent
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Developer Community"
        $(widgetFile "forum/boards")

postHomeR :: Handler Html
postHomeR = do
    userId <- requireAuthId
    boardId <- runInputPost $ ireq hiddenField "boardId"
    mTitle <- runInputPost $ iopt textField "title"
    content <- runInputPost $ ireq textField "content"
    let contentText = T.strip content
    when (T.null contentText) $ invalidArgs ["content is required"]
    _ <- runDB $ get404 boardId
    let generatedTitle =
            let firstLine = T.takeWhile (/= '\n') (stripTags contentText)
                trimmed = T.strip (T.take 80 firstLine)
            in if T.null trimmed then "Untitled" else trimmed
        title = case fmap T.strip mTitle of
            Just t | not (T.null t) -> t
            _ -> generatedTitle
    now <- liftIO getCurrentTime
    _ <- runDB $ insert Thread
        { threadTitle = title
        , threadContent = contentText
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
