{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Admin where

import Company.Categories (companyMajorCategoryName, findCompanyMajorCategory)
import Company.Description (prepareCompanyDescription)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import qualified Prelude as P
import Database.Persist.Sql (fromSqlKey, toSqlKey)
import Handler.Api.Common
import Import
import SiteTemplate (normalizeSiteTemplateKey)
import SiteSettings
import Text.Read (readMaybe)
import Yesod.Auth.HashDB (setPassword)

getApiAdminBootstrapR :: Handler Value
getApiAdminBootstrapR = do
    _ <- requireApiAdminId
    boards <- runDB $ selectList [] [Asc BoardName]
    users <- runDB $ selectList [] [Asc UserIdent]
    companies <- runDB $ selectList [] [Desc CompanyUpdatedAt, Asc CompanyName]
    categories <- runDB $ selectList [] [Desc CompanyGroupIsSystem, Asc CompanyGroupSortOrder, Asc CompanyGroupName]
    ads <- runDB $ selectList [] [Asc AdSortOrder, Desc AdCreatedAt]
    settingsRows <- runDB $ selectList [] [Asc SiteSettingKey]
    postFlags <- runDB $ selectList [] [Desc PostFlagCreatedAt]
    postBlocks <- runDB $ selectList [] [Desc PostBlockCreatedAt]
    moderationLogs <- runDB $ selectList [] [Desc ModerationLogCreatedAt, LimitTo 100]
    allPosts <- runDB $ selectList [] []
    allComments <- runDB $ selectList [] []
    postCount <- runDB $ count ([] :: [Filter Post])
    commentCount <- runDB $ count ([] :: [Filter Comment])
    jobCount <- runDB $ count ([] :: [Filter Job])

    let companyCategoryIds = L.nub $ map (companyCategory . entityVal) companies
        companyAuthorIds = L.nub $ map (companyAuthor . entityVal) companies
        categoryAuthorIds = L.nub $ map (companyGroupAuthor . entityVal) categories
        moderationActorIds =
            L.nub $
                map (postFlagUser . entityVal) postFlags
                    <> map (postBlockUser . entityVal) postBlocks
                    <> map (moderationLogActor . entityVal) moderationLogs
        moderationPostIds =
            L.nub $
                map (postFlagPost . entityVal) postFlags
                    <> map (postBlockPost . entityVal) postBlocks
                    <> mapMaybe moderationLogPostId moderationLogs
        allUserIds = L.nub (companyAuthorIds <> categoryAuthorIds <> moderationActorIds)

    companyCategoryRows <-
        if P.null companyCategoryIds
            then pure []
            else runDB $ selectList [CompanyGroupId <-. companyCategoryIds] []
    companyAuthorRows <-
        if P.null allUserIds
            then pure []
            else runDB $ selectList [UserId <-. allUserIds] []
    moderationPostRows <-
        if P.null moderationPostIds
            then pure []
            else runDB $ selectList [PostId <-. moderationPostIds] []

    let userMap = Map.fromList $ map (\ent@(Entity userId _) -> (userId, ent)) (users <> companyAuthorRows)
        categoryMap = Map.fromList $ map (\(Entity categoryId category) -> (categoryId, category)) (categories <> companyCategoryRows)
        categoryNameByCode = Map.fromList $ map (\(Entity _ category) -> (companyGroupCode category, companyGroupName category)) categories
        categoryIdByCode = Map.fromList $ map (\(Entity categoryId category) -> (companyGroupCode category, categoryId)) categories
        postMap = Map.fromList $ map (\ent@(Entity postId _) -> (postId, ent)) moderationPostRows
        userPostCountMap =
            Map.fromListWith (+) $
                map (\(Entity _ post) -> (postAuthor post, 1 :: Int)) allPosts
        userCommentCountMap =
            Map.fromListWith (+) $
                map (\(Entity _ comment) -> (commentAuthor comment, 1 :: Int)) allComments
        companyCountMap =
            Map.fromListWith (+) $
                map (\(Entity _ company) -> (companyCategory company, 1 :: Int)) companies
        childCountMap =
            Map.fromListWith (+) $
                mapMaybe
                    (\(Entity _ category) ->
                        (\parentId -> (parentId, 1 :: Int)) <$> (companyGroupMajorCode category >>= (`Map.lookup` categoryIdByCode))
                    )
                    categories
        settingMap = siteSettingMapFromEntities settingsRows
    returnJson $
        object
            [ "summary" .= object
                [ "boardCount" .= P.length boards
                , "userCount" .= P.length users
                , "companyCount" .= P.length companies
                , "categoryCount" .= P.length categories
                , "adCount" .= P.length ads
                , "siteSettingCount" .= P.length settingsRows
                , "postCount" .= postCount
                , "commentCount" .= commentCount
                , "jobCount" .= jobCount
                , "postFlagCount" .= P.length postFlags
                , "postBlockCount" .= P.length postBlocks
                ]
            , "boards" .= map boardSummaryValue boards
            , "users" .= map (adminUserValue userPostCountMap userCommentCountMap) users
            , "companies" .= map (adminCompanyValue userMap categoryMap) companies
            , "companyCategories" .= map (adminCategoryValue userMap companyCountMap childCountMap categoryIdByCode categoryNameByCode) categories
            , "ads" .= map adminAdValue ads
            , "settings" .= adminSettingsValue settingMap
            , "moderation" .= object
                [ "queue" .= object
                    [ "postFlags" .= map (moderationFlagValue userMap postMap) postFlags
                    , "postBlocks" .= map (moderationBlockValue userMap postMap) postBlocks
                    ]
                , "logs" .= map (moderationLogValue userMap) moderationLogs
                ]
            ]

postApiAdminBoardsR :: Handler Value
postApiAdminBoardsR = do
    _ <- requireApiAdminId
    name <- T.strip <$> runInputPost (ireq textField "name")
    description <- normalizeOptionalTextarea <$> runInputPost (iopt textareaField "description")
    when (T.null name) $
        jsonError status400 "invalid_name" "Board name is required."
    mExisting <- runDB $ getBy $ UniqueBoard name
    case mExisting of
        Just _ -> jsonError status400 "board_exists" "Board already exists."
        Nothing -> do
            void $ runDB $ insert $ Board name description 0 0
            returnJson $ object ["message" .= ("Board created." :: Text)]

postApiAdminBoardR :: BoardId -> Handler Value
postApiAdminBoardR boardId = do
    _ <- requireApiAdminId
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            postCount <- runDB $ count [PostBoard ==. boardId]
            if postCount > 0
                then jsonError status400 "board_not_empty" "Board has posts and cannot be deleted."
                else do
                    runDB $ delete boardId
                    returnJson $ object ["message" .= ("Board deleted." :: Text)]
        "update" -> do
            name <- T.strip <$> runInputPost (ireq textField "name")
            description <- normalizeOptionalTextarea <$> runInputPost (iopt textareaField "description")
            when (T.null name) $
                jsonError status400 "invalid_name" "Board name is required."
            mExisting <- runDB $ getBy $ UniqueBoard name
            case mExisting of
                Just (Entity existingId _) | existingId /= boardId ->
                    jsonError status400 "board_exists" "Board name already exists."
                _ -> do
                    runDB $ update boardId [BoardName =. name, BoardDescription =. description]
                    returnJson $ object ["message" .= ("Board updated." :: Text)]
        _ -> jsonError status400 "unknown_action" "Unknown action."

postApiAdminCompaniesR :: Handler Value
postApiAdminCompaniesR = do
    adminId <- requireApiAdminId
    admin <- requireDbEntity adminId "user_not_found" "User not found."
    nameRaw <- runInputPost $ ireq textField "name"
    categoryId <- parsePostedCompanyCategoryId
    mWebsite <- runInputPost $ iopt textField "website"
    mSize <- runInputPost $ iopt textField "size"
    descriptionRaw <- runInputPost $ ireq textField "description"
    _ <- requireDbEntity categoryId "category_not_found" "Category not found."
    now <- liftIO getCurrentTime
    let name = T.strip nameRaw
        website = normalizeOptionalText mWebsite
        sizeValue = normalizeOptionalText mSize
        (mCountryCodeValue, mStateValue) = userRegionFields (entityVal admin)
    when (T.null name) $
        jsonError status400 "invalid_name" "Company name is required."
    description <-
        case prepareCompanyDescription descriptionRaw of
            Left err -> jsonError status400 "invalid_description" err
            Right value -> pure value
    _ <- runDB $ insert Company
        { companyName = name
        , companyCategory = categoryId
        , companyWebsite = website
        , companySize = sizeValue
        , companyCountryCode = mCountryCodeValue
        , companyState = mStateValue
        , companyLatitude = Nothing
        , companyLongitude = Nothing
        , companyDescription = description
        , companyAuthor = adminId
        , companyCreatedAt = now
        , companyUpdatedAt = now
        }
    returnJson $ object ["message" .= ("Company created." :: Text)]

postApiAdminCompanyR :: CompanyId -> Handler Value
postApiAdminCompanyR companyId = do
    _ <- requireApiAdminId
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            runDB $ delete companyId
            returnJson $ object ["message" .= ("Company deleted." :: Text)]
        "update" -> do
            nameRaw <- runInputPost $ ireq textField "name"
            categoryId <- parsePostedCompanyCategoryId
            mWebsite <- runInputPost $ iopt textField "website"
            mSize <- runInputPost $ iopt textField "size"
            descriptionRaw <- runInputPost $ ireq textField "description"
            _ <- requireDbEntity categoryId "category_not_found" "Category not found."
            now <- liftIO getCurrentTime
            let name = T.strip nameRaw
                website = normalizeOptionalText mWebsite
                sizeValue = normalizeOptionalText mSize
            when (T.null name) $
                jsonError status400 "invalid_name" "Company name is required."
            description <-
                case prepareCompanyDescription descriptionRaw of
                    Left err -> jsonError status400 "invalid_description" err
                    Right value -> pure value
            runDB $ update companyId
                [ CompanyName =. name
                , CompanyCategory =. categoryId
                , CompanyWebsite =. website
                , CompanySize =. sizeValue
                , CompanyDescription =. description
                , CompanyUpdatedAt =. now
                ]
            returnJson $ object ["message" .= ("Company updated." :: Text)]
        _ -> jsonError status400 "unknown_action" "Unknown action."

postApiAdminCompanyCategoriesR :: Handler Value
postApiAdminCompanyCategoriesR = do
    adminId <- requireApiAdminId
    nameRaw <- runInputPost $ ireq textField "name"
    codeRaw <- runInputPost $ ireq textField "code"
    description <- runInputPost $ iopt textareaField "description"
    mParentMajorCode <- parsePostedParentMajorCode
    now <- liftIO getCurrentTime
    let name = T.strip nameRaw
        code = T.strip codeRaw
        mDescription = normalizeOptionalTextarea description
    when (T.null name) $
        jsonError status400 "invalid_name" "Category name is required."
    when (T.null code) $
        jsonError status400 "invalid_code" "Category code is required."
    validateParentMajorCode Nothing mParentMajorCode
    inserted <- runDB $ insertBy $
        CompanyGroup name mDescription adminId now code mParentMajorCode 0 False
    case inserted of
        Left _ -> jsonError status400 "category_code_exists" "Company category code already exists."
        Right _ -> returnJson $ object ["message" .= ("Company category created." :: Text)]

postApiAdminCompanyCategoryR :: CompanyGroupId -> Handler Value
postApiAdminCompanyCategoryR categoryId = do
    _ <- requireApiAdminId
    action <- runInputPost $ ireq textField "action"
    category <- requireDbEntity categoryId "category_not_found" "Category not found."
    case action of
        "delete" -> do
            companyCount <- runDB $ count [CompanyCategory ==. categoryId]
            childCount <- runDB $ count [CompanyGroupMajorCode ==. Just (companyGroupCode (entityVal category))]
            when (companyGroupIsSystem (entityVal category)) $
                jsonError status400 "system_category" "System category cannot be deleted."
            when (companyCount > 0) $
                jsonError status400 "category_not_empty" "Category has companies and cannot be deleted."
            when (childCount > 0) $
                jsonError status400 "category_has_children" "Major category has child categories and cannot be deleted."
            runDB $ delete categoryId
            returnJson $ object ["message" .= ("Company category deleted." :: Text)]
        "update" -> do
            let currentCategory = entityVal category
            when (companyGroupIsSystem currentCategory) $
                jsonError status400 "system_category" "System category cannot be edited."
            nameRaw <- runInputPost $ ireq textField "name"
            codeRaw <- runInputPost $ ireq textField "code"
            description <- runInputPost $ iopt textareaField "description"
            mParentMajorCode <- parsePostedParentMajorCode
            let name = T.strip nameRaw
                code = T.strip codeRaw
                mDescription = normalizeOptionalTextarea description
            when (T.null name) $
                jsonError status400 "invalid_name" "Category name is required."
            when (T.null code) $
                jsonError status400 "invalid_code" "Category code is required."
            validateParentMajorCode (Just category) mParentMajorCode
            childCount <- runDB $ count [CompanyGroupMajorCode ==. Just (companyGroupCode currentCategory)]
            when (isJust mParentMajorCode && childCount > 0) $
                jsonError status400 "category_has_children" "Major category with child categories cannot become a subcategory."
            mExistingCode <- runDB $ getBy $ UniqueCompanyGroupCode code
            case mExistingCode of
                Just (Entity existingId _) | existingId /= categoryId ->
                    jsonError status400 "category_code_exists" "Company category code already exists."
                _ -> do
                    runDB $ do
                        update categoryId
                            [ CompanyGroupName =. name
                            , CompanyGroupCode =. code
                            , CompanyGroupDescription =. mDescription
                            , CompanyGroupMajorCode =. mParentMajorCode
                            ]
                        when (isNothing (companyGroupMajorCode currentCategory) && companyGroupCode currentCategory /= code) $
                            updateWhere
                                [CompanyGroupMajorCode ==. Just (companyGroupCode currentCategory)]
                                [CompanyGroupMajorCode =. Just code]
                    returnJson $ object ["message" .= ("Company category updated." :: Text)]
        _ -> jsonError status400 "unknown_action" "Unknown action."

postApiAdminUsersR :: Handler Value
postApiAdminUsersR = do
    _ <- requireApiAdminId
    ident <- T.strip <$> runInputPost (ireq textField "ident")
    password <- runInputPost $ ireq passwordField "password"
    role <- normalizeRole <$> runInputPost (ireq textField "role")
    name <- normalizeOptionalText <$> runInputPost (iopt textField "name")
    description <- normalizeOptionalText <$> runInputPost (iopt textField "description")
    when (T.null ident) $
        jsonError status400 "invalid_ident" "Username is required."
    when (T.null password) $
        jsonError status400 "invalid_password" "Password is required."
    mExisting <- runDB $ getBy $ UniqueUser ident
    case mExisting of
        Just _ -> jsonError status400 "user_exists" "User already exists."
        Nothing -> do
            user <- liftIO $ setPassword password (User ident Nothing role name description Nothing Nothing False Nothing Nothing Nothing "personal" Nothing Nothing Nothing Nothing)
            void $ runDB $ insert user
            returnJson $ object ["message" .= ("User created." :: Text)]

postApiAdminUserR :: UserId -> Handler Value
postApiAdminUserR userId = do
    adminId <- requireApiAdminId
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            when (userId == adminId) $
                jsonError status400 "self_delete" "You cannot delete your own account."
            postCount <- runDB $ count [PostAuthor ==. userId]
            commentCount <- runDB $ count [CommentAuthor ==. userId]
            when (postCount + commentCount > 0) $
                jsonError status400 "user_has_content" "User has content and cannot be deleted."
            runDB $ delete userId
            returnJson $ object ["message" .= ("User deleted." :: Text)]
        "update" -> do
            ident <- T.strip <$> runInputPost (ireq textField "ident")
            role <- normalizeRole <$> runInputPost (ireq textField "role")
            name <- normalizeOptionalText <$> runInputPost (iopt textField "name")
            description <- normalizeOptionalText <$> runInputPost (iopt textField "description")
            password <- runInputPost $ iopt passwordField "password"
            when (T.null ident) $
                jsonError status400 "invalid_ident" "Username is required."
            mExisting <- runDB $ getBy $ UniqueUser ident
            case mExisting of
                Just (Entity existingId _) | existingId /= userId ->
                    jsonError status400 "user_exists" "Username already exists."
                _ -> do
                    user <- requireDbEntity userId "user_not_found" "User not found."
                    let baseUser =
                            (entityVal user)
                                { userIdent = ident
                                , userRole = role
                                , userName = name
                                , userDescription = description
                                }
                    updatedUser <- case password of
                        Nothing -> pure baseUser
                        Just pwd | T.null pwd -> pure baseUser
                        Just pwd -> liftIO $ setPassword pwd baseUser
                    runDB $ replace userId updatedUser
                    returnJson $ object ["message" .= ("User updated." :: Text)]
        _ -> jsonError status400 "unknown_action" "Unknown action."

postApiAdminSettingsR :: Handler Value
postApiAdminSettingsR = do
    _ <- requireApiAdminId
    action <- runInputPost $ ireq textField "action"
    case action of
        "save-site-basics" -> saveSettingGroup siteBasicsSettingKeys "Site settings updated."
        "save-forum" -> saveSettingGroup forumSettingKeys "Forum settings updated."
        "save-upload" -> saveSettingGroup uploadSettingKeys "Upload settings updated."
        "save-moderation" -> saveSettingGroup moderationSettingKeys "Moderation settings updated."
        "save-ads" -> saveSettingGroup adsSettingKeys "Ad settings updated."
        "save-features" -> saveSettingGroup featureSettingKeys "Feature settings updated."
        _ -> jsonError status400 "unknown_action" "Unknown action."

postApiAdminAdsR :: Handler Value
postApiAdminAdsR = do
    _ <- requireApiAdminId
    title <- T.strip <$> runInputPost (ireq textField "title")
    body <- T.strip <$> runInputPost (ireq textField "body")
    mLink <- normalizeOptionalText <$> runInputPost (iopt textField "link")
    isActive <- runInputPost $ ireq checkBoxField "isActive"
    mStartDate <- runInputPost $ iopt dayField "startDate"
    mEndDate <- runInputPost $ iopt dayField "endDate"
    position <- T.strip <$> runInputPost (ireq textField "position")
    sortOrder <- runInputPost $ ireq intField "sortOrder"
    now <- liftIO getCurrentTime
    when (T.null title) $
        jsonError status400 "invalid_title" "Title is required."
    when (T.null body) $
        jsonError status400 "invalid_body" "Body is required."
    when (T.null position) $
        jsonError status400 "invalid_position" "Position is required."
    when (hasInvalidAdSchedule mStartDate mEndDate) $
        jsonError status400 "invalid_schedule" "Start date must be on or before end date."
    _ <- runDB $ insert $ Ad title body mLink isActive mStartDate mEndDate position sortOrder now now
    returnJson $ object ["message" .= ("Ad created." :: Text)]

postApiAdminAdR :: AdId -> Handler Value
postApiAdminAdR adId = do
    _ <- requireApiAdminId
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            runDB $ delete adId
            returnJson $ object ["message" .= ("Ad deleted." :: Text)]
        "update" -> do
            title <- T.strip <$> runInputPost (ireq textField "title")
            body <- T.strip <$> runInputPost (ireq textField "body")
            mLink <- normalizeOptionalText <$> runInputPost (iopt textField "link")
            isActive <- runInputPost $ ireq checkBoxField "isActive"
            mStartDate <- runInputPost $ iopt dayField "startDate"
            mEndDate <- runInputPost $ iopt dayField "endDate"
            position <- T.strip <$> runInputPost (ireq textField "position")
            sortOrder <- runInputPost $ ireq intField "sortOrder"
            now <- liftIO getCurrentTime
            when (T.null title) $
                jsonError status400 "invalid_title" "Title is required."
            when (T.null body) $
                jsonError status400 "invalid_body" "Body is required."
            when (T.null position) $
                jsonError status400 "invalid_position" "Position is required."
            when (hasInvalidAdSchedule mStartDate mEndDate) $
                jsonError status400 "invalid_schedule" "Start date must be on or before end date."
            runDB $ update adId
                [ AdTitle =. title
                , AdBody =. body
                , AdLink =. mLink
                , AdIsActive =. isActive
                , AdStartDate =. mStartDate
                , AdEndDate =. mEndDate
                , AdPosition =. position
                , AdSortOrder =. sortOrder
                , AdUpdatedAt =. now
                ]
            returnJson $ object ["message" .= ("Ad updated." :: Text)]
        _ -> jsonError status400 "unknown_action" "Unknown action."

postApiAdminModerationActionR :: Handler Value
postApiAdminModerationActionR = do
    actor <- requireApiAdminId
    action <- runInputPost $ ireq textField "action"
    now <- liftIO getCurrentTime
    case action of
        "post-flag-delete" -> do
            flagId <- runInputPost $ ireq hiddenField "id"
            mFlag <- runDB $ get flagId
            runDB $ delete flagId
            let targetId = maybe "unknown" (T.pack . show . fromSqlKey . postFlagPost) mFlag
            runDB $ insert_ $ ModerationLog actor "post-flag" targetId "delete" now
            returnJson $ object ["message" .= ("Post flag removed." :: Text)]
        "post-block-delete" -> do
            blockId <- runInputPost $ ireq hiddenField "id"
            mBlock <- runDB $ get blockId
            runDB $ delete blockId
            let targetId = maybe "unknown" (T.pack . show . fromSqlKey . postBlockPost) mBlock
            runDB $ insert_ $ ModerationLog actor "post-block" targetId "delete" now
            returnJson $ object ["message" .= ("Post block removed." :: Text)]
        _ -> jsonError status400 "unknown_action" "Unknown action."

requireApiAdminId :: Handler UserId
requireApiAdminId = do
    userId <- requireApiAuthId
    user <- requireDbEntity userId "user_not_found" "User not found."
    unless (userRole (entityVal user) == "admin") $
        jsonError status403 "admin_only" "Admin only"
    pure userId

saveSettingGroup :: [Text] -> Text -> Handler Value
saveSettingGroup settingKeys successMessage = do
    (params, _) <- runRequestBody
    let paramMap = Map.fromList params
        settingPairs =
            map
                (\key ->
                    let rawValue = T.strip (fromMaybe "" (Map.lookup key paramMap))
                    in (key, normalizeAdminSettingValue key rawValue)
                )
                settingKeys
    runDB $
        forM_ settingPairs $ \(key, value) ->
            if T.null value
                then deleteBy (UniqueSiteSetting key)
                else void $ upsert (SiteSetting key value) [SiteSettingValue =. value]
    returnJson $ object ["message" .= successMessage]

normalizeAdminSettingValue :: Text -> Text -> Text
normalizeAdminSettingValue "site_template" raw =
    fromMaybe "" (normalizeSiteTemplateKey raw)
normalizeAdminSettingValue _ raw = raw

normalizeOptionalTextarea :: Maybe Textarea -> Maybe Text
normalizeOptionalTextarea = normalizeOptionalText . fmap unTextarea

parsePostedCompanyCategoryId :: Handler CompanyGroupId
parsePostedCompanyCategoryId = do
    categoryIdRaw <- runInputPost $ ireq textField "categoryId"
    case fromPathPiece (T.strip categoryIdRaw) of
        Just categoryId -> pure categoryId
        Nothing -> jsonError status400 "invalid_category" "categoryId is invalid"

normalizeRole :: Text -> Text
normalizeRole role
    | role == "admin" = "admin"
    | otherwise = "user"

hasInvalidAdSchedule :: Maybe Day -> Maybe Day -> Bool
hasInvalidAdSchedule (Just startDate) (Just endDate) = startDate > endDate
hasInvalidAdSchedule _ _ = False

adminUserValue :: Map.Map UserId Int -> Map.Map UserId Int -> Entity User -> Value
adminUserValue userPostCountMap userCommentCountMap (Entity userId user) =
    object
        [ "id" .= keyToInt userId
        , "ident" .= userIdent user
        , "role" .= userRole user
        , "name" .= userName user
        , "description" .= userDescription user
        , "countryCode" .= userCountryCode user
        , "state" .= userState user
        , "localRegionOnly" .= userLocalRegionOnly user
        , "postCount" .= Map.findWithDefault 0 userId userPostCountMap
        , "commentCount" .= Map.findWithDefault 0 userId userCommentCountMap
        ]

adminCompanyValue :: Map.Map UserId (Entity User) -> Map.Map CompanyGroupId CompanyGroup -> Entity Company -> Value
adminCompanyValue userMap categoryMap (Entity companyId company) =
    let mAuthor = Map.lookup (companyAuthor company) userMap
        mCategory = Map.lookup (companyCategory company) categoryMap
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
        , "description" .= companyDescription company
        , "author" .= maybe Null userRefValue mAuthor
        , "createdAt" .= companyCreatedAt company
        , "updatedAt" .= companyUpdatedAt company
        ]

