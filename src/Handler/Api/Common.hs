{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeOperators #-}

module Handler.Api.Common where

import Auth.Jwt (bearerTokenFromHeader, verifyJwt)
import Data.Aeson (withObject, (.!=), (.:?))
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Time (addDays)
import Data.Type.Equality (type (~))
import Database.Persist.Sql (fromSqlKey, toSqlKey)
import Forum.Tag (loadPostTagsMap)
import Import
import SiteSettings
import Theme (userThemeKey)
import qualified Data.Text as T
import qualified Prelude as P

data AuthPayload = AuthPayload
    { authPayloadUsername :: Text
    , authPayloadPassword :: Text
    , authPayloadAccountType :: Text
    , authPayloadEmployerPlan :: Maybe Text
    , authPayloadRealEstatePlan :: Maybe Text
    }

instance FromJSON AuthPayload where
    parseJSON = withObject "AuthPayload" $ \o ->
        AuthPayload
            <$> o .: "username"
            <*> o .: "password"
            <*> o .:? "accountType" .!= "personal"
            <*> o .:? "employerPlan"
            <*> o .:? "realEstatePlan"

data UpdateProfilePayload = UpdateProfilePayload
    { updateProfileName :: Maybe Text
    , updateProfileDescription :: Maybe Text
    , updateProfileCountryCode :: Text
    , updateProfileState :: Text
    , updateProfileLocalRegionOnly :: Bool
    , updateProfileLatitude :: Maybe Double
    , updateProfileLongitude :: Maybe Double
    }

instance FromJSON UpdateProfilePayload where
    parseJSON = withObject "UpdateProfilePayload" $ \o ->
        UpdateProfilePayload
            <$> o .:? "name"
            <*> o .:? "description"
            <*> o .: "countryCode"
            <*> o .: "state"
            <*> o .: "localRegionOnly"
            <*> o .:? "latitude"
            <*> o .:? "longitude"

data UpdatePreferencesPayload = UpdatePreferencesPayload
    { updatePreferencesTheme :: Text
    }

instance FromJSON UpdatePreferencesPayload where
    parseJSON = withObject "UpdatePreferencesPayload" $ \o ->
        UpdatePreferencesPayload <$> o .: "theme"

data PostPayload = PostPayload
    { postPayloadTitle :: Text
    , postPayloadContent :: Text
    , postPayloadTags :: Maybe [Text]
    , postPayloadLatitude :: Maybe Double
    , postPayloadLongitude :: Maybe Double
    }

instance FromJSON PostPayload where
    parseJSON = withObject "PostPayload" $ \o ->
        PostPayload
            <$> o .: "title"
            <*> o .: "content"
            <*> o .:? "tags"
            <*> o .:? "latitude"
            <*> o .:? "longitude"

data UpdatePostPayload = UpdatePostPayload
    { updatePostTitle :: Text
    , updatePostContent :: Text
    , updatePostTags :: Maybe [Text]
    }

instance FromJSON UpdatePostPayload where
    parseJSON = withObject "UpdatePostPayload" $ \o ->
        UpdatePostPayload <$> o .: "title" <*> o .: "content" <*> o .:? "tags"

data CommentPayload = CommentPayload
    { commentPayloadContent :: Text
    , commentPayloadParentCommentId :: Maybe CommentId
    }

instance FromJSON CommentPayload where
    parseJSON = withObject "CommentPayload" $ \o ->
        CommentPayload <$> o .: "content" <*> o .:? "parentCommentId"

data UpdateCommentPayload = UpdateCommentPayload
    { updateCommentContent :: Text
    }

instance FromJSON UpdateCommentPayload where
    parseJSON = withObject "UpdateCommentPayload" $ \o ->
        UpdateCommentPayload <$> o .: "content"

data ReactionPayload = ReactionPayload
    { reactionPayloadEmoji :: Text
    }

instance FromJSON ReactionPayload where
    parseJSON = withObject "ReactionPayload" $ \o ->
        ReactionPayload <$> o .: "emoji"

data CreateChatPayload = CreateChatPayload
    { createChatPeerId :: UserId
    }

instance FromJSON CreateChatPayload where
    parseJSON = withObject "CreateChatPayload" $ \o ->
        CreateChatPayload <$> o .: "peerId"

data CreateDirectMessagePayload = CreateDirectMessagePayload
    { createDirectMessageContent :: Text
    }

instance FromJSON CreateDirectMessagePayload where
    parseJSON = withObject "CreateDirectMessagePayload" $ \o ->
        CreateDirectMessagePayload <$> o .: "content"

data CreateCompanyPayload = CreateCompanyPayload
    { createCompanyName :: Text
    , createCompanyCategoryId :: CompanyGroupId
    , createCompanyWebsite :: Maybe Text
    , createCompanySize :: Maybe Text
    , createCompanyDescription :: Text
    , createCompanyLatitude :: Maybe Double
    , createCompanyLongitude :: Maybe Double
    }

instance FromJSON CreateCompanyPayload where
    parseJSON = withObject "CreateCompanyPayload" $ \o ->
        CreateCompanyPayload
            <$> o .: "name"
            <*> o .: "categoryId"
            <*> o .:? "website"
            <*> o .:? "size"
            <*> o .: "description"
            <*> o .:? "latitude"
            <*> o .:? "longitude"

data UpdateCompanyPayload = UpdateCompanyPayload
    { updateCompanyName :: Text
    , updateCompanyCategoryId :: CompanyGroupId
    , updateCompanyWebsite :: Maybe Text
    , updateCompanySize :: Maybe Text
    , updateCompanyDescription :: Text
    , updateCompanyLatitude :: Maybe Double
    , updateCompanyLongitude :: Maybe Double
    }

instance FromJSON UpdateCompanyPayload where
    parseJSON = withObject "UpdateCompanyPayload" $ \o ->
        UpdateCompanyPayload
            <$> o .: "name"
            <*> o .: "categoryId"
            <*> o .:? "website"
            <*> o .:? "size"
            <*> o .: "description"
            <*> o .:? "latitude"
            <*> o .:? "longitude"

data CreateJobPayload = CreateJobPayload
    { createJobTitle :: Text
    , createJobCompany :: Text
    , createJobCompanyId :: Maybe CompanyId
    , createJobSalary :: Maybe Text
    , createJobSalaryMin :: Maybe Int
    , createJobSalaryMax :: Maybe Int
    , createJobSalaryCurrency :: Maybe Text
    , createJobSalaryPeriod :: Maybe Text
    , createJobWorkingHours :: Maybe Text
    , createJobDeadline :: Maybe Day
    , createJobExperience :: Maybe Text
    , createJobSeniority :: Maybe Text
    , createJobEmploymentType :: Text
    , createJobWorkplaceType :: Maybe Text
    , createJobApplyUrl :: Maybe Text
    , createJobApplyEmail :: Maybe Text
    , createJobSkills :: [Text]
    , createJobBenefits :: [Text]
    , createJobContent :: Text
    , createJobLatitude :: Maybe Double
    , createJobLongitude :: Maybe Double
    }

instance FromJSON CreateJobPayload where
    parseJSON = withObject "CreateJobPayload" $ \o ->
        CreateJobPayload
            <$> o .: "title"
            <*> o .: "company"
            <*> o .:? "companyId"
            <*> o .:? "salary"
            <*> o .:? "salaryMin"
            <*> o .:? "salaryMax"
            <*> o .:? "salaryCurrency"
            <*> o .:? "salaryPeriod"
            <*> o .:? "workingHours"
            <*> o .:? "deadline"
            <*> o .:? "experience"
            <*> o .:? "seniority"
            <*> o .:? "employmentType" .!= "full_time"
            <*> o .:? "workplaceType"
            <*> o .:? "applyUrl"
            <*> o .:? "applyEmail"
            <*> o .:? "skills" .!= []
            <*> o .:? "benefits" .!= []
            <*> o .: "content"
            <*> o .:? "latitude"
            <*> o .:? "longitude"

data UpdateJobPayload = UpdateJobPayload
    { updateJobTitle :: Text
    , updateJobCompany :: Text
    , updateJobCompanyId :: Maybe CompanyId
    , updateJobSalary :: Maybe Text
    , updateJobSalaryMin :: Maybe Int
    , updateJobSalaryMax :: Maybe Int
    , updateJobSalaryCurrency :: Maybe Text
    , updateJobSalaryPeriod :: Maybe Text
    , updateJobWorkingHours :: Maybe Text
    , updateJobDeadline :: Maybe Day
    , updateJobExperience :: Maybe Text
    , updateJobSeniority :: Maybe Text
    , updateJobEmploymentType :: Text
    , updateJobWorkplaceType :: Maybe Text
    , updateJobApplyUrl :: Maybe Text
    , updateJobApplyEmail :: Maybe Text
    , updateJobSkills :: [Text]
    , updateJobBenefits :: [Text]
    , updateJobContent :: Text
    , updateJobLatitude :: Maybe Double
    , updateJobLongitude :: Maybe Double
    }

instance FromJSON UpdateJobPayload where
    parseJSON = withObject "UpdateJobPayload" $ \o ->
        UpdateJobPayload
            <$> o .: "title"
            <*> o .: "company"
            <*> o .:? "companyId"
            <*> o .:? "salary"
            <*> o .:? "salaryMin"
            <*> o .:? "salaryMax"
            <*> o .:? "salaryCurrency"
            <*> o .:? "salaryPeriod"
            <*> o .:? "workingHours"
            <*> o .:? "deadline"
            <*> o .:? "experience"
            <*> o .:? "seniority"
            <*> o .:? "employmentType" .!= "full_time"
            <*> o .:? "workplaceType"
            <*> o .:? "applyUrl"
            <*> o .:? "applyEmail"
            <*> o .:? "skills" .!= []
            <*> o .:? "benefits" .!= []
            <*> o .: "content"
            <*> o .:? "latitude"
            <*> o .:? "longitude"

data ApplyJobPayload = ApplyJobPayload
    { applyJobNote :: Maybe Text
    }

instance FromJSON ApplyJobPayload where
    parseJSON = withObject "ApplyJobPayload" $ \o ->
        ApplyJobPayload
            <$> o .:? "note"

data UpdateJobApplicationPayload = UpdateJobApplicationPayload
    { updateJobApplicationStatus :: Text
    , updateJobApplicationManagerNote :: Maybe Text
    , updateJobApplicationRating :: Maybe Int
    }

instance FromJSON UpdateJobApplicationPayload where
    parseJSON = withObject "UpdateJobApplicationPayload" $ \o ->
        UpdateJobApplicationPayload
            <$> o .: "status"
            <*> o .:? "managerNote"
            <*> o .:? "rating"

reactionEmojiOptions :: [Text]
reactionEmojiOptions =
    ["👍", "👎", "🎉", "😀", "😮", "❤️", "🚀", "👏", "🤯", "💸", "💯", "😂", "😢", "🤮"]

data FeedTab
    = FeedUnread
    | FeedEverything
    | FeedLocal
    | FeedTrends
    | FeedFollowing
    | FeedInterests
    deriving (Eq)

data PostTypeFilter
    = PostTypeText
    | PostTypeLink
    | PostTypeMedia
    deriving (Eq)

data ActiveRegionFilter
    = RegionFilterDisabled
    | RegionFilterUnavailable
    | RegionFilterEnabled Text Text

loadSettingMap :: Handler SiteSettingMap
loadSettingMap = siteSettingMapFromEntities <$> runDB (selectList [] [])

maybeApiAuthId :: Handler (Maybe UserId)
maybeApiAuthId = do
    settings <- getsYesod appSettings
    mAuthorization <- lookupHeader "Authorization"
    case bearerTokenFromHeader mAuthorization of
        Left err -> jsonError status401 "invalid_authorization_header" err
        Right (Just token) -> do
            now <- liftIO getCurrentTime
            case verifyJwt settings now token of
                Left err -> jsonError status401 "invalid_token" err
                Right subjectId -> pure $ Just (toSqlKey subjectId)
        Right Nothing -> maybeAuthId

maybeApiAuth :: Handler (Maybe (Entity User))
maybeApiAuth =
    maybeApiAuthId >>= \case
        Nothing -> pure Nothing
        Just userId -> fmap (Entity userId) <$> runDB (get userId)

ensureApiReadAllowed :: Handler ()
ensureApiReadAllowed = do
    settingMap <- loadSettingMap
    mViewerId <- maybeApiAuthId
    unless (siteSettingBool "allow_anonymous_read" True settingMap || isJust mViewerId) $
        jsonError status401 "authentication_required" "Authentication required."

requireApiAuthId :: Handler UserId
requireApiAuthId =
    maybeApiAuthId >>= \case
        Nothing -> jsonError status401 "authentication_required" "Authentication required."
        Just userId -> pure userId

requireDbEntity
    :: (PersistEntityBackend record ~ SqlBackend, PersistEntity record)
    => Key record
    -> Text
    -> Text
    -> Handler (Entity record)
requireDbEntity entityId errCode errMessage = do
    mEntity <- runDB $ get entityId
    case mEntity of
        Nothing -> jsonError status404 errCode errMessage
        Just entity -> pure (Entity entityId entity)

jsonError :: Status -> Text -> Text -> Handler a
jsonError status code message =
    sendResponseStatus status (object ["error" .= code, "message" .= message])

paginationParams :: Handler (Int, Int, Int)
paginationParams = do
    page <- max 1 <$> queryIntParam "page" 1
    size <- min 100 . max 1 <$> queryIntParam "size" 20
    pure (page, size, (page - 1) * size)

queryIntParam :: Text -> Int -> Handler Int
queryIntParam key fallback =
    lookupGetParam key >>= \case
        Nothing -> pure fallback
        Just raw ->
            maybe (pure fallback) pure (fromPathPiece raw)

parseBoolFlag :: Maybe Text -> Bool
parseBoolFlag mRaw =
    case fmap (T.toLower . T.strip) mRaw of
        Just "1" -> True
        Just "true" -> True
        Just "yes" -> True
        Just "on" -> True
        _ -> False

normalizeTagFilter :: Maybe Text -> Maybe Text
normalizeTagFilter Nothing = Nothing
normalizeTagFilter (Just raw) =
    let cleaned = T.toLower $ T.dropWhile (== '#') $ T.strip raw
    in if T.null cleaned then Nothing else Just cleaned

normalizeSortTrending :: Maybe Text -> Bool
normalizeSortTrending mRaw =
    case fmap (T.toLower . T.strip) mRaw of
        Just "trending" -> True
        _ -> False

normalizeSearchFilter :: Maybe Text -> Maybe Text
normalizeSearchFilter Nothing = Nothing
normalizeSearchFilter (Just raw) =
    let cleaned = T.toLower $ T.strip raw
    in if T.null cleaned then Nothing else Just cleaned

normalizeCsvFilters :: Maybe Text -> [Text]
normalizeCsvFilters Nothing = []
normalizeCsvFilters (Just raw) =
    filter (not . T.null) $ map (T.toLower . T.strip) (T.splitOn "," raw)

parsePostTypeFilter :: Maybe Text -> Maybe PostTypeFilter
parsePostTypeFilter mRaw =
    case fmap (T.toLower . T.strip) mRaw of
        Just "text" -> Just PostTypeText
        Just "link" -> Just PostTypeLink
        Just "media" -> Just PostTypeMedia
        _ -> Nothing

parseFeedTab :: Maybe Text -> FeedTab
parseFeedTab mRaw =
    case fmap (T.toLower . T.strip) mRaw of
        Just "unread" -> FeedUnread
        Just "local" -> FeedLocal
        Just "trends" -> FeedTrends
        Just "following" -> FeedFollowing
        Just "interests" -> FeedInterests
        _ -> FeedEverything

addTagWeights :: Int -> [[Text]] -> Map.Map Text Int -> Map.Map Text Int
addTagWeights weight tagGroups initial =
    P.foldl'
        (\acc tags ->
            P.foldl'
                (\inner tag -> Map.insertWith (+) tag weight inner)
                acc
                tags
        )
        initial
        tagGroups

activeRegionFilter :: Maybe (Entity User) -> ActiveRegionFilter
activeRegionFilter Nothing = RegionFilterDisabled
activeRegionFilter (Just (Entity _ user))
    | not (userLocalRegionOnly user) = RegionFilterDisabled
    | otherwise =
        case userRegionPair user of
            Nothing -> RegionFilterUnavailable
            Just (countryCodeValue, stateValue) -> RegionFilterEnabled countryCodeValue stateValue

userRegionFields :: User -> (Maybe Text, Maybe Text)
userRegionFields user = (normalizeOptionalText (userCountryCode user), normalizeOptionalText (userState user))

userRegionPair :: User -> Maybe (Text, Text)
userRegionPair user =
    case userRegionFields user of
        (Just countryCodeValue, Just stateValue) -> Just (countryCodeValue, stateValue)
        _ -> Nothing

normalizeOptionalText :: Maybe Text -> Maybe Text
normalizeOptionalText Nothing = Nothing
normalizeOptionalText (Just raw) =
    let trimmed = T.strip raw
    in if T.null trimmed then Nothing else Just trimmed

requireCoordinatePairJson :: Maybe Double -> Maybe Double -> Handler (Maybe Double, Maybe Double)
requireCoordinatePairJson Nothing Nothing = pure (Nothing, Nothing)
requireCoordinatePairJson (Just lat) (Just lng) = pure (Just lat, Just lng)
requireCoordinatePairJson _ _ =
    jsonError status400 "invalid_coordinates" "Latitude and longitude must be provided together."

validateProfilePayload :: Text -> Text -> Maybe Double -> Maybe Double -> Handler (Maybe Double, Maybe Double)
validateProfilePayload countryCodeValue stateValue mLatitude mLongitude
    | T.null countryCodeValue = jsonError status400 "invalid_country" "Country is required."
    | T.null stateValue = jsonError status400 "invalid_state" "State is required."
    | otherwise = do
        mCountry <- runDB $ getBy $ UniqueCountryCode countryCodeValue
        when (isNothing mCountry) $
            jsonError status400 "invalid_country" "Choose a valid country."
        mState <- runDB $ getBy $ UniqueCountryStateCode countryCodeValue stateValue
        when (isNothing mState) $
            jsonError status400 "invalid_state" "Choose a valid state for the selected country."
        requireCoordinatePairJson mLatitude mLongitude

normalizeApiTags :: Maybe [Text] -> [Text]
normalizeApiTags Nothing = []
normalizeApiTags (Just rawTags) =
    L.nub $
        mapMaybe
            (\raw ->
                let cleaned = T.toLower $ T.dropWhile (== '#') $ T.strip raw
                in if T.null cleaned then Nothing else Just cleaned
            )
            rawTags

buildPostSummaryValues :: Maybe UserId -> [Entity Post] -> Handler [Value]
buildPostSummaryValues mViewerId posts = do
    let postIds = map entityKey posts
        boardIds = L.nub $ map (postBoard . entityVal) posts
        authorIds = L.nub $ map (postAuthor . entityVal) posts
    boards <- if P.null boardIds then pure [] else runDB $ selectList [BoardId <-. boardIds] []
    users <- if P.null authorIds then pure [] else runDB $ selectList [UserId <-. authorIds] []
    comments <- if P.null postIds then pure [] else runDB $ selectList [CommentPost <-. postIds] []
    likes <- if P.null postIds then pure [] else runDB $ selectList [PostLikePost <-. postIds] []
    reactions <- if P.null postIds then pure [] else runDB $ selectList [PostReactionPost <-. postIds] []
    views <- if P.null postIds then pure [] else runDB $ selectList [PostViewPost <-. postIds] []
    tagsByPost <- runDB $ loadPostTagsMap postIds
    likedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null postIds
                then pure []
                else runDB $ selectList [PostLikeUser ==. viewerId, PostLikePost <-. postIds] []
    bookmarkedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null postIds
                then pure []
                else runDB $ selectList [PostBookmarkUser ==. viewerId, PostBookmarkPost <-. postIds] []
    watchedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null postIds
                then pure []
                else runDB $ selectList [PostWatchUser ==. viewerId, PostWatchPost <-. postIds] []
    viewerReactionRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null postIds
                then pure []
                else runDB $ selectList [PostReactionUser ==. viewerId, PostReactionPost <-. postIds] []
    let boardMap = Map.fromList $ map (\(Entity bid board) -> (bid, board)) boards
        userMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) users
        commentCountMap =
            P.foldl'
                (\acc (Entity _ comment) -> Map.insertWith (+) (commentPost comment) (1 :: Int) acc)
                Map.empty
                comments
        likeCountMap =
            P.foldl'
                (\acc (Entity _ like) -> Map.insertWith (+) (postLikePost like) (1 :: Int) acc)
                Map.empty
                likes
        reactionRowsMap =
            P.foldl'
                (\acc ent@(Entity _ reaction) -> Map.insertWith (P.++) (postReactionPost reaction) [ent] acc)
                Map.empty
                reactions
        viewCountMap =
            P.foldl'
                (\acc (Entity _ view) -> Map.insertWith (+) (postViewPost view) (1 :: Int) acc)
                Map.empty
                views
        likeSet = Set.fromList $ map (postLikePost . entityVal) likedRows
        bookmarkSet = Set.fromList $ map (postBookmarkPost . entityVal) bookmarkedRows
        watchSet = Set.fromList $ map (postWatchPost . entityVal) watchedRows
        viewerReactionMap = Map.fromList $ map (\(Entity _ reaction) -> (postReactionPost reaction, postReactionEmoji reaction)) viewerReactionRows
    pure $
        map
            ( postSummaryValue
                userMap
                boardMap
                likeCountMap
                commentCountMap
                viewCountMap
                reactionRowsMap
                tagsByPost
                (Just likeSet)
                (Just bookmarkSet)
                (Just watchSet)
                (Just viewerReactionMap)
            )
            posts

