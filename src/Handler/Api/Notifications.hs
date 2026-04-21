{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Notifications where

import qualified Data.List as L
import qualified Data.Map.Strict as Map
import Handler.Api.Common
import Import
import qualified Prelude as P

getApiNotificationsR :: Handler Value
getApiNotificationsR = do
    viewerId <- requireApiAuthId
    (page, size, offset) <- paginationParams
    notifications <- runDB $ selectList [NotificationUser ==. viewerId] [Desc NotificationCreatedAt, OffsetBy offset, LimitTo (size + 1)]
    let hasNext = P.length notifications > size
        pageRows = P.take size notifications
        actorIds = L.nub $ mapMaybe (notificationActor . entityVal) pageRows
    actors <- if P.null actorIds then pure [] else runDB $ selectList [UserId <-. actorIds] []
    let actorMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) actors
        items = map (notificationValue actorMap) pageRows
    returnJson $
        object
            [ "items" .= items
            , "page" .= page
            , "size" .= size
            , "hasNext" .= hasNext
            ]

postApiNotificationsReadAllR :: Handler Value
postApiNotificationsReadAllR = do
    viewerId <- requireApiAuthId
    runDB $ updateWhere [NotificationUser ==. viewerId, NotificationIsRead ==. False] [NotificationIsRead =. True]
    returnJson $ object ["message" .= ("All notifications marked as read." :: Text)]