adminCategoryValue
    :: Map.Map UserId (Entity User)
    -> Map.Map CompanyGroupId Int
    -> Map.Map CompanyGroupId Int
    -> Map.Map Text CompanyGroupId
    -> Map.Map Text Text
    -> Entity CompanyGroup
    -> Value
adminCategoryValue userMap companyCountMap childCountMap categoryIdByCode categoryNameByCode (Entity categoryId category) =
    object
        [ "id" .= keyToInt categoryId
        , "name" .= companyGroupName category
        , "description" .= companyGroupDescription category
        , "code" .= companyGroupCode category
        , "majorCode" .= companyGroupMajorCode category
        , "majorName" .= ((companyGroupMajorCode category >>= fmap companyMajorCategoryName . findCompanyMajorCategory) <|> (companyGroupMajorCode category >>= (`Map.lookup` categoryNameByCode)))
        , "parentCategoryId" .= fmap keyToInt (companyGroupMajorCode category >>= (`Map.lookup` categoryIdByCode))
        , "isMajor" .= isNothing (companyGroupMajorCode category)
        , "sortOrder" .= companyGroupSortOrder category
        , "isSystem" .= companyGroupIsSystem category
        , "companyCount" .= Map.findWithDefault 0 categoryId companyCountMap
        , "childCount" .= Map.findWithDefault 0 categoryId childCountMap
        , "author" .= maybe Null userRefValue (Map.lookup (companyGroupAuthor category) userMap)
        ]