postSummaryValue
    :: Map.Map UserId User
    -> Map.Map BoardId Board
    -> Map.Map PostId Int
    -> Map.Map PostId Int
    -> Map.Map PostId Int
    -> Map.Map PostId [Entity PostReaction]
    -> Map.Map PostId [Text]
    -> Maybe (Set.Set PostId)
    -> Maybe (Set.Set PostId)
    -> Maybe (Set.Set PostId)
    -> Maybe (Map.Map PostId Text)
    -> Entity Post
    -> Value
postSummaryValue userMap boardMap likeCountMap commentCountMap viewCountMap reactionRowsMap tagsByPost mLikeSet mBookmarkSet mWatchSet mViewerReactionMap (Entity postId post) =
    object
        [ "id" .= keyToInt postId
        , "title" .= postTitle post
        , "content" .= postContent post
        , "author" .= maybe Null userRefForAuthor (Map.lookup (postAuthor post) userMap)
        , "board" .= maybe Null boardRefForPost (Map.lookup (postBoard post) boardMap)
        , "tags" .= Map.findWithDefault [] postId tagsByPost
        , "likeCount" .= Map.findWithDefault 0 postId likeCountMap
        , "commentCount" .= Map.findWithDefault 0 postId commentCountMap
        , "viewCount" .= Map.findWithDefault 0 postId viewCountMap
        , "reactions" .= reactionSummaryValue (Map.findWithDefault [] postId reactionRowsMap)
        , "isLiked" .= maybe False (Set.member postId) mLikeSet
        , "isBookmarked" .= maybe False (Set.member postId) mBookmarkSet
        , "isWatching" .= maybe False (Set.member postId) mWatchSet
        , "viewerReaction" .= (Map.lookup postId =<< mViewerReactionMap)
        , "latitude" .= postLatitude post
        , "longitude" .= postLongitude post
        , "createdAt" .= postCreatedAt post
        , "updatedAt" .= postUpdatedAt post
        ]
  where
    userRefForAuthor user =
        object
            [ "id" .= keyToInt (postAuthor post)
            , "ident" .= userIdent user
            , "name" .= userName user
            ]
    boardRefForPost board =
        object
            [ "id" .= keyToInt (postBoard post)
            , "name" .= boardName board
            ]

