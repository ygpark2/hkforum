{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Chat.Chats
    ( getChatsR
    , getChatsNewR
    , postChatsNewR
    , getChatRoomR
    , postChatRoomR
    ) where

import Import
import Database.Persist.Sql (fromSqlKey)
import Data.Time (diffUTCTime)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Text.Blaze (preEscapedText)
import qualified Prelude as P

data ChatRoomSummary = ChatRoomSummary
    { chatRoomSummaryId :: ChatRoomId
    , chatRoomSummaryPeerName :: Text
    , chatRoomSummaryPeerHandle :: Text
    , chatRoomSummaryPreview :: Text
    , chatRoomSummaryUpdatedLabel :: Text
    }

getChatsR :: Handler Html
getChatsR = do
    mViewerId <- maybeAuthId
    roomSummaries <-
        case mViewerId of
            Nothing -> pure []
            Just viewerId -> loadChatRoomSummaries viewerId
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Chats"
        $(widgetFile "chat/index")

getChatsNewR :: Handler Html
getChatsNewR = do
    viewerId <- requireAuthId
    req <- getRequest
    let mCsrfToken = reqToken req
    rawQuery <- fromMaybe "" <$> lookupGetParam "q"
    let searchQuery = T.strip rawQuery
        hasQuery = not (T.null searchQuery)
    allUsers <- runDB $ selectList [UserId !=. viewerId] [Asc UserIdent, LimitTo 200]
    let needle = T.toLower searchQuery
        matchedUsers =
            if hasQuery
                then filter (matchesNeedle needle) allUsers
                else []
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | New Chat"
        $(widgetFile "chat/new")

postChatsNewR :: Handler Html
postChatsNewR = do
    viewerId <- requireAuthId
    peerId <- runInputPost $ ireq hiddenField "peerId"
    when (peerId == viewerId) $ invalidArgs ["cannot chat with yourself"]
    _ <- runDB $ get404 peerId
    now <- liftIO getCurrentTime
    let (userA, userB) = normalizeChatPair viewerId peerId
    mExisting <- runDB $ getBy $ UniqueChatRoomPair userA userB
    roomId <-
        case mExisting of
            Just (Entity existingRoomId _) -> do
                runDB $ update existingRoomId [ChatRoomUpdatedAt =. now]
                pure existingRoomId
            Nothing ->
                runDB $ insert ChatRoom
                    { chatRoomUserA = userA
                    , chatRoomUserB = userB
                    , chatRoomCreatedAt = now
                    , chatRoomUpdatedAt = now
                    }
    redirect $ ChatRoomR roomId

getChatRoomR :: ChatRoomId -> Handler Html
getChatRoomR roomId = do
    viewerId <- requireAuthId
    req <- getRequest
    let mCsrfToken = reqToken req
    room <- runDB $ get404 roomId
    unless (viewerCanAccessRoom viewerId room) $ permissionDenied "You cannot access this chat room."
    let peerId = roomPeerId viewerId room
    peer <- runDB $ get404 peerId
    messages <- runDB $ selectList [DirectMessageRoom ==. roomId] [Asc DirectMessageCreatedAt, LimitTo 500]
    now <- liftIO getCurrentTime
    let authorIds = L.nub $ map (directMessageAuthor . entityVal) messages
    authors <-
        if P.null authorIds
            then pure []
            else runDB $ selectList [UserId <-. authorIds] []
    let authorMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) authors
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid authorMap
        authorHandle uid = T.toLower $ T.filter (/= ' ') (authorName uid)
        authorInitial uid =
            let name = authorName uid
            in if T.null name then "?" else T.toUpper (T.take 1 name)
        relativeTime ts = relativeTimeLabel now ts
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Chat Room"
        $(widgetFile "chat/room")

postChatRoomR :: ChatRoomId -> Handler Html
postChatRoomR roomId = do
    viewerId <- requireAuthId
    room <- runDB $ get404 roomId
    unless (viewerCanAccessRoom viewerId room) $ permissionDenied "You cannot access this chat room."
    contentRaw <- runInputPost $ ireq textField "content"
    let content = T.strip contentRaw
    when (T.null content) $ invalidArgs ["content is required"]
    now <- liftIO getCurrentTime
    _ <- runDB $ insert DirectMessage
        { directMessageRoom = roomId
        , directMessageAuthor = viewerId
        , directMessageContent = content
        , directMessageCreatedAt = now
        }
    runDB $ update roomId [ChatRoomUpdatedAt =. now]
    redirect $ ChatRoomR roomId

loadChatRoomSummaries :: UserId -> Handler [ChatRoomSummary]
loadChatRoomSummaries viewerId = do
    rooms <- runDB $ selectList [FilterOr [ChatRoomUserA ==. viewerId, ChatRoomUserB ==. viewerId]] [Desc ChatRoomUpdatedAt, LimitTo 100]
    let roomIds = map entityKey rooms
        peerIds = map (roomPeerId viewerId . entityVal) rooms
    peers <-
        if P.null peerIds
            then pure []
            else runDB $ selectList [UserId <-. L.nub peerIds] []
    messages <-
        if P.null roomIds
            then pure []
            else runDB $ selectList [DirectMessageRoom <-. roomIds] [Desc DirectMessageCreatedAt]
    now <- liftIO getCurrentTime
    let peerMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) peers
        latestMessageByRoom =
            Map.fromListWith
                (\old _ -> old)
                (map (\(Entity _ msg) -> (directMessageRoom msg, msg)) messages)
        summaryFor (Entity roomId room) =
            let peerId = roomPeerId viewerId room
                peer = Map.lookup peerId peerMap
                peerName = maybe "Unknown" userIdent peer
                peerHandle = T.toLower $ T.filter (/= ' ') peerName
                preview = maybe "No messages yet" directMessageContent (Map.lookup roomId latestMessageByRoom)
                updatedLabel = relativeTimeLabel now (chatRoomUpdatedAt room)
            in ChatRoomSummary roomId peerName peerHandle preview updatedLabel
    pure $ map summaryFor rooms

normalizeChatPair :: UserId -> UserId -> (UserId, UserId)
normalizeChatPair a b =
    if fromSqlKey a <= fromSqlKey b then (a, b) else (b, a)

roomPeerId :: UserId -> ChatRoom -> UserId
roomPeerId viewerId room
    | chatRoomUserA room == viewerId = chatRoomUserB room
    | otherwise = chatRoomUserA room

viewerCanAccessRoom :: UserId -> ChatRoom -> Bool
viewerCanAccessRoom viewerId room =
    chatRoomUserA room == viewerId || chatRoomUserB room == viewerId

matchesNeedle :: Text -> Entity User -> Bool
matchesNeedle needle (Entity _ user) =
    let ident = T.toLower (userIdent user)
        nameText = maybe "" T.toLower (userName user)
    in needle `T.isInfixOf` ident || needle `T.isInfixOf` nameText

relativeTimeLabel :: UTCTime -> UTCTime -> Text
relativeTimeLabel now ts =
    let minutes = floor (diffUTCTime now ts / 60) :: Int
        hours = minutes `div` 60
        days = hours `div` 24
    in if minutes < 60 then tshow minutes <> " min ago"
       else if hours < 24 then tshow hours <> " hours ago"
       else if days < 30 then tshow days <> " days ago"
       else tshow $ formatTime defaultTimeLocale "%b %e, %Y" ts
