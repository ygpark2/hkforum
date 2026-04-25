{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Me where

import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (NominalDiffTime, addUTCTime)
import Handler.Api.Common
import Import
import Theme (normalizeThemeKey, userThemeKey)
import qualified Prelude as P

getApiMeR :: Handler Value
getApiMeR = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    followerCount <- runDB $ count [UserFollowFollowing ==. viewerId]
    followingCount <- runDB $ count [UserFollowFollower ==. viewerId]
    returnJson $
        object
            [ "user" .= userProfileValue (Just viewerId) viewer followerCount followingCount (Just False)
            ]

getApiMeSecurityEventsR :: Handler Value
getApiMeSecurityEventsR = do
    viewerId <- requireApiAuthId
    now <- liftIO getCurrentTime
    reactionRows <- runDB $ selectList [PostReactionUser ==. viewerId] [Desc PostReactionCreatedAt, LimitTo 8]
    likeRows <- runDB $ selectList [PostLikeUser ==. viewerId] [Desc PostLikeCreatedAt, LimitTo 8]
    bookmarkRows <- runDB $ selectList [PostBookmarkUser ==. viewerId] [Desc PostBookmarkCreatedAt, LimitTo 8]
    let reactionEvents =
            map (\(Entity _ row) -> SecurityEvent "reacted to post" "macOS" (postReactionCreatedAt row)) reactionRows
        likeEvents =
            map (\(Entity _ row) -> SecurityEvent "liked post" "macOS" (postLikeCreatedAt row)) likeRows
        bookmarkEvents =
            map (\(Entity _ row) -> SecurityEvent "bookmarked post" "macOS" (postBookmarkCreatedAt row)) bookmarkRows
        fallbackEvents =
            [ SecurityEvent "login" "macOS" (addUTCTime (negate $ daysToSeconds 14) now)
            , SecurityEvent "user created" "macOS" (addUTCTime (negate $ daysToSeconds 14) now)
            ]
        items =
            map securityEventValue
                . take 8
                . L.sortBy (\a b -> compare (securityEventCreatedAt b) (securityEventCreatedAt a))
                $ reactionEvents <> likeEvents <> bookmarkEvents <> fallbackEvents
    returnJson $ object ["items" .= items]

patchApiMeProfileR :: Handler Value
patchApiMeProfileR = do
    viewerId <- requireApiAuthId
    _ <- requireDbEntity viewerId "user_not_found" "User not found."
    payload <- requireCheckJsonBody :: Handler UpdateProfilePayload
    let nameValue = normalizeOptionalText (updateProfileName payload)
        descriptionValue = normalizeOptionalText (updateProfileDescription payload)
        countryCodeValue = toUpperText (updateProfileCountryCode payload)
        stateValue = stripText (updateProfileState payload)
    (mLatitudeValue, mLongitudeValue) <-
        validateProfilePayload countryCodeValue stateValue (updateProfileLatitude payload) (updateProfileLongitude payload)
    runDB $
        update viewerId
            [ UserName =. nameValue
            , UserDescription =. descriptionValue
            , UserCountryCode =. Just countryCodeValue
            , UserState =. Just stateValue
            , UserLocalRegionOnly =. updateProfileLocalRegionOnly payload
            , UserLatitude =. mLatitudeValue
            , UserLongitude =. mLongitudeValue
            ]
    updated <- requireDbEntity viewerId "user_not_found" "User not found."
    followerCount <- runDB $ count [UserFollowFollowing ==. viewerId]
    followingCount <- runDB $ count [UserFollowFollower ==. viewerId]
    returnJson $
        object
            [ "user" .= userProfileValue (Just viewerId) updated followerCount followingCount (Just False)
            ]
  where
    stripText = T.strip
    toUpperText = T.toUpper . T.strip

patchApiMePreferencesR :: Handler Value
patchApiMePreferencesR = do
    viewerId <- requireApiAuthId
    _ <- requireDbEntity viewerId "user_not_found" "User not found."
    payload <- requireCheckJsonBody :: Handler UpdatePreferencesPayload
    themeKey <-
        case normalizeThemeKey (updatePreferencesTheme payload) of
            Just value -> pure value
            Nothing -> jsonError status400 "invalid_theme" "Invalid theme."
    runDB $ update viewerId [UserTheme =. Just themeKey]
    updated <- requireDbEntity viewerId "user_not_found" "User not found."
    returnJson $
        object
            [ "theme" .= userThemeKey (entityVal updated)
            , "user" .= object
                [ "id" .= keyToInt viewerId
                , "theme" .= userThemeKey (entityVal updated)
                ]
            ]

getApiMeBookmarksR :: Handler Value
getApiMeBookmarksR = do
    viewerId <- requireApiAuthId
    (page, size, offset) <- paginationParams
    bookmarkRows <- runDB $ selectList [PostBookmarkUser ==. viewerId] [Desc PostBookmarkCreatedAt, OffsetBy offset, LimitTo (size + 1)]
    let hasNext = P.length bookmarkRows > size
        pageRows = P.take size bookmarkRows
        bookmarkedPostIds = map (postBookmarkPost . entityVal) pageRows
    posts <-
        if P.null bookmarkedPostIds
            then pure []
            else do
                rows <- runDB $ selectList [PostId <-. bookmarkedPostIds] []
                let postMap = Map.fromList $ map (\ent@(Entity pid _) -> (pid, ent)) rows
                pure $ mapMaybe (\(Entity _ bookmark) -> Map.lookup (postBookmarkPost bookmark) postMap) pageRows
    items <- buildPostSummaryValues (Just viewerId) posts
    returnJson $
        object
            [ "items" .= items
            , "page" .= page
            , "size" .= size
            , "hasNext" .= hasNext
            ]

getApiMeBlockedUsersR :: Handler Value
getApiMeBlockedUsersR = do
    viewerId <- requireApiAuthId
    rows <- runDB $ selectList [UserBlockBlocker ==. viewerId] [Desc UserBlockCreatedAt]
    let blockedIds = map (userBlockBlocked . entityVal) rows
    users <- if P.null blockedIds then pure [] else runDB $ selectList [UserId <-. blockedIds] []
    let userMap = Map.fromList $ map (\(Entity userId user) -> (userId, user)) users
        items =
            mapMaybe
                (\ent@(Entity _ block) ->
                    blockedUserValue ent <$> Map.lookup (userBlockBlocked block) userMap
                )
                rows
    returnJson $ object ["items" .= items]

data SecurityEvent = SecurityEvent
    { securityEventLabel :: Text
    , securityEventPlatform :: Text
    , securityEventCreatedAt :: UTCTime
    }

securityEventValue :: SecurityEvent -> Value
securityEventValue event =
    object
        [ "label" .= securityEventLabel event
        , "platform" .= securityEventPlatform event
        , "createdAt" .= securityEventCreatedAt event
        ]

daysToSeconds :: Int -> NominalDiffTime
daysToSeconds d = fromInteger (toInteger d) * 86400