commentValue :: Map.Map UserId User -> Entity Comment -> Value
commentValue userMap (Entity commentId comment) =
    object
        [ "id" .= keyToInt commentId
        , "content" .= commentContent comment
        , "author" .= maybe Null (\user -> object ["id" .= keyToInt (commentAuthor comment), "ident" .= userIdent user, "name" .= userName user]) (Map.lookup (commentAuthor comment) userMap)
        , "postId" .= keyToInt (commentPost comment)
        , "parentCommentId" .= fmap keyToInt (commentParentComment comment)
        , "createdAt" .= commentCreatedAt comment
        ]

boardSummaryValue :: Entity Board -> Value
boardSummaryValue (Entity boardId board) =
    object
        [ "id" .= keyToInt boardId
        , "name" .= boardName board
        , "description" .= boardDescription board
        , "postCount" .= boardPostCount board
        , "commentCount" .= boardCommentCount board
        ]

userRefValue :: Entity User -> Value
userRefValue (Entity userId user) =
    object
        [ "id" .= keyToInt userId
        , "ident" .= userIdent user
        , "name" .= userName user
        ]

userProfileValue :: Maybe UserId -> Entity User -> Int -> Int -> Maybe Bool -> Value
userProfileValue mViewerId (Entity userId user) followerCount followingCount mIsFollowing =
    object
        [ "id" .= keyToInt userId
        , "ident" .= userIdent user
        , "role" .= userRole user
        , "name" .= userName user
        , "description" .= userDescription user
        , "countryCode" .= userCountryCode user
        , "state" .= userState user
        , "localRegionOnly" .= userLocalRegionOnly user
        , "latitude" .= userLatitude user
        , "longitude" .= userLongitude user
        , "theme" .= userThemeKey user
        , "accountType" .= userAccountType user
        , "employerPlan" .= userEmployerPlan user
        , "employerPlanStartedAt" .= userEmployerPlanStartedAt user
        , "realEstatePlan" .= userRealEstatePlan user
        , "realEstatePlanStartedAt" .= userRealEstatePlanStartedAt user
        , "followerCount" .= followerCount
        , "followingCount" .= followingCount
        , "isFollowing" .= case mViewerId of
            Just viewerId | viewerId == userId -> Just False
            _ -> mIsFollowing
        ]