parsePostedParentMajorCode :: Handler (Maybe Text)
parsePostedParentMajorCode = do
    mParentMajorCodeRaw <- runInputPost $ iopt textField "parentMajorCode"
    case normalizeOptionalText mParentMajorCodeRaw of
        Just majorCode -> pure (Just majorCode)
        Nothing -> do
            mParentCategoryIdRaw <- runInputPost $ iopt textField "parentCategoryId"
            case normalizeOptionalText mParentCategoryIdRaw of
                Nothing -> pure Nothing
                Just rawParentId ->
                    case fromPathPiece rawParentId of
                        Nothing -> jsonError status400 "invalid_parent_category" "Parent category is invalid."
                        Just parentCategoryId -> do
                            parentCategory <- requireDbEntity parentCategoryId "category_not_found" "Category not found."
                            pure (Just (companyGroupCode (entityVal parentCategory)))

validateParentMajorCode :: Maybe (Entity CompanyGroup) -> Maybe Text -> Handler ()
validateParentMajorCode mCurrentCategory Nothing = pure ()
validateParentMajorCode mCurrentCategory (Just parentMajorCode) = do
    when (maybe False ((== parentMajorCode) . companyGroupCode . entityVal) mCurrentCategory) $
        jsonError status400 "invalid_parent_category" "Category cannot be its own parent."
    mExistingParent <- runDB $ getBy $ UniqueCompanyGroupCode parentMajorCode
    case mExistingParent of
        Just (Entity parentCategoryId parentCategory) -> do
            when (maybe False ((== parentCategoryId) . entityKey) mCurrentCategory) $
                jsonError status400 "invalid_parent_category" "Category cannot be its own parent."
            when (isJust (companyGroupMajorCode parentCategory)) $
                jsonError status400 "invalid_parent_category" "Parent category must be a major category."
        Nothing ->
            when (isNothing (findCompanyMajorCategory parentMajorCode)) $
                jsonError status400 "invalid_parent_category" "Parent category is invalid."

