{-# LANGUAGE OverloadedStrings #-}
module Handler.Forum.User (postUserFollowR) where

import Import

postUserFollowR :: UserId -> Handler Value
postUserFollowR targetUserId = do
    viewerId <- requireAuthId
    when (viewerId == targetUserId) $ invalidArgs ["cannot follow yourself"]
    _ <- runDB $ get404 targetUserId
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniqueUserFollow viewerId targetUserId
    case existing of
        Nothing -> do
            runDB $ insert_ $ UserFollow viewerId targetUserId now
            when (viewerId /= targetUserId) $ do
                runDB $ insert_ Notification
                    { notificationUser = targetUserId
                    , notificationActor = Just viewerId
                    , notificationKind = "follow"
                    , notificationPost = Nothing
                    , notificationComment = Nothing
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
            followerCount <- runDB $ count [UserFollowFollowing ==. targetUserId]
            returnJson $ object
                [ "message" .= ("Followed user" :: Text)
                , "state" .= ("followed" :: Text)
                , "followerCount" .= followerCount
                ]
        Just (Entity followId _) -> do
            runDB $ delete followId
            followerCount <- runDB $ count [UserFollowFollowing ==. targetUserId]
            returnJson $ object
                [ "message" .= ("Unfollowed user" :: Text)
                , "state" .= ("unfollowed" :: Text)
                , "followerCount" .= followerCount
                ]
