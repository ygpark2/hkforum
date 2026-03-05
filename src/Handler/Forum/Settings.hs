{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Settings
    ( getSettingsR
    , getSettingsAccountR
    , getSettingsConnectionsR
    , getSettingsBlockedAccountsR
    , getSettingsSecurityEventsR
    , getSettingsAboutR
    ) where

import Import hiding (map, take, (++))
import Data.Time (NominalDiffTime, addUTCTime, diffUTCTime)
import qualified Data.List as L
import qualified Data.Text as T
import Text.Blaze (preEscapedText)

data SecurityEventRow = SecurityEventRow
    { securityEventLabel :: Text
    , securityEventPlatform :: Text
    , securityEventWhen :: Text
    }

data TimedSecurityEvent = TimedSecurityEvent
    { timedSecurityEventLabel :: Text
    , timedSecurityEventCreatedAt :: UTCTime
    }

getSettingsR :: Handler Html
getSettingsR = do
    viewerId <- requireAuthId
    viewer <- runDB $ get404 viewerId
    let displayName = fromMaybe (userIdent viewer) (userName viewer)
        avatarInitial =
            let base = T.strip displayName
            in if T.null base then "?" else T.toUpper (T.take 1 base)
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Settings"
        $(widgetFile "forum/settings")

getSettingsAccountR :: Handler Html
getSettingsAccountR = do
    viewerId <- requireAuthId
    viewer <- runDB $ get404 viewerId
    let githubHandle = userIdent viewer
        githubProfileUrl = "https://github.com/" <> githubHandle
        githubProfileLabel = "github.com/" <> githubHandle
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Account"
        $(widgetFile "forum/settings-account")

getSettingsConnectionsR :: Handler Html
getSettingsConnectionsR = do
    viewerId <- requireAuthId
    viewer <- runDB $ get404 viewerId
    let githubHandle = userIdent viewer
        githubProfileUrl = "https://github.com/" <> githubHandle
        githubProfileLabel = "github.com/" <> githubHandle
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Connections"
        $(widgetFile "forum/settings-connections")

getSettingsBlockedAccountsR :: Handler Html
getSettingsBlockedAccountsR = do
    _ <- requireAuthId
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Blocked Accounts"
        $(widgetFile "forum/settings-blocked-accounts")

getSettingsSecurityEventsR :: Handler Html
getSettingsSecurityEventsR = do
    viewerId <- requireAuthId
    now <- liftIO getCurrentTime

    reactionRows <- runDB $ selectList [PostReactionUser ==. viewerId] [Desc PostReactionCreatedAt, LimitTo 8]
    likeRows <- runDB $ selectList [PostLikeUser ==. viewerId] [Desc PostLikeCreatedAt, LimitTo 8]
    bookmarkRows <- runDB $ selectList [PostBookmarkUser ==. viewerId] [Desc PostBookmarkCreatedAt, LimitTo 8]

    let reactionEvents =
            map
                (\(Entity _ row) ->
                    TimedSecurityEvent
                        { timedSecurityEventLabel = "reacted to post"
                        , timedSecurityEventCreatedAt = postReactionCreatedAt row
                        }
                )
                reactionRows
        likeEvents =
            map
                (\(Entity _ row) ->
                    TimedSecurityEvent
                        { timedSecurityEventLabel = "liked post"
                        , timedSecurityEventCreatedAt = postLikeCreatedAt row
                        }
                )
                likeRows
        bookmarkEvents =
            map
                (\(Entity _ row) ->
                    TimedSecurityEvent
                        { timedSecurityEventLabel = "bookmarked post"
                        , timedSecurityEventCreatedAt = postBookmarkCreatedAt row
                        }
                )
                bookmarkRows
        fallbackEvents =
            [ TimedSecurityEvent "login" (addUTCTime (negate $ daysToSeconds 14) now)
            , TimedSecurityEvent "user created" (addUTCTime (negate $ daysToSeconds 14) now)
            ]
        sortedEvents =
            L.sortBy
                (\a b -> compare (timedSecurityEventCreatedAt b) (timedSecurityEventCreatedAt a))
                (reactionEvents ++ likeEvents ++ bookmarkEvents ++ fallbackEvents)
        securityEventRows =
            map
                (\event ->
                    SecurityEventRow
                        { securityEventLabel = timedSecurityEventLabel event
                        , securityEventPlatform = "macOS"
                        , securityEventWhen = relativeTimeLabel now (timedSecurityEventCreatedAt event)
                        }
                )
                (take 8 sortedEvents)

    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Security Events"
        $(widgetFile "forum/settings-security-events")

getSettingsAboutR :: Handler Html
getSettingsAboutR = do
    _ <- requireAuthId
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | About"
        $(widgetFile "forum/settings-about")

relativeTimeLabel :: UTCTime -> UTCTime -> Text
relativeTimeLabel now ts =
    let minutes = floor (diffUTCTime now ts / 60) :: Int
        hours = minutes `div` 60
        days = hours `div` 24
    in if minutes < 60
        then tshow minutes <> " minutes ago"
        else if hours < 24
            then tshow hours <> " hours ago"
            else if days < 30
                then tshow days <> " days ago"
                else tshow $ formatTime defaultTimeLocale "%b %e, %Y" ts

daysToSeconds :: Int -> NominalDiffTime
daysToSeconds d = fromInteger (toInteger d) * 86400