blockedUserValue :: Entity UserBlock -> User -> Value
blockedUserValue (Entity blockId block) user =
    object
        [ "id" .= keyToInt (userBlockBlocked block)
        , "blockId" .= keyToInt blockId
        , "ident" .= userIdent user
        , "name" .= userName user
        , "description" .= userDescription user
        , "createdAt" .= userBlockCreatedAt block
        ]

notificationValue :: Map.Map UserId User -> Entity Notification -> Value
notificationValue actorMap (Entity notificationId notification) =
    object
        [ "id" .= keyToInt notificationId
        , "actor" .= maybe Null (\actorId -> maybe Null (\user -> userRefValue (Entity actorId user)) (Map.lookup actorId actorMap)) (notificationActor notification)
        , "kind" .= notificationKind notification
        , "postId" .= fmap keyToInt (notificationPost notification)
        , "commentId" .= fmap keyToInt (notificationComment notification)
        , "jobId" .= fmap keyToInt (notificationJob notification)
        , "isRead" .= notificationIsRead notification
        , "createdAt" .= notificationCreatedAt notification
        , "message" .= notificationMessage actorMap notification
        ]

notificationMessage :: Map.Map UserId User -> Notification -> Text
notificationMessage actorMap notification =
    let actorLabel =
            maybe ("System" :: Text)
                (\uid -> maybe "Unknown" userIdent (Map.lookup uid actorMap))
                (notificationActor notification)
        suffix =
            case notificationKind notification of
                "follow" -> "started following you"
                "post-like" -> "liked your post"
                "post-bookmark" -> "bookmarked your post"
                "comment" -> "commented on your post"
                "reply" -> "replied to your comment"
                "watch-comment" -> "new activity on a post you watch"
                "job-application" -> "applied to your job post"
                "job-application-status" -> "updated your job application status"
                "job-application-withdrawn" -> "withdrew a job application"
                _ -> "sent a notification"
    in actorLabel <> " " <> suffix

