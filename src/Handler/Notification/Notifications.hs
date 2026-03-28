{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Notification.Notifications (getNotificationsR, postNotificationsReadAllR) where

import Import
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import Text.Blaze (preEscapedText)
import qualified Prelude as P

getNotificationsR :: Handler Html
getNotificationsR = do
    viewerId <- requireAuthId
    req <- getRequest
    let mCsrfToken = reqToken req
    notifications <- runDB $ selectList [NotificationUser ==. viewerId] [Desc NotificationCreatedAt, LimitTo 200]
    let actorIds = L.nub $ mapMaybe (notificationActor . entityVal) notifications
    actors <-
        if P.null actorIds
            then pure []
            else runDB $ selectList [UserId <-. actorIds] []
    let actorMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) actors
        actorLabel mActorId = maybe ("System" :: Text) (\uid -> Map.findWithDefault "Unknown" uid actorMap) mActorId
        kindLabel :: Notification -> Text
        kindLabel n =
            case notificationKind n of
                "follow" -> "started following you"
                "post-like" -> "liked your post"
                "post-bookmark" -> "bookmarked your post"
                "comment" -> "commented on your post"
                "reply" -> "replied to your comment"
                "watch-comment" -> "new activity on a post you watch"
                _ -> "sent a notification"
        targetRoute n = fmap PostR (notificationPost n)
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Notifications"
        $(widgetFile "forum/notifications")

postNotificationsReadAllR :: Handler Html
postNotificationsReadAllR = do
    viewerId <- requireAuthId
    runDB $ updateWhere [NotificationUser ==. viewerId, NotificationIsRead ==. False] [NotificationIsRead =. True]
    setMessage "All notifications marked as read."
    redirect NotificationsR
