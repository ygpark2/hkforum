{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.RealEstate
    ( getApiRealEstateListingsR
    , getApiRealEstateDashboardR
    , postApiRealEstateListingsR
    , getApiRealEstateListingR
    , patchApiRealEstateListingR
    , deleteApiRealEstateListingR
    , postApiRealEstateApproveR
    , postApiRealEstateRejectR
    , postApiRealEstateRepublishR
    , getApiRealEstateAgentProfileR
    , putApiRealEstateAgentProfileR
    , postApiRealEstateImagesR
    , patchApiRealEstateImageR
    , deleteApiRealEstateImageR
    , getApiRealEstateInquiriesR
    , postApiRealEstateInquiriesR
    , patchApiRealEstateInquiryR
    , postApiRealEstateReportsR
    , patchApiRealEstateReportR
    ) where

import Data.Aeson (withObject, (.:?), (.!=))
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (addUTCTime)
import Handler.Api.Common
import Import
import SiteSettings
import Storage (storageUrl)
import qualified Prelude as P

data RealEstatePayload = RealEstatePayload
    { realEstatePayloadTitle :: Text
    , realEstatePayloadListingType :: Text
    , realEstatePayloadPropertyType :: Text
    , realEstatePayloadCountryCode :: Maybe Text
    , realEstatePayloadState :: Maybe Text
    , realEstatePayloadCity :: Maybe Text
    , realEstatePayloadSuburb :: Maybe Text
    , realEstatePayloadAddressText :: Maybe Text
    , realEstatePayloadLatitude :: Maybe Double
    , realEstatePayloadLongitude :: Maybe Double
    , realEstatePayloadCurrency :: Maybe Text
    , realEstatePayloadPrice :: Maybe Int
    , realEstatePayloadPricePeriod :: Maybe Text
    , realEstatePayloadBondAmount :: Maybe Int
    , realEstatePayloadDepositAmount :: Maybe Int
    , realEstatePayloadBedrooms :: Maybe Int
    , realEstatePayloadBathrooms :: Maybe Int
    , realEstatePayloadParkingSpaces :: Maybe Int
    , realEstatePayloadFloorAreaSqm :: Maybe Double
    , realEstatePayloadLandAreaSqm :: Maybe Double
    , realEstatePayloadAvailableFrom :: Maybe Day
    , realEstatePayloadLeaseTerm :: Maybe Text
    , realEstatePayloadPetsAllowed :: Maybe Bool
    , realEstatePayloadFurnished :: Maybe Bool
    , realEstatePayloadBillsIncluded :: Maybe Bool
    , realEstatePayloadContent :: Text
    , realEstatePayloadContactName :: Maybe Text
    , realEstatePayloadContactEmail :: Maybe Text
    , realEstatePayloadContactPhone :: Maybe Text
    , realEstatePayloadCompanyId :: Maybe CompanyId
    , realEstatePayloadFeatures :: [Text]
    }

instance FromJSON RealEstatePayload where
    parseJSON = withObject "RealEstatePayload" $ \o ->
        RealEstatePayload
            <$> o .: "title"
            <*> o .:? "listingType" .!= "rent"
            <*> o .:? "propertyType" .!= "apartment"
            <*> o .:? "countryCode"
            <*> o .:? "state"
            <*> o .:? "city"
            <*> o .:? "suburb"
            <*> o .:? "addressText"
            <*> o .:? "latitude"
            <*> o .:? "longitude"
            <*> o .:? "currency"
            <*> o .:? "price"
            <*> o .:? "pricePeriod"
            <*> o .:? "bondAmount"
            <*> o .:? "depositAmount"
            <*> o .:? "bedrooms"
            <*> o .:? "bathrooms"
            <*> o .:? "parkingSpaces"
            <*> o .:? "floorAreaSqm"
            <*> o .:? "landAreaSqm"
            <*> o .:? "availableFrom"
            <*> o .:? "leaseTerm"
            <*> o .:? "petsAllowed"
            <*> o .:? "furnished"
            <*> o .:? "billsIncluded"
            <*> o .: "content"
            <*> o .:? "contactName"
            <*> o .:? "contactEmail"
            <*> o .:? "contactPhone"
            <*> o .:? "companyId"
            <*> o .:? "features" .!= []

data RealEstateInquiryPayload = RealEstateInquiryPayload
    { realEstateInquiryPayloadName :: Text
    , realEstateInquiryPayloadEmail :: Text
    , realEstateInquiryPayloadPhone :: Maybe Text
    , realEstateInquiryPayloadMessage :: Text
    }

instance FromJSON RealEstateInquiryPayload where
    parseJSON = withObject "RealEstateInquiryPayload" $ \o ->
        RealEstateInquiryPayload
            <$> o .: "name"
            <*> o .: "email"
            <*> o .:? "phone"
            <*> o .: "message"

data UpdateRealEstateInquiryPayload = UpdateRealEstateInquiryPayload
    { updateRealEstateInquiryStatus :: Text
    }

instance FromJSON UpdateRealEstateInquiryPayload where
    parseJSON = withObject "UpdateRealEstateInquiryPayload" $ \o ->
        UpdateRealEstateInquiryPayload <$> o .: "status"

data RealEstateImagePayload = RealEstateImagePayload
    { realEstateImagePayloadFileKey :: Maybe Text
    , realEstateImagePayloadCaption :: Maybe Text
    , realEstateImagePayloadSortOrder :: Maybe Int
    }

instance FromJSON RealEstateImagePayload where
    parseJSON = withObject "RealEstateImagePayload" $ \o ->
        RealEstateImagePayload
            <$> o .:? "fileKey"
            <*> o .:? "caption"
            <*> o .:? "sortOrder"

data RealEstateReportPayload = RealEstateReportPayload
    { realEstateReportPayloadName :: Maybe Text
    , realEstateReportPayloadEmail :: Maybe Text
    , realEstateReportPayloadReason :: Text
    , realEstateReportPayloadDetails :: Maybe Text
    }

instance FromJSON RealEstateReportPayload where
    parseJSON = withObject "RealEstateReportPayload" $ \o ->
        RealEstateReportPayload
            <$> o .:? "name"
            <*> o .:? "email"
            <*> o .: "reason"
            <*> o .:? "details"

data UpdateRealEstateReportPayload = UpdateRealEstateReportPayload
    { updateRealEstateReportStatus :: Text
    }

instance FromJSON UpdateRealEstateReportPayload where
    parseJSON = withObject "UpdateRealEstateReportPayload" $ \o ->
        UpdateRealEstateReportPayload <$> o .: "status"

data RealEstateAgentProfilePayload = RealEstateAgentProfilePayload
    { realEstateAgentProfilePayloadAgencyName :: Text
    , realEstateAgentProfilePayloadLicenseNumber :: Maybe Text
    , realEstateAgentProfilePayloadWebsite :: Maybe Text
    , realEstateAgentProfilePayloadPhone :: Maybe Text
    , realEstateAgentProfilePayloadEmail :: Maybe Text
    }

instance FromJSON RealEstateAgentProfilePayload where
    parseJSON = withObject "RealEstateAgentProfilePayload" $ \o ->
        RealEstateAgentProfilePayload
            <$> o .: "agencyName"
            <*> o .:? "licenseNumber"
            <*> o .:? "website"
            <*> o .:? "phone"
            <*> o .:? "email"

getApiRealEstateListingsR :: Handler Value
getApiRealEstateListingsR = do
    ensureApiReadAllowed
    autoExpireRealEstateListings
    (page, size, offset) <- paginationParams
    mViewer <- maybeApiAuth
    listingTypeFilter <- lookupOptionalAllowedQueryParam "invalid_listing_type" "listingType" listingTypeOptions
    propertyTypeFilter <- lookupOptionalAllowedQueryParam "invalid_property_type" "propertyType" propertyTypeOptions
    countryCodeFilter <- lookupOptionalTextQueryParam "countryCode"
    suburbFilter <- lookupOptionalTextQueryParam "suburb"
    searchFilter <- lookupOptionalTextQueryParam "q"
    sortValue <- lookupOptionalAllowedQueryParam "invalid_sort" "sort" realEstateSortOptions
    minPrice <- lookupOptionalIntQueryParam "minPrice"
    maxPrice <- lookupOptionalIntQueryParam "maxPrice"
    bedrooms <- lookupOptionalIntQueryParam "bedrooms"
    queryLatitude <- lookupOptionalDoubleQueryParam "latitude"
    queryLongitude <- lookupOptionalDoubleQueryParam "longitude"
    queryRadius <- lookupOptionalDoubleQueryParam "radiusKm"
    (mLatitude, mLongitude) <- requireCoordinatePairJson queryLatitude queryLongitude
    radiusKm <- validateRadiusQuery mLatitude queryRadius
    let mRadiusCenter = (,) <$> mLatitude <*> mLongitude
        boundingFilters =
            case (mRadiusCenter, radiusKm) of
                (Just (lat, lng), Just radius) ->
                    let (minLat, maxLat, minLng, maxLng) = boundingBox lat lng radius
                    in [ RealEstateListingLatitude !=. Nothing
                       , RealEstateListingLongitude !=. Nothing
                       , RealEstateListingLatitude >=. Just minLat
                       , RealEstateListingLatitude <=. Just maxLat
                       , RealEstateListingLongitude >=. Just minLng
                       , RealEstateListingLongitude <=. Just maxLng
                       ]
                _ -> []
        regionFilters =
            case activeRegionFilter mViewer of
                RegionFilterUnavailable -> []
                RegionFilterDisabled -> []
                RegionFilterEnabled countryCodeValue stateValue ->
                    [ RealEstateListingCountryCode ==. Just countryCodeValue
                    , RealEstateListingState ==. Just stateValue
                    ]
        filters =
            regionFilters
                <> [RealEstateListingStatus ==. "published"]
                <> maybe [] (\value -> [RealEstateListingListingType ==. value]) listingTypeFilter
                <> maybe [] (\value -> [RealEstateListingPropertyType ==. value]) propertyTypeFilter
                <> maybe [] (\value -> [RealEstateListingCountryCode ==. Just value]) countryCodeFilter
                <> maybe [] (\value -> [RealEstateListingSuburb ==. Just value]) suburbFilter
                <> maybe [] (\value -> [RealEstateListingPrice >=. Just value]) minPrice
                <> maybe [] (\value -> [RealEstateListingPrice <=. Just value]) maxPrice
                <> maybe [] (\value -> [RealEstateListingBedrooms >=. Just value]) bedrooms
                <> boundingFilters
        orderOptions =
            case sortValue of
                Just "price_asc" -> [Asc RealEstateListingPrice, Desc RealEstateListingCreatedAt]
                Just "price_desc" -> [Desc RealEstateListingPrice, Desc RealEstateListingCreatedAt]
                _ -> [Desc RealEstateListingCreatedAt]
        matchesSearch row =
            case fmap T.toLower searchFilter of
                Nothing -> True
                Just needle ->
                    let listing = entityVal row
                        haystack = T.toLower $ T.intercalate " "
                            [ realEstateListingTitle listing
                            , fromMaybe "" (realEstateListingCity listing)
                            , fromMaybe "" (realEstateListingSuburb listing)
                            , realEstateListingContent listing
                            ]
                    in needle `T.isInfixOf` haystack
        applySearchAndSort rows =
            let searched = filter matchesSearch rows
            in case (sortValue, mRadiusCenter) of
                (Just "distance", Just center) -> L.sortOn (fromMaybe 999999 . listingDistanceFrom (Just center) . entityVal) searched
                _ -> searched
    listings <- case activeRegionFilter mViewer of
        RegionFilterUnavailable -> pure []
        _ ->
            case (mRadiusCenter, radiusKm) of
                (Just center, Just radius) -> do
                    candidates <- runDB $ selectList filters orderOptions
                    pure $
                        P.take (size + 1) $
                            P.drop offset $
                                applySearchAndSort (filter (listingWithinRadius center radius) candidates)
                _ | isJust searchFilter ->
                    P.take (size + 1) . P.drop offset . applySearchAndSort <$> runDB (selectList filters orderOptions)
                _ -> runDB $ selectList filters (orderOptions <> [OffsetBy offset, LimitTo (size + 1)])
    let hasNext = P.length listings > size
        pageRows = P.take size listings
    (featureMap, imageMap, inquiryCountMap) <- loadRealEstateMeta (map entityKey pageRows)
    returnJson $
        object
            [ "items" .= map (realEstateListingValue mRadiusCenter featureMap imageMap inquiryCountMap) pageRows
            , "page" .= page
            , "size" .= size
            , "hasNext" .= hasNext
            ]

postApiRealEstateListingsR :: Handler Value
postApiRealEstateListingsR = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    enforceRealEstateListingQuota viewerId (entityVal viewer)
    payload <- requireCheckJsonBody :: Handler RealEstatePayload
    let initialStatus = if userRole (entityVal viewer) == ("admin" :: Text) then "published" else "pending"
    listing <- validateRealEstatePayload initialStatus payload
    now <- liftIO getCurrentTime
    mExpiresAt <- defaultRealEstateExpiresAt initialStatus now
    listingId <- runDB $ do
        insertedId <- insert ((listing viewerId now) { realEstateListingExpiresAt = mExpiresAt })
        replaceRealEstateFeatures insertedId (normalizeFeatureList (realEstatePayloadFeatures payload))
        pure insertedId
    created <- requireDbEntity listingId "listing_not_found" "Listing not found."
    (featureMap, imageMap, inquiryCountMap) <- loadRealEstateMeta [listingId]
    sendResponseStatus status201 $
        object ["listing" .= realEstateListingValue Nothing featureMap imageMap inquiryCountMap created]

getApiRealEstateDashboardR :: Handler Value
getApiRealEstateDashboardR = do
    autoExpireRealEstateListings
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    ensureRealEstateAgentAccess viewerId (entityVal viewer)
    now <- liftIO getCurrentTime
    let isAdmin = userRole (entityVal viewer) == ("admin" :: Text)
        filters = if isAdmin then [] else [RealEstateListingAuthor ==. viewerId]
    listings <- runDB $ selectList filters [Desc RealEstateListingCreatedAt, LimitTo 100]
    reports <- if isAdmin then runDB $ selectList [] [Desc RealEstateReportCreatedAt, LimitTo 100] else pure []
    agentProfiles <- runDB $ selectList (if isAdmin then [] else [RealEstateAgentProfileUser ==. viewerId]) [Desc RealEstateAgentProfileUpdatedAt, LimitTo 100]
    (featureMap, imageMap, inquiryCountMap) <- loadRealEstateMeta (map entityKey listings)
    quota <- realEstateQuotaValue viewerId (entityVal viewer) now
    returnJson $
        object
            [ "quota" .= quota
            , "listings" .= map (realEstateListingValue Nothing featureMap imageMap inquiryCountMap) listings
            , "reports" .= map realEstateReportValue reports
            , "agentProfiles" .= map realEstateAgentProfileValue agentProfiles
            , "plans" .= map realEstatePlanValue realEstatePlans
            ]

getApiRealEstateListingR :: RealEstateListingId -> Handler Value
getApiRealEstateListingR listingId = do
    ensureApiReadAllowed
    autoExpireRealEstateListings
    mViewer <- maybeApiAuth
    listing <- requireDbEntity listingId "listing_not_found" "Listing not found."
    unless (realEstateListingStatus (entityVal listing) == ("published" :: Text) || maybe False (\(Entity viewerId viewer) -> realEstateListingAuthor (entityVal listing) == viewerId || userRole viewer == ("admin" :: Text)) mViewer) $
        jsonError status404 "listing_not_found" "Listing not found."
    (featureMap, imageMap, inquiryCountMap) <- loadRealEstateMeta [listingId]
    returnJson $ object ["listing" .= realEstateListingValue Nothing featureMap imageMap inquiryCountMap listing]

getApiRealEstateAgentProfileR :: Handler Value
getApiRealEstateAgentProfileR = do
    viewerId <- requireApiAuthId
    profile <- runDB $ getBy (UniqueRealEstateAgentProfile viewerId)
    returnJson $ object ["profile" .= maybe Null realEstateAgentProfileValue profile]

putApiRealEstateAgentProfileR :: Handler Value
putApiRealEstateAgentProfileR = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    ensureRealEstateAgentAccess viewerId (entityVal viewer)
    payload <- requireCheckJsonBody :: Handler RealEstateAgentProfilePayload
    now <- liftIO getCurrentTime
    let agencyName = T.strip (realEstateAgentProfilePayloadAgencyName payload)
        licenseNumber = normalizeOptionalText (realEstateAgentProfilePayloadLicenseNumber payload)
        website = normalizeOptionalText (realEstateAgentProfilePayloadWebsite payload)
        phone = normalizeOptionalText (realEstateAgentProfilePayloadPhone payload)
        email = normalizeOptionalText (realEstateAgentProfilePayloadEmail payload)
    when (T.null agencyName) $
        jsonError status400 "invalid_agency_name" "agencyName is required."
    mExisting <- runDB $ getBy (UniqueRealEstateAgentProfile viewerId)
    profileId <- runDB $
        case mExisting of
            Nothing -> insert RealEstateAgentProfile
                { realEstateAgentProfileUser = viewerId
                , realEstateAgentProfileAgencyName = agencyName
                , realEstateAgentProfileLicenseNumber = licenseNumber
                , realEstateAgentProfileWebsite = website
                , realEstateAgentProfilePhone = phone
                , realEstateAgentProfileEmail = email
                , realEstateAgentProfileVerified = False
                , realEstateAgentProfileCreatedAt = now
                , realEstateAgentProfileUpdatedAt = now
                }
            Just (Entity profileId _) -> do
                update profileId
                    [ RealEstateAgentProfileAgencyName =. agencyName
                    , RealEstateAgentProfileLicenseNumber =. licenseNumber
                    , RealEstateAgentProfileWebsite =. website
                    , RealEstateAgentProfilePhone =. phone
                    , RealEstateAgentProfileEmail =. email
                    , RealEstateAgentProfileUpdatedAt =. now
                    ]
                pure profileId
    profile <- requireDbEntity profileId "profile_not_found" "Profile not found."
    returnJson $ object ["profile" .= realEstateAgentProfileValue profile]

patchApiRealEstateListingR :: RealEstateListingId -> Handler Value
patchApiRealEstateListingR listingId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    listing <- requireDbEntity listingId "listing_not_found" "Listing not found."
    requireListingManager viewerId (entityVal viewer) (entityVal listing)
    payload <- requireCheckJsonBody :: Handler RealEstatePayload
    listingBuilder <- validateRealEstatePayload (realEstateListingStatus (entityVal listing)) payload
    now <- liftIO getCurrentTime
    let next = listingBuilder (realEstateListingAuthor (entityVal listing)) now
    runDB $ do
        replace listingId next
        replaceRealEstateFeatures listingId (normalizeFeatureList (realEstatePayloadFeatures payload))
    updated <- requireDbEntity listingId "listing_not_found" "Listing not found."
    (featureMap, imageMap, inquiryCountMap) <- loadRealEstateMeta [listingId]
    returnJson $ object ["listing" .= realEstateListingValue Nothing featureMap imageMap inquiryCountMap updated]

postApiRealEstateApproveR :: RealEstateListingId -> Handler Value
postApiRealEstateApproveR listingId =
    updateRealEstateApprovalStatus listingId "published"

postApiRealEstateRejectR :: RealEstateListingId -> Handler Value
postApiRealEstateRejectR listingId =
    updateRealEstateApprovalStatus listingId "rejected"

postApiRealEstateRepublishR :: RealEstateListingId -> Handler Value
postApiRealEstateRepublishR listingId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    listing <- requireDbEntity listingId "listing_not_found" "Listing not found."
    requireListingManager viewerId (entityVal viewer) (entityVal listing)
    let nextStatus = if userRole (entityVal viewer) == ("admin" :: Text) then "published" else "pending"
    now <- liftIO getCurrentTime
    mExpiresAt <- defaultRealEstateExpiresAt nextStatus now
    runDB $ update listingId
        [ RealEstateListingStatus =. nextStatus
        , RealEstateListingPublishedAt =. if nextStatus == "published" then Just now else Nothing
        , RealEstateListingExpiresAt =. mExpiresAt
        , RealEstateListingUpdatedAt =. now
        ]
    updated <- requireDbEntity listingId "listing_not_found" "Listing not found."
    (featureMap, imageMap, inquiryCountMap) <- loadRealEstateMeta [listingId]
    returnJson $ object ["listing" .= realEstateListingValue Nothing featureMap imageMap inquiryCountMap updated]

deleteApiRealEstateListingR :: RealEstateListingId -> Handler Value
deleteApiRealEstateListingR listingId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    listing <- requireDbEntity listingId "listing_not_found" "Listing not found."
    requireListingManager viewerId (entityVal viewer) (entityVal listing)
    runDB $ do
        deleteWhere [RealEstateFeatureListing ==. listingId]
        deleteWhere [RealEstateImageListing ==. listingId]
        deleteWhere [RealEstateInquiryListing ==. listingId]
        deleteWhere [RealEstateReportListing ==. listingId]
        delete listingId
    returnJson $ object ["message" .= ("Listing deleted." :: Text)]

updateRealEstateApprovalStatus :: RealEstateListingId -> Text -> Handler Value
updateRealEstateApprovalStatus listingId nextStatus = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    unless (userRole (entityVal viewer) == ("admin" :: Text)) $
        jsonError status403 "admin_required" "Admin access is required."
    _ <- requireDbEntity listingId "listing_not_found" "Listing not found."
    now <- liftIO getCurrentTime
    mExpiresAt <- defaultRealEstateExpiresAt nextStatus now
    let publishedAtUpdate =
            if nextStatus == "published"
                then [RealEstateListingPublishedAt =. Just now]
                else []
    runDB $ update listingId $
        [ RealEstateListingStatus =. nextStatus
        , RealEstateListingExpiresAt =. mExpiresAt
        , RealEstateListingUpdatedAt =. now
        ]
        <> publishedAtUpdate
    updated <- requireDbEntity listingId "listing_not_found" "Listing not found."
    (featureMap, imageMap, inquiryCountMap) <- loadRealEstateMeta [listingId]
    returnJson $ object ["listing" .= realEstateListingValue Nothing featureMap imageMap inquiryCountMap updated]

postApiRealEstateImagesR :: RealEstateListingId -> Handler Value
postApiRealEstateImagesR listingId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    listing <- requireDbEntity listingId "listing_not_found" "Listing not found."
    requireListingManager viewerId (entityVal viewer) (entityVal listing)
    payload <- requireCheckJsonBody :: Handler RealEstateImagePayload
    let fileKey = T.strip (fromMaybe "" (realEstateImagePayloadFileKey payload))
        caption = normalizeOptionalText (realEstateImagePayloadCaption payload)
        sortOrder = fromMaybe 0 (realEstateImagePayloadSortOrder payload)
    when (T.null fileKey) $
        jsonError status400 "invalid_file_key" "fileKey is required."
    when (sortOrder < 0) $
        jsonError status400 "invalid_sort_order" "sortOrder must be zero or greater."
    now <- liftIO getCurrentTime
    imageId <- runDB $ insert RealEstateImage
        { realEstateImageListing = listingId
        , realEstateImageFileKey = fileKey
        , realEstateImageCaption = caption
        , realEstateImageSortOrder = sortOrder
        , realEstateImageCreatedAt = now
        }
    image <- requireDbEntity imageId "image_not_found" "Image not found."
    value <- realEstateImageValue image
    sendResponseStatus status201 $ object ["image" .= value]

patchApiRealEstateImageR :: RealEstateListingId -> RealEstateImageId -> Handler Value
patchApiRealEstateImageR listingId imageId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    listing <- requireDbEntity listingId "listing_not_found" "Listing not found."
    requireListingManager viewerId (entityVal viewer) (entityVal listing)
    image <- requireDbEntity imageId "image_not_found" "Image not found."
    when (realEstateImageListing (entityVal image) /= listingId) $
        jsonError status404 "image_not_found" "Image not found."
    payload <- requireCheckJsonBody :: Handler RealEstateImagePayload
    let caption = normalizeOptionalText (realEstateImagePayloadCaption payload)
        sortOrder = fromMaybe (realEstateImageSortOrder (entityVal image)) (realEstateImagePayloadSortOrder payload)
    when (sortOrder < 0) $
        jsonError status400 "invalid_sort_order" "sortOrder must be zero or greater."
    runDB $ update imageId [RealEstateImageCaption =. caption, RealEstateImageSortOrder =. sortOrder]
    updated <- requireDbEntity imageId "image_not_found" "Image not found."
    value <- realEstateImageValue updated
    returnJson $ object ["image" .= value]

deleteApiRealEstateImageR :: RealEstateListingId -> RealEstateImageId -> Handler Value
deleteApiRealEstateImageR listingId imageId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    listing <- requireDbEntity listingId "listing_not_found" "Listing not found."
    requireListingManager viewerId (entityVal viewer) (entityVal listing)
    image <- requireDbEntity imageId "image_not_found" "Image not found."
    when (realEstateImageListing (entityVal image) /= listingId) $
        jsonError status404 "image_not_found" "Image not found."
    runDB $ delete imageId
    returnJson $ object ["message" .= ("Image deleted." :: Text)]

getApiRealEstateInquiriesR :: RealEstateListingId -> Handler Value
getApiRealEstateInquiriesR listingId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    listing <- requireDbEntity listingId "listing_not_found" "Listing not found."
    requireListingManager viewerId (entityVal viewer) (entityVal listing)
    rows <- runDB $ selectList [RealEstateInquiryListing ==. listingId] [Desc RealEstateInquiryCreatedAt]
    returnJson $ object ["items" .= map realEstateInquiryValue rows]

postApiRealEstateInquiriesR :: RealEstateListingId -> Handler Value
postApiRealEstateInquiriesR listingId = do
    mViewerId <- maybeApiAuthId
    _ <- requireDbEntity listingId "listing_not_found" "Listing not found."
    payload <- requireCheckJsonBody :: Handler RealEstateInquiryPayload
    let name = T.strip (realEstateInquiryPayloadName payload)
        email = T.strip (realEstateInquiryPayloadEmail payload)
        message = T.strip (realEstateInquiryPayloadMessage payload)
        phone = normalizeOptionalText (realEstateInquiryPayloadPhone payload)
    when (T.null name) $ jsonError status400 "invalid_name" "Name is required."
    when (T.null email) $ jsonError status400 "invalid_email" "Email is required."
    when (T.null message) $ jsonError status400 "invalid_message" "Message is required."
    now <- liftIO getCurrentTime
    enforceInquiryRateLimit listingId email now
    inquiryId <- runDB $ insert RealEstateInquiry
        { realEstateInquiryListing = listingId
        , realEstateInquirySender = mViewerId
        , realEstateInquiryName = name
        , realEstateInquiryEmail = email
        , realEstateInquiryPhone = phone
        , realEstateInquiryMessage = message
        , realEstateInquiryStatus = "new"
        , realEstateInquiryCreatedAt = now
        , realEstateInquiryUpdatedAt = now
        }
    inquiry <- requireDbEntity inquiryId "inquiry_not_found" "Inquiry not found."
    sendResponseStatus status201 $ object ["inquiry" .= realEstateInquiryValue inquiry]

patchApiRealEstateInquiryR :: RealEstateListingId -> RealEstateInquiryId -> Handler Value
patchApiRealEstateInquiryR listingId inquiryId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    listing <- requireDbEntity listingId "listing_not_found" "Listing not found."
    requireListingManager viewerId (entityVal viewer) (entityVal listing)
    inquiry <- requireDbEntity inquiryId "inquiry_not_found" "Inquiry not found."
    when (realEstateInquiryListing (entityVal inquiry) /= listingId) $
        jsonError status404 "inquiry_not_found" "Inquiry not found."
    payload <- requireCheckJsonBody :: Handler UpdateRealEstateInquiryPayload
    statusValue <- requireAllowedOption "invalid_inquiry_status" "status" inquiryStatusOptions (updateRealEstateInquiryStatus payload)
    now <- liftIO getCurrentTime
    runDB $ update inquiryId [RealEstateInquiryStatus =. statusValue, RealEstateInquiryUpdatedAt =. now]
    updated <- requireDbEntity inquiryId "inquiry_not_found" "Inquiry not found."
    returnJson $ object ["inquiry" .= realEstateInquiryValue updated]

postApiRealEstateReportsR :: RealEstateListingId -> Handler Value
postApiRealEstateReportsR listingId = do
    mViewerId <- maybeApiAuthId
    _ <- requireDbEntity listingId "listing_not_found" "Listing not found."
    payload <- requireCheckJsonBody :: Handler RealEstateReportPayload
    now <- liftIO getCurrentTime
    let name = normalizeOptionalText (realEstateReportPayloadName payload)
        email = normalizeOptionalText (realEstateReportPayloadEmail payload)
        reason = T.toLower $ T.strip (realEstateReportPayloadReason payload)
        details = normalizeOptionalText (realEstateReportPayloadDetails payload)
    unless (reason `P.elem` realEstateReportReasonOptions) $
        jsonError status400 "invalid_reason" "reason is invalid."
    reportId <- runDB $ insert RealEstateReport
        { realEstateReportListing = listingId
        , realEstateReportReporter = mViewerId
        , realEstateReportName = name
        , realEstateReportEmail = email
        , realEstateReportReason = reason
        , realEstateReportDetails = details
        , realEstateReportStatus = "new"
        , realEstateReportCreatedAt = now
        , realEstateReportUpdatedAt = now
        }
    report <- requireDbEntity reportId "report_not_found" "Report not found."
    sendResponseStatus status201 $ object ["report" .= realEstateReportValue report]

patchApiRealEstateReportR :: RealEstateReportId -> Handler Value
patchApiRealEstateReportR reportId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    unless (userRole (entityVal viewer) == ("admin" :: Text)) $
        jsonError status403 "admin_required" "Admin access is required."
    report <- requireDbEntity reportId "report_not_found" "Report not found."
    payload <- requireCheckJsonBody :: Handler UpdateRealEstateReportPayload
    statusValue <- requireAllowedOption "invalid_report_status" "status" realEstateReportStatusOptions (updateRealEstateReportStatus payload)
    now <- liftIO getCurrentTime
    runDB $ update (entityKey report) [RealEstateReportStatus =. statusValue, RealEstateReportUpdatedAt =. now]
    updated <- requireDbEntity reportId "report_not_found" "Report not found."
    returnJson $ object ["report" .= realEstateReportValue updated]

validateRealEstatePayload :: Text -> RealEstatePayload -> Handler (UserId -> UTCTime -> RealEstateListing)
validateRealEstatePayload statusValue payload = do
    let title = T.strip (realEstatePayloadTitle payload)
        content = T.strip (realEstatePayloadContent payload)
    listingType <- requireAllowedOption "invalid_listing_type" "listingType" listingTypeOptions (realEstatePayloadListingType payload)
    propertyType <- requireAllowedOption "invalid_property_type" "propertyType" propertyTypeOptions (realEstatePayloadPropertyType payload)
    pricePeriod <- requireOptionalAllowedOption "invalid_price_period" "pricePeriod" pricePeriodOptions (realEstatePayloadPricePeriod payload)
    validateNonNegative "price" (realEstatePayloadPrice payload)
    validateNonNegative "bondAmount" (realEstatePayloadBondAmount payload)
    validateNonNegative "depositAmount" (realEstatePayloadDepositAmount payload)
    validateNonNegative "bedrooms" (realEstatePayloadBedrooms payload)
    validateNonNegative "bathrooms" (realEstatePayloadBathrooms payload)
    validateNonNegative "parkingSpaces" (realEstatePayloadParkingSpaces payload)
    when (T.null title) $ jsonError status400 "invalid_title" "Title is required."
    when (T.null content) $ jsonError status400 "invalid_content" "Content is required."
    forM_ (realEstatePayloadCompanyId payload) $ \companyId ->
        void $ requireDbEntity companyId "company_not_found" "Company not found."
    (latitude, longitude) <- requireCoordinatePairJson (realEstatePayloadLatitude payload) (realEstatePayloadLongitude payload)
    pure $ \authorId now -> RealEstateListing
        { realEstateListingTitle = title
        , realEstateListingListingType = listingType
        , realEstateListingPropertyType = propertyType
        , realEstateListingStatus = statusValue
        , realEstateListingCountryCode = normalizeOptionalText (fmap T.toUpper (realEstatePayloadCountryCode payload))
        , realEstateListingState = normalizeOptionalText (realEstatePayloadState payload)
        , realEstateListingCity = normalizeOptionalText (realEstatePayloadCity payload)
        , realEstateListingSuburb = normalizeOptionalText (realEstatePayloadSuburb payload)
        , realEstateListingAddressText = normalizeOptionalText (realEstatePayloadAddressText payload)
        , realEstateListingLatitude = latitude
        , realEstateListingLongitude = longitude
        , realEstateListingCurrency = normalizeOptionalText (fmap T.toUpper (realEstatePayloadCurrency payload))
        , realEstateListingPrice = realEstatePayloadPrice payload
        , realEstateListingPricePeriod = pricePeriod
        , realEstateListingBondAmount = realEstatePayloadBondAmount payload
        , realEstateListingDepositAmount = realEstatePayloadDepositAmount payload
        , realEstateListingBedrooms = realEstatePayloadBedrooms payload
        , realEstateListingBathrooms = realEstatePayloadBathrooms payload
        , realEstateListingParkingSpaces = realEstatePayloadParkingSpaces payload
        , realEstateListingFloorAreaSqm = realEstatePayloadFloorAreaSqm payload
        , realEstateListingLandAreaSqm = realEstatePayloadLandAreaSqm payload
        , realEstateListingAvailableFrom = realEstatePayloadAvailableFrom payload
        , realEstateListingLeaseTerm = normalizeOptionalText (realEstatePayloadLeaseTerm payload)
        , realEstateListingPetsAllowed = realEstatePayloadPetsAllowed payload
        , realEstateListingFurnished = realEstatePayloadFurnished payload
        , realEstateListingBillsIncluded = realEstatePayloadBillsIncluded payload
        , realEstateListingContent = content
        , realEstateListingContactName = normalizeOptionalText (realEstatePayloadContactName payload)
        , realEstateListingContactEmail = normalizeOptionalText (realEstatePayloadContactEmail payload)
        , realEstateListingContactPhone = normalizeOptionalText (realEstatePayloadContactPhone payload)
        , realEstateListingCompanyRef = realEstatePayloadCompanyId payload
        , realEstateListingAuthor = authorId
        , realEstateListingPublishedAt = if statusValue == "published" then Just now else Nothing
        , realEstateListingExpiresAt = Nothing
        , realEstateListingCreatedAt = now
        , realEstateListingUpdatedAt = now
        }

realEstateListingValue :: Maybe (Double, Double) -> Map.Map RealEstateListingId [Text] -> Map.Map RealEstateListingId [Value] -> Map.Map RealEstateListingId Int -> Entity RealEstateListing -> Value
realEstateListingValue mCenter featureMap imageMap inquiryCountMap (Entity listingId listing) =
    object
        [ "id" .= keyToInt listingId
        , "title" .= realEstateListingTitle listing
        , "listingType" .= realEstateListingListingType listing
        , "propertyType" .= realEstateListingPropertyType listing
        , "status" .= realEstateListingStatus listing
        , "countryCode" .= realEstateListingCountryCode listing
        , "state" .= realEstateListingState listing
        , "city" .= realEstateListingCity listing
        , "suburb" .= realEstateListingSuburb listing
        , "addressText" .= realEstateListingAddressText listing
        , "latitude" .= realEstateListingLatitude listing
        , "longitude" .= realEstateListingLongitude listing
        , "distanceKm" .= listingDistanceFrom mCenter listing
        , "currency" .= realEstateListingCurrency listing
        , "price" .= realEstateListingPrice listing
        , "pricePeriod" .= realEstateListingPricePeriod listing
        , "bondAmount" .= realEstateListingBondAmount listing
        , "depositAmount" .= realEstateListingDepositAmount listing
        , "bedrooms" .= realEstateListingBedrooms listing
        , "bathrooms" .= realEstateListingBathrooms listing
        , "parkingSpaces" .= realEstateListingParkingSpaces listing
        , "floorAreaSqm" .= realEstateListingFloorAreaSqm listing
        , "landAreaSqm" .= realEstateListingLandAreaSqm listing
        , "availableFrom" .= realEstateListingAvailableFrom listing
        , "leaseTerm" .= realEstateListingLeaseTerm listing
        , "petsAllowed" .= realEstateListingPetsAllowed listing
        , "furnished" .= realEstateListingFurnished listing
        , "billsIncluded" .= realEstateListingBillsIncluded listing
        , "content" .= realEstateListingContent listing
        , "contactName" .= realEstateListingContactName listing
        , "contactEmail" .= realEstateListingContactEmail listing
        , "contactPhone" .= realEstateListingContactPhone listing
        , "companyId" .= fmap keyToInt (realEstateListingCompanyRef listing)
        , "authorId" .= keyToInt (realEstateListingAuthor listing)
        , "features" .= Map.findWithDefault [] listingId featureMap
        , "images" .= Map.findWithDefault [] listingId imageMap
        , "inquiryCount" .= Map.findWithDefault 0 listingId inquiryCountMap
        , "publishedAt" .= realEstateListingPublishedAt listing
        , "expiresAt" .= realEstateListingExpiresAt listing
        , "createdAt" .= realEstateListingCreatedAt listing
        , "updatedAt" .= realEstateListingUpdatedAt listing
        ]

realEstateInquiryValue :: Entity RealEstateInquiry -> Value
realEstateInquiryValue (Entity inquiryId inquiry) =
    object
        [ "id" .= keyToInt inquiryId
        , "listingId" .= keyToInt (realEstateInquiryListing inquiry)
        , "senderId" .= fmap keyToInt (realEstateInquirySender inquiry)
        , "name" .= realEstateInquiryName inquiry
        , "email" .= realEstateInquiryEmail inquiry
        , "phone" .= realEstateInquiryPhone inquiry
        , "message" .= realEstateInquiryMessage inquiry
        , "status" .= realEstateInquiryStatus inquiry
        , "createdAt" .= realEstateInquiryCreatedAt inquiry
        , "updatedAt" .= realEstateInquiryUpdatedAt inquiry
        ]

realEstateReportValue :: Entity RealEstateReport -> Value
realEstateReportValue (Entity reportId report) =
    object
        [ "id" .= keyToInt reportId
        , "listingId" .= keyToInt (realEstateReportListing report)
        , "reporterId" .= fmap keyToInt (realEstateReportReporter report)
        , "name" .= realEstateReportName report
        , "email" .= realEstateReportEmail report
        , "reason" .= realEstateReportReason report
        , "details" .= realEstateReportDetails report
        , "status" .= realEstateReportStatus report
        , "createdAt" .= realEstateReportCreatedAt report
        , "updatedAt" .= realEstateReportUpdatedAt report
        ]

realEstateAgentProfileValue :: Entity RealEstateAgentProfile -> Value
realEstateAgentProfileValue (Entity profileId profile) =
    object
        [ "id" .= keyToInt profileId
        , "userId" .= keyToInt (realEstateAgentProfileUser profile)
        , "agencyName" .= realEstateAgentProfileAgencyName profile
        , "licenseNumber" .= realEstateAgentProfileLicenseNumber profile
        , "website" .= realEstateAgentProfileWebsite profile
        , "phone" .= realEstateAgentProfilePhone profile
        , "email" .= realEstateAgentProfileEmail profile
        , "verified" .= realEstateAgentProfileVerified profile
        , "createdAt" .= realEstateAgentProfileCreatedAt profile
        , "updatedAt" .= realEstateAgentProfileUpdatedAt profile
        ]

loadRealEstateMeta :: [RealEstateListingId] -> Handler (Map.Map RealEstateListingId [Text], Map.Map RealEstateListingId [Value], Map.Map RealEstateListingId Int)
loadRealEstateMeta [] = pure (Map.empty, Map.empty, Map.empty)
loadRealEstateMeta listingIds = do
    featureRows <- runDB $ selectList [RealEstateFeatureListing <-. listingIds] [Asc RealEstateFeatureSortOrder]
    imageRows <- runDB $ selectList [RealEstateImageListing <-. listingIds] [Asc RealEstateImageSortOrder]
    inquiryRows <- runDB $ selectList [RealEstateInquiryListing <-. listingIds] []
    let featureMap = appendTextMap realEstateFeatureListing realEstateFeatureName featureRows
    imageValues <- mapM realEstateImageValue imageRows
    let imageMap =
            P.foldl'
                (\acc (row, value) ->
                    Map.insertWith (P.flip (<>)) (realEstateImageListing (entityVal row)) [value] acc
                )
                Map.empty
                (zip imageRows imageValues)
        inquiryCountMap = P.foldl' (\acc row -> Map.insertWith (+) (realEstateInquiryListing (entityVal row)) 1 acc) Map.empty inquiryRows
    pure (featureMap, imageMap, inquiryCountMap)

realEstateImageValue :: Entity RealEstateImage -> Handler Value
realEstateImageValue (Entity imageId image) = do
    storage <- getsYesod appStorage
    url <- storageUrl storage (realEstateImageFileKey image)
    pure $ object
        [ "id" .= keyToInt imageId
        , "listingId" .= keyToInt (realEstateImageListing image)
        , "fileKey" .= realEstateImageFileKey image
        , "url" .= url
        , "caption" .= realEstateImageCaption image
        , "sortOrder" .= realEstateImageSortOrder image
        , "createdAt" .= realEstateImageCreatedAt image
        ]

replaceRealEstateFeatures :: RealEstateListingId -> [Text] -> ReaderT SqlBackend Handler ()
replaceRealEstateFeatures listingId features = do
    deleteWhere [RealEstateFeatureListing ==. listingId]
    insertMany_ $
        zipWith
            (\indexValue name -> RealEstateFeature listingId name indexValue)
            [0..]
            features

appendTextMap :: Ord key => (value -> key) -> (value -> Text) -> [Entity value] -> Map.Map key [Text]
appendTextMap keyFn valueFn =
    P.foldl'
        (\acc row ->
            let value = entityVal row
            in Map.insertWith (P.flip (<>)) (keyFn value) [valueFn value] acc
        )
        Map.empty

normalizeFeatureList :: [Text] -> [Text]
normalizeFeatureList =
    P.take 30 . L.nub . map (T.toLower . T.strip) . filter (not . T.null . T.strip)

validateNonNegative :: Text -> Maybe Int -> Handler ()
validateNonNegative _ Nothing = pure ()
validateNonNegative fieldName (Just value) =
    when (value < 0) $
        jsonError status400 "invalid_number" (fieldName <> " must be zero or greater.")

autoExpireRealEstateListings :: Handler ()
autoExpireRealEstateListings = do
    now <- liftIO getCurrentTime
    runDB $ updateWhere
        [ RealEstateListingStatus ==. "published"
        , RealEstateListingExpiresAt !=. Nothing
        , RealEstateListingExpiresAt <=. Just now
        ]
        [ RealEstateListingStatus =. "expired"
        , RealEstateListingUpdatedAt =. now
        ]

defaultRealEstateExpiresAt :: Text -> UTCTime -> Handler (Maybe UTCTime)
defaultRealEstateExpiresAt statusValue now
    | statusValue /= "published" = pure Nothing
    | otherwise = do
        settingMap <- loadSettingMap
        let expiryDays = max 1 (siteSettingInt "real_estate_listing_expiry_days" 30 settingMap)
            seconds = fromIntegral (expiryDays * 24 * 60 * 60)
        pure $ Just (addUTCTime seconds now)

enforceInquiryRateLimit :: RealEstateListingId -> Text -> UTCTime -> Handler ()
enforceInquiryRateLimit listingId email now = do
    let windowStart = addUTCTime (negate (60 * 60)) now
    recentCount <- runDB $ count
        [ RealEstateInquiryListing ==. listingId
        , RealEstateInquiryEmail ==. email
        , RealEstateInquiryCreatedAt >=. windowStart
        ]
    when (recentCount >= (3 :: Int)) $
        jsonError status429 "inquiry_rate_limited" "Too many inquiries. Please try again later."

requireListingManager :: UserId -> User -> RealEstateListing -> Handler ()
requireListingManager viewerId viewer listing =
    unless (realEstateListingAuthor listing == viewerId || userRole viewer == ("admin" :: Text)) $
        jsonError status403 "forbidden" "Only the listing author or admin can manage this listing."

ensureRealEstateAgentAccess :: UserId -> User -> Handler ()
ensureRealEstateAgentAccess _ viewer =
    unless (userRole viewer == ("admin" :: Text) || userAccountType viewer == ("real_estate" :: Text) || isJust (userRealEstatePlan viewer)) $
        jsonError status403 "real_estate_membership_required" "Real estate membership is required."

enforceRealEstateListingQuota :: UserId -> User -> Handler ()
enforceRealEstateListingQuota viewerId viewer = do
    ensureRealEstateAgentAccess viewerId viewer
    unless (userRole viewer == ("admin" :: Text)) $ do
        now <- liftIO getCurrentTime
        quota <- realEstateQuota viewerId viewer now
        case realEstateQuotaLimit quota of
            Nothing -> pure ()
            Just limitValue ->
                when (realEstateQuotaUsed quota >= limitValue) $
                    jsonError status402 "real_estate_quota_exceeded" "Monthly real estate listing quota exceeded."

data RealEstatePlan = RealEstatePlan
    { realEstatePlanKey :: Text
    , realEstatePlanName :: Text
    , realEstatePlanMonthlyPrice :: Maybe Int
    , realEstatePlanMonthlyListingLimit :: Maybe Int
    , realEstatePlanDescription :: Text
    }

realEstatePlans :: [RealEstatePlan]
realEstatePlans =
    [ RealEstatePlan "starter" "Starter" (Just 100000) (Just 10) "월 10만원 · 부동산 매물 10개"
    , RealEstatePlan "growth" "Growth" (Just 300000) (Just 30) "월 30만원 · 부동산 매물 30개"
    , RealEstatePlan "scale" "Scale" (Just 500000) (Just 70) "월 50만원 · 부동산 매물 70개"
    , RealEstatePlan "enterprise" "Enterprise" Nothing Nothing "70개 초과는 협의"
    ]

realEstatePlanValue :: RealEstatePlan -> Value
realEstatePlanValue plan =
    object
        [ "key" .= realEstatePlanKey plan
        , "name" .= realEstatePlanName plan
        , "monthlyPrice" .= realEstatePlanMonthlyPrice plan
        , "monthlyListingLimit" .= realEstatePlanMonthlyListingLimit plan
        , "description" .= realEstatePlanDescription plan
        ]

lookupRealEstatePlan :: Maybe Text -> RealEstatePlan
lookupRealEstatePlan mPlanKey =
    fromMaybe defaultRealEstatePlan $
        mPlanKey >>= \planKey -> L.find ((== planKey) . realEstatePlanKey) realEstatePlans

defaultRealEstatePlan :: RealEstatePlan
defaultRealEstatePlan = RealEstatePlan "starter" "Starter" (Just 100000) (Just 10) "월 10만원 · 부동산 매물 10개"

data RealEstateQuota = RealEstateQuota
    { realEstateQuotaPlan :: RealEstatePlan
    , realEstateQuotaUsed :: Int
    , realEstateQuotaLimit :: Maybe Int
    , realEstateQuotaPeriodStart :: Day
    }

realEstateQuota :: UserId -> User -> UTCTime -> Handler RealEstateQuota
realEstateQuota viewerId viewer now = do
    let plan = lookupRealEstatePlan (userRealEstatePlan viewer)
        (year, month, _) = toGregorian (utctDay now)
        periodStart = fromGregorian year month 1
    used <- runDB $ count [RealEstateListingAuthor ==. viewerId, RealEstateListingCreatedAt >=. UTCTime periodStart 0]
    pure $
        RealEstateQuota
            { realEstateQuotaPlan = plan
            , realEstateQuotaUsed = used
            , realEstateQuotaLimit = realEstatePlanMonthlyListingLimit plan
            , realEstateQuotaPeriodStart = periodStart
            }

realEstateQuotaValue :: UserId -> User -> UTCTime -> Handler Value
realEstateQuotaValue viewerId viewer now = do
    quota <- realEstateQuota viewerId viewer now
    pure $
        object
            [ "plan" .= realEstatePlanValue (realEstateQuotaPlan quota)
            , "usedThisMonth" .= realEstateQuotaUsed quota
            , "monthlyListingLimit" .= realEstateQuotaLimit quota
            , "periodStart" .= realEstateQuotaPeriodStart quota
            ]

lookupOptionalTextQueryParam :: Text -> Handler (Maybe Text)
lookupOptionalTextQueryParam fieldName =
    normalizeOptionalText . fmap T.strip <$> lookupGetParam fieldName

lookupOptionalIntQueryParam :: Text -> Handler (Maybe Int)
lookupOptionalIntQueryParam fieldName = do
    raw <- fmap T.strip <$> lookupGetParam fieldName
    case raw of
        Nothing -> pure Nothing
        Just "" -> pure Nothing
        Just value ->
            case P.reads (T.unpack value) of
                [(parsed, "")] -> pure (Just parsed)
                _ -> jsonError status400 "invalid_query_param" (fieldName <> " must be an integer.")

lookupOptionalDoubleQueryParam :: Text -> Handler (Maybe Double)
lookupOptionalDoubleQueryParam fieldName = do
    raw <- fmap T.strip <$> lookupGetParam fieldName
    case raw of
        Nothing -> pure Nothing
        Just "" -> pure Nothing
        Just value ->
            case P.reads (T.unpack value) of
                [(parsed, "")] -> pure (Just parsed)
                _ -> jsonError status400 "invalid_query_param" (fieldName <> " must be a number.")

validateRadiusQuery :: Maybe Double -> Maybe Double -> Handler (Maybe Double)
validateRadiusQuery Nothing Nothing = pure Nothing
validateRadiusQuery Nothing (Just _) =
    jsonError status400 "invalid_radius" "latitude and longitude are required when radiusKm is provided."
validateRadiusQuery (Just _) Nothing = pure (Just 10)
validateRadiusQuery (Just _) (Just radius)
    | radius <= 0 = jsonError status400 "invalid_radius" "radiusKm must be greater than zero."
    | radius > 1000 = jsonError status400 "invalid_radius" "radiusKm must be 1000 or less."
    | otherwise = pure (Just radius)

listingWithinRadius :: (Double, Double) -> Double -> Entity RealEstateListing -> Bool
listingWithinRadius center radius (Entity _ listing) =
    maybe False (<= radius) (listingDistanceFrom (Just center) listing)

listingDistanceFrom :: Maybe (Double, Double) -> RealEstateListing -> Maybe Double
listingDistanceFrom Nothing _ = Nothing
listingDistanceFrom (Just (originLat, originLng)) listing =
    haversineKm originLat originLng
        <$> realEstateListingLatitude listing
        <*> realEstateListingLongitude listing

boundingBox :: Double -> Double -> Double -> (Double, Double, Double, Double)
boundingBox lat lng radiusKm =
    let latDelta = radiusKm / 111.32
        cosLat = P.cos (degreesToRadians lat)
        lngDelta =
            if P.abs cosLat < 0.000001
                then 180
                else P.min 180 (radiusKm / (111.32 * P.abs cosLat))
    in ( clampLatitude (lat - latDelta)
       , clampLatitude (lat + latDelta)
       , clampLongitude (lng - lngDelta)
       , clampLongitude (lng + lngDelta)
       )

haversineKm :: Double -> Double -> Double -> Double -> Double
haversineKm lat1 lng1 lat2 lng2 =
    let earthRadiusKm = 6371.0088
        dLat = degreesToRadians (lat2 - lat1)
        dLng = degreesToRadians (lng2 - lng1)
        rLat1 = degreesToRadians lat1
        rLat2 = degreesToRadians lat2
        a = P.sin (dLat / 2) P.^ (2 :: Int)
            + P.cos rLat1 * P.cos rLat2 * P.sin (dLng / 2) P.^ (2 :: Int)
        c = 2 * P.atan2 (P.sqrt a) (P.sqrt (1 - a))
    in earthRadiusKm * c

degreesToRadians :: Double -> Double
degreesToRadians value = value * P.pi / 180

clampLatitude :: Double -> Double
clampLatitude = P.max (-90) . P.min 90

clampLongitude :: Double -> Double
clampLongitude = P.max (-180) . P.min 180

lookupOptionalAllowedQueryParam :: Text -> Text -> [Text] -> Handler (Maybe Text)
lookupOptionalAllowedQueryParam errCode fieldName allowedValues =
    lookupGetParam fieldName >>= requireOptionalAllowedOption errCode fieldName allowedValues

requireAllowedOption :: Text -> Text -> [Text] -> Text -> Handler Text
requireAllowedOption errCode fieldName allowedValues raw = do
    let value = T.toLower $ T.strip raw
    when (T.null value) $
        jsonError status400 errCode (fieldName <> " is required.")
    unless (value `P.elem` allowedValues) $
        jsonError status400 errCode (fieldName <> " is invalid.")
    pure value

requireOptionalAllowedOption :: Text -> Text -> [Text] -> Maybe Text -> Handler (Maybe Text)
requireOptionalAllowedOption _ _ _ Nothing = pure Nothing
requireOptionalAllowedOption errCode fieldName allowedValues (Just raw) = do
    let value = T.toLower $ T.strip raw
    if T.null value
        then pure Nothing
        else do
            unless (value `P.elem` allowedValues) $
                jsonError status400 errCode (fieldName <> " is invalid.")
            pure (Just value)

listingTypeOptions :: [Text]
listingTypeOptions = ["rent", "sale", "share", "short_term"]

propertyTypeOptions :: [Text]
propertyTypeOptions = ["apartment", "house", "townhouse", "studio", "room", "land", "commercial"]

pricePeriodOptions :: [Text]
pricePeriodOptions = ["weekly", "monthly", "total"]

inquiryStatusOptions :: [Text]
inquiryStatusOptions = ["new", "replied", "closed"]

realEstateReportReasonOptions :: [Text]
realEstateReportReasonOptions = ["fraud", "duplicate", "unavailable", "wrong_info", "spam", "other"]

realEstateReportStatusOptions :: [Text]
realEstateReportStatusOptions = ["new", "reviewing", "resolved", "dismissed"]

realEstateSortOptions :: [Text]
realEstateSortOptions = ["latest", "price_asc", "price_desc", "distance"]