directMessageValue :: Map.Map UserId User -> Entity DirectMessage -> Value
directMessageValue authorMap (Entity messageId message) =
    object
        [ "id" .= keyToInt messageId
        , "roomId" .= keyToInt (directMessageRoom message)
        , "author" .= maybe Null (\user -> object ["id" .= keyToInt (directMessageAuthor message), "ident" .= userIdent user, "name" .= userName user]) (Map.lookup (directMessageAuthor message) authorMap)
        , "content" .= directMessageContent message
        , "createdAt" .= directMessageCreatedAt message
        ]

companyValue :: Map.Map UserId User -> Map.Map CompanyGroupId CompanyGroup -> Entity Company -> Value
companyValue userMap categoryMap (Entity companyId company) =
    let mCategory = Map.lookup (companyCategory company) categoryMap
    in object
        [ "id" .= keyToInt companyId
        , "name" .= companyName company
        , "categoryId" .= keyToInt (companyCategory company)
        , "categoryName" .= fmap companyGroupName mCategory
        , "majorCode" .= (companyGroupMajorCode =<< mCategory)
        , "website" .= companyWebsite company
        , "size" .= companySize company
        , "countryCode" .= companyCountryCode company
        , "state" .= companyState company
        , "latitude" .= companyLatitude company
        , "longitude" .= companyLongitude company
        , "description" .= companyDescription company
        , "author" .= maybe Null (\user -> userRefValue (Entity (companyAuthor company) user)) (Map.lookup (companyAuthor company) userMap)
        , "createdAt" .= companyCreatedAt company
        , "updatedAt" .= companyUpdatedAt company
        ]

