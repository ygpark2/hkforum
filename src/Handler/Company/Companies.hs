{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Handler.Company.Companies
    ( getCompaniesR
    , postCompaniesR
    , postCompanyCategoriesR
    ) where

import Company.Categories
import Company.Description (prepareCompanyDescription)
import Import
import SiteSettings
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (diffUTCTime)
import qualified Prelude as P
import Text.Blaze (preEscapedText)

getCompaniesR :: Handler Html
getCompaniesR = do
    req <- getRequest
    let mCsrfToken = reqToken req
    settingRows <- runDB $ selectList [] []
    let settingMap = siteSettingMapFromEntities settingRows
        globalLocalRegionFilterEnabled = siteSettingBool "local_region_filter_enabled" True settingMap
        mapsEnabled = siteSettingBool "maps_enabled" True settingMap
    mViewer <- maybeAuth
    let localRegionFilterEnabled = globalLocalRegionFilterEnabled && maybe False (userLocalRegionOnly . entityVal) mViewer
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
    mSelectedMajorParam <- lookupGetParam "major"
    mSelectedCategoryParam <- lookupGetParam "category"
    categories <- runDB $ selectList [CompanyGroupIsSystem ==. True] [Asc CompanyGroupSortOrder, Asc CompanyGroupName]
    let categoryMap = Map.fromList $ map (\ent@(Entity categoryId _) -> (categoryId, ent)) categories
        selectedCategoryId = mSelectedCategoryParam >>= fromPathPiece
        selectedCategory =
            selectedCategoryId >>= (`Map.lookup` categoryMap)
        selectedMajorCode =
            case mSelectedMajorParam >>= findCompanyMajorCategory of
                Just major -> Just (companyMajorCategoryCode major)
                Nothing ->
                    selectedCategory >>= companyGroupMajorCode . entityVal
        selectedMajor =
            selectedMajorCode >>= findCompanyMajorCategory
        visibleCategories =
            case selectedCategory of
                Just categoryEnt -> [categoryEnt]
                Nothing ->
                    case selectedMajorCode of
                        Just majorCode ->
                            filter
                                ((== Just majorCode) . companyGroupMajorCode . entityVal)
                                categories
                        Nothing -> categories
        visibleCategoryIds = map entityKey visibleCategories
    companies <-
        if P.null visibleCategoryIds || (localRegionFilterEnabled && isNothing mActiveLocalRegion)
            then pure []
            else do
                let baseFilters = [CompanyCategory <-. visibleCategoryIds]
                    regionFilters =
                        case (localRegionFilterEnabled, mActiveLocalRegion) of
                            (True, Just (countryCodeValue, stateValue)) ->
                                [ CompanyCountryCode ==. Just countryCodeValue
                                , CompanyState ==. Just stateValue
                                ]
                            _ -> []
                runDB $ selectList (baseFilters <> regionFilters) [Desc CompanyCreatedAt, Desc CompanyUpdatedAt, Asc CompanyName]
    now <- liftIO getCurrentTime
    let authorIds = L.nub $ map (companyAuthor . entityVal) companies
    users <-
        if P.null authorIds
            then pure []
            else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) users
        viewerId = entityKey <$> mViewer
        selectedCreateCategoryId =
            case selectedCategory of
                Just (Entity categoryId _) -> Just categoryId
                Nothing ->
                    case visibleCategories of
                        Entity categoryId _ : _ -> Just categoryId
                        [] -> Nothing
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        authorHandle uid = T.toLower $ T.filter (/= ' ') (authorName uid)
        categoryLabel category =
            companyGroupName category
        companyMajorName company =
            case Map.lookup (companyCategory company) categoryMap >>= companyGroupMajorCode . entityVal of
                Just majorCode ->
                    maybe "기타" companyMajorCategoryName (findCompanyMajorCategory majorCode)
                Nothing -> "기타"
        companyMinorLabel company =
            case Map.lookup (companyCategory company) categoryMap of
                Just (Entity _ category) -> categoryLabel category
                Nothing -> "미분류"
        relativeTime ts =
            let minutes = floor (diffUTCTime now ts / 60) :: Int
                hours = minutes `div` 60
                days = hours `div` 24
            in if minutes < 60 then tshow minutes <> " min ago"
               else if hours < 24 then tshow hours <> " hours ago"
               else if days < 30 then tshow days <> " days ago"
               else tshow $ formatTime defaultTimeLocale "%b %e, %Y" ts
        companyDescriptionHtml company = preEscapedText (companyDescription company)
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Company"
        $(widgetFile "company/companies")