adminAdValue :: Entity Ad -> Value
adminAdValue (Entity adId ad) =
    object
        [ "id" .= keyToInt adId
        , "title" .= adTitle ad
        , "body" .= adBody ad
        , "link" .= adLink ad
        , "isActive" .= adIsActive ad
        , "startDate" .= adStartDate ad
        , "endDate" .= adEndDate ad
        , "position" .= adPosition ad
        , "sortOrder" .= adSortOrder ad
        , "createdAt" .= adCreatedAt ad
        , "updatedAt" .= adUpdatedAt ad
        ]

adminSettingsValue :: SiteSettingMap -> Value
adminSettingsValue settingMap =
    object
        [ "values" .= settingMap
        , "groups" .= object
            [ "siteBasics" .= siteBasicsSettingKeys
            , "forum" .= forumSettingKeys
            , "upload" .= uploadSettingKeys
            , "moderation" .= moderationSettingKeys
            , "ads" .= adsSettingKeys
            , "features" .= featureSettingKeys
            ]
        ]

moderationFlagValue :: Map.Map UserId (Entity User) -> Map.Map PostId (Entity Post) -> Entity PostFlag -> Value
moderationFlagValue userMap postMap (Entity flagId row) =
    let mUser = Map.lookup (postFlagUser row) userMap
        mPost = Map.lookup (postFlagPost row) postMap
    in object
        [ "id" .= keyToInt flagId
        , "user" .= maybe Null userRefValue mUser
        , "postId" .= keyToInt (postFlagPost row)
        , "postTitle" .= maybe ("Unknown" :: Text) (postTitle . entityVal) mPost
        , "postPreview" .= maybe ("Unknown" :: Text) (buildPreview 160 . postContent . entityVal) mPost
        , "createdAt" .= postFlagCreatedAt row
        ]