jobValue :: Map.Map UserId User -> Int -> Entity Job -> Value
jobValue = jobValueWithMeta Map.empty Map.empty Map.empty Map.empty

jobValueWithMeta :: Map.Map JobId [Text] -> Map.Map JobId [Text] -> Map.Map JobId Int -> Map.Map JobId Bool -> Map.Map UserId User -> Int -> Entity Job -> Value
jobValueWithMeta skillMap benefitMap applicationCountMap viewerAppliedMap userMap jobAutoCloseDays (Entity jobId job) =
    let today = utctDay (jobUpdatedAt job)
        isClosedByDeadline = maybe False (< today) (jobDeadline job)
        isClosedByAge =
            jobAutoCloseDays > 0
                && addDays (fromIntegral jobAutoCloseDays) (utctDay (jobCreatedAt job)) < today
        effectiveIsClosed = jobIsClosed job || isClosedByDeadline || isClosedByAge
        skills = Map.findWithDefault [] jobId skillMap
        benefits = Map.findWithDefault [] jobId benefitMap
        applicationCount = Map.findWithDefault 0 jobId applicationCountMap
        viewerHasApplied = Map.findWithDefault False jobId viewerAppliedMap
    in object
        [ "id" .= keyToInt jobId
        , "title" .= jobTitle job
        , "company" .= jobCompany job
        , "companyId" .= fmap keyToInt (jobCompanyRef job)
        , "salary" .= jobSalary job
        , "salaryMin" .= jobSalaryMin job
        , "salaryMax" .= jobSalaryMax job
        , "salaryCurrency" .= jobSalaryCurrency job
        , "salaryPeriod" .= jobSalaryPeriod job
        , "workingHours" .= jobWorkingHours job
        , "deadline" .= jobDeadline job
        , "isClosed" .= effectiveIsClosed
        , "closedAt" .= jobClosedAt job
        , "experience" .= jobExperience job
        , "seniority" .= jobSeniority job
        , "employmentType" .= jobEmploymentType job
        , "workplaceType" .= jobWorkplaceType job
        , "applyUrl" .= jobApplyUrl job
        , "applyEmail" .= jobApplyEmail job
        , "publishedAt" .= jobPublishedAt job
        , "skills" .= skills
        , "benefits" .= benefits
        , "applicationCount" .= applicationCount
        , "viewerHasApplied" .= viewerHasApplied
        , "countryCode" .= jobCountryCode job
        , "state" .= jobState job
        , "latitude" .= jobLatitude job
        , "longitude" .= jobLongitude job
        , "content" .= jobContent job
        , "author" .= maybe Null (\user -> userRefValue (Entity (jobAuthor job) user)) (Map.lookup (jobAuthor job) userMap)
        , "createdAt" .= jobCreatedAt job
        , "updatedAt" .= jobUpdatedAt job
        ]