postCompaniesR :: Handler Html
postCompaniesR = do
    userId <- requireAuthId
    user <- runDB $ get404 userId
    settingRows <- runDB $ selectList [] []
    let settingMap = siteSettingMapFromEntities settingRows
        blockedWords = siteSettingCsv "blocked_words" settingMap
    nameRaw <- runInputPost $ ireq textField "name"
    categoryIdRaw <- runInputPost $ ireq textField "categoryId"
    mWebsiteRaw <- runInputPost $ iopt textField "website"
    mSizeRaw <- runInputPost $ iopt textField "size"
    mLatitude <- runInputPost $ iopt doubleField "latitude"
    mLongitude <- runInputPost $ iopt doubleField "longitude"
    descriptionRaw <- runInputPost $ ireq textField "description"
    categoryId <-
        case fromPathPiece categoryIdRaw of
            Nothing -> invalidArgs ["categoryId is invalid"]
            Just cid -> pure cid
    category <- runDB $ get404 categoryId
    unless (companyGroupIsSystem category) $
        invalidArgs ["categoryId is invalid"]
    let name = T.strip nameRaw
        mWebsite = normalizeOptionalText mWebsiteRaw
        mSize = normalizeOptionalText mSizeRaw
    description <-
        case prepareCompanyDescription descriptionRaw of
            Left err -> invalidArgs [err]
            Right value -> pure value
    when (T.null name) $ invalidArgs ["name is required"]
    when (textContainsBlockedTerm blockedWords (name <> " " <> description)) $
        invalidArgs ["content contains blocked terms"]
    (mLatitudeValue, mLongitudeValue) <- requireCoordinatePair mLatitude mLongitude
    let (mCountryCodeValue, mStateValue) = userRegionFields user
    now <- liftIO getCurrentTime
    _ <- runDB $ insert Company
        { companyName = name
        , companyCategory = categoryId
        , companyWebsite = mWebsite
        , companySize = mSize
        , companyCountryCode = mCountryCodeValue
        , companyState = mStateValue
        , companyLatitude = mLatitudeValue
        , companyLongitude = mLongitudeValue
        , companyDescription = description
        , companyAuthor = userId
        , companyCreatedAt = now
        , companyUpdatedAt = now
        }
    setMessage "Company created."
    redirect CompaniesR

postCompanyCategoriesR :: Handler Html
postCompanyCategoriesR = do
    userId <- requireAuthId
    nameRaw <- runInputPost $ ireq textField "name"
    codeRaw <- runInputPost $ ireq textField "code"
    mDescriptionRaw <- runInputPost $ iopt textField "description"
    let name = T.strip nameRaw
        code = T.strip codeRaw
        mDescription = normalizeOptionalText mDescriptionRaw
    when (T.null name) $ invalidArgs ["name is required"]
    when (T.null code) $ invalidArgs ["code is required"]
    now <- liftIO getCurrentTime
    inserted <- runDB $ insertBy CompanyGroup
        { companyGroupName = name
        , companyGroupDescription = mDescription
        , companyGroupAuthor = userId
        , companyGroupCreatedAt = now
        , companyGroupCode = code
        , companyGroupMajorCode = Nothing
        , companyGroupSortOrder = 0
        , companyGroupIsSystem = False
        }
    case inserted of
        Left _ -> setMessage "Category code already exists."
        Right _ -> setMessage "Company category created."
    redirect CompaniesR

normalizeOptionalText :: Maybe Text -> Maybe Text
normalizeOptionalText Nothing = Nothing
normalizeOptionalText (Just raw) =
    let trimmed = T.strip raw
    in if T.null trimmed then Nothing else Just trimmed

normalizeRegionField :: Maybe Text -> Maybe Text
normalizeRegionField = normalizeOptionalText . fmap T.strip

userRegionFields :: User -> (Maybe Text, Maybe Text)
userRegionFields user = (normalizeRegionField (userCountryCode user), normalizeRegionField (userState user))

userRegionPair :: User -> Maybe (Text, Text)
userRegionPair user =
    case userRegionFields user of
        (Just countryCodeValue, Just stateValue) -> Just (countryCodeValue, stateValue)
        _ -> Nothing

requireCoordinatePair :: Maybe Double -> Maybe Double -> Handler (Maybe Double, Maybe Double)
requireCoordinatePair Nothing Nothing = pure (Nothing, Nothing)
requireCoordinatePair (Just lat) (Just lng) = pure (Just lat, Just lng)
requireCoordinatePair _ _ = invalidArgs ["latitude and longitude must be provided together"]
