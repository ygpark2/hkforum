{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Users where

import Handler.Api.Common
import Import
import qualified Data.Set as Set
import qualified Data.Text as T

getApiUsersR :: Handler Value
getApiUsersR = do
    ensureApiReadAllowed
    mViewerId <- maybeApiAuthId
    query <- T.toLower . T.strip . fromMaybe "" <$> lookupGetParam "q"
    size <- min 50 . max 1 <$> queryIntParam "size" 20
    blockedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            runDB $
                selectList
                    [ FilterOr
                        [ UserBlockBlocker ==. viewerId
                        , UserBlockBlocked ==. viewerId
                        ]
                    ]
                    []
    let blockedUserIds =
            Set.fromList $
                concatMap
                    (\(Entity _ row) -> [userBlockBlocker row, userBlockBlocked row])
                    blockedRows
        filters =
            [ UserId !=. viewerId
            | viewerId <- maybeToList mViewerId
            ]
    rows <- runDB $ selectList filters [Asc UserIdent, LimitTo 200]
    let matched =
            take size $
                filter
                    (\ent@(Entity userId user) ->
                        not
                            ( maybe False
                                (\viewerId ->
                                    Set.member userId blockedUserIds
                                        && userId /= viewerId
                                )
                                mViewerId
                            )
                            &&
                        ( T.null query
                            || query `T.isInfixOf` T.toLower (userIdent user)
                            || maybe False (T.isInfixOf query . T.toLower) (userName user)
                        )
                    )
                    rows
    returnJson $ object ["items" .= map userRefValue matched]

getApiUserR :: UserId -> Handler Value
getApiUserR userId = do
    ensureApiReadAllowed
    mViewerId <- maybeApiAuthId
    user <- requireDbEntity userId "user_not_found" "User not found."
    followerCount <- runDB $ count [UserFollowFollowing ==. userId]
    followingCount <- runDB $ count [UserFollowFollower ==. userId]
    isFollowing <- case mViewerId of
        Nothing -> pure Nothing
        Just viewerId -> do
            following <- isJust <$> runDB (getBy $ UniqueUserFollow viewerId userId)
            pure (Just following)
    isBlocked <- case mViewerId of
        Nothing -> pure Nothing
        Just viewerId -> do
            blocked <- isJust <$> runDB (getBy $ UniqueUserBlock viewerId userId)
            pure (Just blocked)
    returnJson $
        object
            [ "user" .=
                userProfileValue mViewerId user followerCount followingCount isFollowing
            , "isBlocked" .= isBlocked
            ]

postApiUserFollowR :: UserId -> Handler Value
postApiUserFollowR targetUserId = do
    viewerId <- requireApiAuthId
    when (viewerId == targetUserId) $
        jsonError status400 "invalid_follow_target" "cannot follow yourself"
    _ <- requireDbEntity targetUserId "user_not_found" "User not found."
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniqueUserFollow viewerId targetUserId
    case existing of
        Nothing -> do
            runDB $ insert_ $ UserFollow viewerId targetUserId now
            when (viewerId /= targetUserId) $
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
            returnJson $
                object
                    [ "message" .= ("Followed user" :: Text)
                    , "state" .= ("followed" :: Text)
                    , "followerCount" .= followerCount
                    ]
        Just (Entity followId _) -> do
            runDB $ delete followId
            followerCount <- runDB $ count [UserFollowFollowing ==. targetUserId]
            returnJson $
                object
                    [ "message" .= ("Unfollowed user" :: Text)
                    , "state" .= ("unfollowed" :: Text)
                    , "followerCount" .= followerCount
                    ]

postApiUserBlockR :: UserId -> Handler Value
postApiUserBlockR targetUserId = do
    viewerId <- requireApiAuthId
    when (viewerId == targetUserId) $
        jsonError status400 "invalid_block_target" "cannot block yourself"
    _ <- requireDbEntity targetUserId "user_not_found" "User not found."
    now <- liftIO getCurrentTime
    existing <- runDB $ getBy $ UniqueUserBlock viewerId targetUserId
    case existing of
        Nothing -> do
            runDB $ insert_ $ UserBlock viewerId targetUserId now
            runDB $ deleteWhere [UserFollowFollower ==. viewerId, UserFollowFollowing ==. targetUserId]
            runDB $ deleteWhere [UserFollowFollower ==. targetUserId, UserFollowFollowing ==. viewerId]
            blockedCount <- runDB $ count [UserBlockBlocker ==. viewerId]
            returnJson $
                object
                    [ "message" .= ("Blocked user" :: Text)
                    , "state" .= ("blocked" :: Text)
                    , "blockedCount" .= blockedCount
                    ]
        Just (Entity blockId _) -> do
            runDB $ delete blockId
            blockedCount <- runDB $ count [UserBlockBlocker ==. viewerId]
            returnJson $
                object
                    [ "message" .= ("Unblocked user" :: Text)
                    , "state" .= ("unblocked" :: Text)
                    , "blockedCount" .= blockedCount
                    ]