reactionSummaryValue :: [Entity PostReaction] -> [Value]
reactionSummaryValue rows =
    map (\(emojiText, countValue) -> object ["emoji" .= emojiText, "count" .= countValue]) (reactionSummary rows)

reactionSummary :: [Entity PostReaction] -> [(Text, Int)]
reactionSummary rows =
    let countMap =
            P.foldl'
                (\acc (Entity _ reaction) -> Map.insertWith (+) (postReactionEmoji reaction) (1 :: Int) acc)
                Map.empty
                rows
        known = mapMaybe (\emoji -> fmap (\cnt -> (emoji, cnt)) (Map.lookup emoji countMap)) reactionEmojiOptions
        extras =
            L.sortBy (\(a, _) (b, _) -> compare a b) $
                filter (\(emoji, _) -> not (emoji `elem` reactionEmojiOptions)) (Map.toList countMap)
    in known P.++ extras

normalizeChatPair :: UserId -> UserId -> (UserId, UserId)
normalizeChatPair a b =
    if keyToInt a <= keyToInt b then (a, b) else (b, a)

roomPeerId :: UserId -> ChatRoom -> UserId
roomPeerId viewerId room
    | chatRoomUserA room == viewerId = chatRoomUserB room
    | otherwise = chatRoomUserA room

viewerCanAccessRoom :: UserId -> ChatRoom -> Bool
viewerCanAccessRoom viewerId room =
    chatRoomUserA room == viewerId || chatRoomUserB room == viewerId

keyToInt :: ToBackendKey SqlBackend record => Key record -> Int64
keyToInt = fromSqlKey
