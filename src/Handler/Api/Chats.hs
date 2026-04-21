{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Chats where

import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Handler.Api.Common
import Import
import qualified Prelude as P

getApiChatsR :: Handler Value
getApiChatsR = do
    viewerId <- requireApiAuthId
    rooms <- runDB $ selectList [FilterOr [ChatRoomUserA ==. viewerId, ChatRoomUserB ==. viewerId]] [Desc ChatRoomUpdatedAt]
    let roomIds = map entityKey rooms
        peerIds = map (roomPeerId viewerId . entityVal) rooms
    peers <- if P.null peerIds then pure [] else runDB $ selectList [UserId <-. L.nub peerIds] []
    messages <- if P.null roomIds then pure [] else runDB $ selectList [DirectMessageRoom <-. roomIds] [Desc DirectMessageCreatedAt]
    let peerMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) peers
        latestMessageByRoom =
            Map.fromListWith (\old _ -> old) (map (\(Entity _ msg) -> (directMessageRoom msg, msg)) messages)
        items =
            map
                (\(Entity roomId room) ->
                    let peerId = roomPeerId viewerId room
                        peer = Map.lookup peerId peerMap
                    in object
                        [ "id" .= keyToInt roomId
                        , "peer" .= maybe Null (\user -> userRefValue (Entity peerId user)) peer
                        , "preview" .= maybe ("No messages yet" :: Text) directMessageContent (Map.lookup roomId latestMessageByRoom)
                        , "updatedAt" .= chatRoomUpdatedAt room
                        ]
                )
                rooms
    returnJson $ object ["items" .= items]

postApiChatsR :: Handler Value
postApiChatsR = do
    viewerId <- requireApiAuthId
    payload <- requireCheckJsonBody :: Handler CreateChatPayload
    let peerId = createChatPeerId payload
    when (peerId == viewerId) $
        jsonError status400 "invalid_peer" "cannot chat with yourself"
    _ <- requireDbEntity peerId "user_not_found" "User not found."
    now <- liftIO getCurrentTime
    let (userA, userB) = normalizeChatPair viewerId peerId
    existing <- runDB $ getBy $ UniqueChatRoomPair userA userB
    roomId <-
        case existing of
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
    peer <- requireDbEntity peerId "user_not_found" "User not found."
    sendResponseStatus status201 $
        object
            [ "room" .= object
                [ "id" .= keyToInt roomId
                , "peer" .= userRefValue peer
                , "preview" .= ("" :: Text)
                , "updatedAt" .= now
                ]
            ]

getApiChatMessagesR :: ChatRoomId -> Handler Value
getApiChatMessagesR roomId = do
    viewerId <- requireApiAuthId
    room <- requireDbEntity roomId "chat_room_not_found" "Chat room not found."
    unless (viewerCanAccessRoom viewerId (entityVal room)) $
        jsonError status403 "forbidden" "You cannot access this chat room."
    (page, size, offset) <- paginationParams
    rows <- runDB $ selectList [DirectMessageRoom ==. roomId] [Asc DirectMessageCreatedAt, OffsetBy offset, LimitTo (size + 1)]
    let hasNext = P.length rows > size
        pageRows = P.take size rows
        authorIds = L.nub $ map (directMessageAuthor . entityVal) pageRows
    authors <- if P.null authorIds then pure [] else runDB $ selectList [UserId <-. authorIds] []
    let authorMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) authors
        items = map (directMessageValue authorMap) pageRows
    returnJson $
        object
            [ "items" .= items
            , "page" .= page
            , "size" .= size
            , "hasNext" .= hasNext
            ]

postApiChatMessagesR :: ChatRoomId -> Handler Value
postApiChatMessagesR roomId = do
    viewerId <- requireApiAuthId
    room <- requireDbEntity roomId "chat_room_not_found" "Chat room not found."
    unless (viewerCanAccessRoom viewerId (entityVal room)) $
        jsonError status403 "forbidden" "You cannot access this chat room."
    payload <- requireCheckJsonBody :: Handler CreateDirectMessagePayload
    let content = T.strip (createDirectMessageContent payload)
    when (T.null content) $
        jsonError status400 "invalid_content" "Content is required."
    now <- liftIO getCurrentTime
    messageId <- runDB $ insert DirectMessage
        { directMessageRoom = roomId
        , directMessageAuthor = viewerId
        , directMessageContent = content
        , directMessageCreatedAt = now
        }
    runDB $ update roomId [ChatRoomUpdatedAt =. now]
    author <- requireDbEntity viewerId "user_not_found" "User not found."
    sendResponseStatus status201 $
        object
            [ "message" .= directMessageValue (Map.singleton viewerId (entityVal author)) (Entity messageId (DirectMessage roomId viewerId content now))
            ]
