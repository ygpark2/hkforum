{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Boards (getBoardsR) where

import Import
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (diffUTCTime)
import qualified Prelude as P
import Text.Blaze (preEscapedText)

getBoardsR :: Handler Html
getBoardsR = do
    mViewer <- maybeAuth
    boards <- runDB $ selectList [] [Asc BoardName]
    let localRegionFilterEnabled = maybe False (userLocalRegionOnly . entityVal) mViewer
        mActiveLocalRegion = mViewer >>= (userRegionPair . entityVal)
        localRegionNotice =
            if localRegionFilterEnabled
                then
                    case mActiveLocalRegion of
                        Just (countryCodeValue, stateValue) ->
                            Just ("내 지역 필터 적용 중: " <> stateValue <> ", " <> countryCodeValue)
                        Nothing ->
                            Just ("프로필에 국가와 주를 저장해야 내 지역 필터를 사용할 수 있습니다." :: Text)
                else Nothing
    now <- liftIO getCurrentTime
    let boardIds = map entityKey boards
    posts <-
        if P.null boardIds || (localRegionFilterEnabled && isNothing mActiveLocalRegion)
            then pure []
            else do
                let baseFilters = [PostBoard <-. boardIds]
                    regionFilters =
                        case (localRegionFilterEnabled, mActiveLocalRegion) of
                            (True, Just (countryCodeValue, stateValue)) ->
                                [ PostCountryCode ==. Just countryCodeValue
                                , PostState ==. Just stateValue
                                ]
                            _ -> []
                runDB $ selectList (baseFilters <> regionFilters) [Desc PostCreatedAt]
    let authorIds = L.nub $ map (postAuthor . entityVal) posts
    users <- if P.null authorIds
        then pure []
        else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        authorHandle uid = T.toLower $ T.filter (/= ' ') (authorName uid)
        addLatestByBoard acc ent@(Entity _ post) =
            Map.insertWith (\new old -> P.take 2 (old P.++ new)) (postBoard post) [ent] acc
        latestPostsByBoard = P.foldl' addLatestByBoard Map.empty posts
        latestPostsFor boardId = Map.findWithDefault [] boardId latestPostsByBoard
        relativeTime ts =
            let minutes = floor (diffUTCTime now ts / 60) :: Int
                hours = minutes `div` 60
                days = hours `div` 24
            in if minutes < 60 then tshow minutes <> " min ago"
               else if hours < 24 then tshow hours <> " hours ago"
               else if days < 30 then tshow days <> " days ago"
               else tshow $ formatTime defaultTimeLocale "%b %e, %Y" ts
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Boards"
        $(widgetFile "forum/boards-index")

normalizeRegionField :: Maybe Text -> Maybe Text
normalizeRegionField Nothing = Nothing
normalizeRegionField (Just raw) =
    let trimmed = T.strip raw
    in if T.null trimmed then Nothing else Just trimmed

userRegionPair :: User -> Maybe (Text, Text)
userRegionPair user =
    case (normalizeRegionField (userCountryCode user), normalizeRegionField (userState user)) of
        (Just countryCodeValue, Just stateValue) -> Just (countryCodeValue, stateValue)
        _ -> Nothing
