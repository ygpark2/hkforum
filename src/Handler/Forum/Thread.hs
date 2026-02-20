{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Thread
    ( getThreadR
    , postThreadMuteR
    , postThreadBookmarkR
    , postThreadBlockR
    , postThreadFlagR
    ) where

import Import
import qualified Data.List as L
import qualified Data.Text as T
import qualified Data.Map.Strict as Map
import Text.Blaze (preEscapedText)
import qualified Prelude as P

getThreadR :: ThreadId -> Handler Html
getThreadR threadId = do
    thread <- runDB $ get404 threadId
    posts <- runDB $ selectList [PostThread ==. threadId] [Asc PostCreatedAt]
    let postIds = map entityKey posts
    comments <- if P.null postIds
        then return []
        else runDB $ selectList [CommentPost <-. postIds] [Asc CommentCreatedAt]
    let commentsByPost =
            P.foldl
                (\acc (Entity cId c) ->
                    Map.insertWith (P.<>) (commentPost c) [Entity cId c] acc)
                Map.empty
                comments
    let postAuthorIds = map (postAuthor . entityVal) posts
        commentAuthorIds = map (commentAuthor . entityVal) comments
        authorIds = L.nub $ threadAuthor thread : (postAuthorIds P.++ commentAuthorIds)
    users <- if P.null authorIds
        then return []
        else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        authorName uid = Map.findWithDefault (T.pack "Unknown") uid userMap
    board <- runDB $ get404 (threadBoard thread)
    maybeAuth <- maybeAuthId
    isAdminUser <- case maybeAuth of
        Nothing -> pure False
        Just userId -> do
            mUser <- runDB $ get userId
            pure $ maybe False (\user -> userRole user == T.pack "admin") mUser
    ads <- runDB $ selectList [AdIsActive ==. True, AdPosition ==. T.pack "sidebar-right"] [Asc AdSortOrder, Desc AdCreatedAt]
    req <- getRequest
    let mCsrfToken = reqToken req
    let commentsFor pid = Map.findWithDefault [] pid commentsByPost
    defaultLayout $ do
        setTitle $ preEscapedText $ threadTitle thread <> T.pack " - HKForum"
        $(widgetFile "forum/thread")

postThreadMuteR :: ThreadId -> Handler Value
postThreadMuteR threadId = do
    userId <- requireAuthId
    existing <- runDB $ getBy $ UniqueThreadMute userId threadId
    case existing of
        Nothing -> do
            now <- liftIO getCurrentTime
            runDB $ insert_ $ ThreadMute userId threadId now
            returnJson $ object
                [ "message" .= ("Muted" :: Text)
                , "state" .= ("muted" :: Text)
                ]
        Just (Entity muteId _) -> do
            runDB $ delete muteId
            returnJson $ object
                [ "message" .= ("Unmuted" :: Text)
                , "state" .= ("unmuted" :: Text)
                ]

postThreadBookmarkR :: ThreadId -> Handler Value
postThreadBookmarkR threadId = do
    userId <- requireAuthId
    _ <- runDB $ get404 threadId
    existing <- runDB $ getBy $ UniqueThreadBookmark userId threadId
    case existing of
        Nothing -> do
            now <- liftIO getCurrentTime
            runDB $ insert_ $ ThreadBookmark userId threadId now
            returnJson $ object
                [ "message" .= ("Bookmarked" :: Text)
                , "state" .= ("bookmarked" :: Text)
                ]
        Just (Entity bookmarkId _) -> do
            runDB $ delete bookmarkId
            returnJson $ object
                [ "message" .= ("Bookmark removed" :: Text)
                , "state" .= ("unbookmarked" :: Text)
                ]

postThreadBlockR :: ThreadId -> Handler Value
postThreadBlockR threadId = do
    userId <- requireAuthId
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniqueThreadBlock userId threadId
    case existing of
        Nothing -> do
            runDB $ insert_ $ ThreadBlock userId threadId now
            returnJson $ object ["message" .= ("Blocked thread" :: Text)]
        Just _ -> returnJson $ object ["message" .= ("Already blocked" :: Text)]

postThreadFlagR :: ThreadId -> Handler Value
postThreadFlagR threadId = do
    userId <- requireAuthId
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniqueThreadFlag userId threadId
    case existing of
        Nothing -> do
            runDB $ insert_ $ ThreadFlag userId threadId now
            returnJson $ object ["message" .= ("Flagged thread" :: Text)]
        Just _ -> returnJson $ object ["message" .= ("Already flagged" :: Text)]