moderationBlockValue :: Map.Map UserId (Entity User) -> Map.Map PostId (Entity Post) -> Entity PostBlock -> Value
moderationBlockValue userMap postMap (Entity blockId row) =
    let mUser = Map.lookup (postBlockUser row) userMap
        mPost = Map.lookup (postBlockPost row) postMap
    in object
        [ "id" .= keyToInt blockId
        , "user" .= maybe Null userRefValue mUser
        , "postId" .= keyToInt (postBlockPost row)
        , "postTitle" .= maybe ("Unknown" :: Text) (postTitle . entityVal) mPost
        , "postPreview" .= maybe ("Unknown" :: Text) (buildPreview 160 . postContent . entityVal) mPost
        , "createdAt" .= postBlockCreatedAt row
        ]

moderationLogValue :: Map.Map UserId (Entity User) -> Entity ModerationLog -> Value
moderationLogValue userMap (Entity _ row) =
    object
        [ "targetType" .= moderationLogTargetType row
        , "targetId" .= moderationLogTargetId row
        , "action" .= moderationLogAction row
        , "actor" .= maybe Null userRefValue (Map.lookup (moderationLogActor row) userMap)
        , "createdAt" .= moderationLogCreatedAt row
        , "postPath" .= moderationLogPostPath row
        ]

moderationLogPostId :: Entity ModerationLog -> Maybe PostId
moderationLogPostId (Entity _ row)
    | moderationLogTargetType row `elem` ["post-flag", "post-block"] =
        toSqlKey <$> (readMaybe (T.unpack (moderationLogTargetId row)) :: Maybe Int64)
    | otherwise = Nothing

moderationLogPostPath :: ModerationLog -> Maybe Text
moderationLogPostPath row = do
    postId <- parseModerationLogPostId row
    pure ("/post/" <> tshow (keyToInt postId))

parseModerationLogPostId :: ModerationLog -> Maybe PostId
parseModerationLogPostId row
    | moderationLogTargetType row `elem` ["post-flag", "post-block"] =
        toSqlKey <$> (readMaybe (T.unpack (moderationLogTargetId row)) :: Maybe Int64)
    | otherwise = Nothing

buildPreview :: Int -> Text -> Text
buildPreview n raw =
    let plain = stripTags raw
        trimmed = T.take n plain
    in if T.length plain > n then trimmed <> "…" else trimmed

stripTags :: Text -> Text
stripTags = T.pack . go False . T.unpack
  where
    go _ [] = []
    go True ('>':xs) = go False xs
    go True (_:xs) = go True xs
    go False ('<':xs) = go True xs
    go False (x:xs) = x : go False xs
