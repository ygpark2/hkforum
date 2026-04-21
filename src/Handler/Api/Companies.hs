{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Companies where

import Company.Description (prepareCompanyDescription)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Handler.Api.Common
import Import
import SiteSettings
import qualified Prelude as P

getApiCompaniesR :: Handler Value
getApiCompaniesR = do
    ensureApiReadAllowed
    settingMap <- loadSettingMap
    unless (siteSettingBool "companies_enabled" True settingMap) $
        jsonError status403 "companies_disabled" "Companies are currently disabled."
    (page, size, offset) <- paginationParams
    mViewer <- maybeApiAuth
    mMajor <- lookupGetParam "major"
    mCategory <- lookupGetParam "category"
    let mCategoryId = mCategory >>= fromPathPiece
        categoryFilters = maybe [] (\cid -> [CompanyCategory ==. cid]) mCategoryId
    categories <- runDB $ selectList [] []
    let categoryMap = Map.fromList $ map (\(Entity cid category) -> (cid, category)) categories
        majorFilters =
            case fmap T.strip mMajor of
                Just majorCode | not (T.null majorCode) ->
                    let categoryIds =
                            [ cid
                            | (cid, category) <- Map.toList categoryMap
                            , companyGroupMajorCode category == Just majorCode
                            ]
                    in [CompanyCategory <-. categoryIds]
                _ -> []
        baseFilters =
            if not (P.null categoryFilters)
                then categoryFilters
                else majorFilters
        finalFilters =
            case activeRegionFilter mViewer of
                RegionFilterUnavailable -> baseFilters
                RegionFilterDisabled -> baseFilters
                RegionFilterEnabled countryCodeValue stateValue ->
                    baseFilters
                        <> [ CompanyCountryCode ==. Just countryCodeValue
                           , CompanyState ==. Just stateValue
                           ]
    companies <- case activeRegionFilter mViewer of
        RegionFilterUnavailable -> pure []
        _ -> runDB $ selectList finalFilters [Desc CompanyCreatedAt, OffsetBy offset, LimitTo (size + 1)]
    let hasNext = P.length companies > size
        pageRows = P.take size companies
        authorIds = L.nub $ map (companyAuthor . entityVal) pageRows
    users <- if P.null authorIds then pure [] else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) users
        items = map (companyValue userMap categoryMap) pageRows
    returnJson $
        object
            [ "items" .= items
            , "page" .= page
            , "size" .= size
            , "hasNext" .= hasNext
            ]

postApiCompaniesR :: Handler Value
postApiCompaniesR = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    settingMap <- loadSettingMap
    unless (siteSettingBool "companies_enabled" True settingMap) $
        jsonError status403 "companies_disabled" "Companies are currently disabled."
    payload <- requireCheckJsonBody :: Handler CreateCompanyPayload
    category <- requireDbEntity (createCompanyCategoryId payload) "category_not_found" "Category not found."
    unless (companyGroupIsSystem (entityVal category)) $
        jsonError status400 "invalid_category" "categoryId is invalid"
    let name = T.strip (createCompanyName payload)
        website = normalizeOptionalText (createCompanyWebsite payload)
        sizeValue = normalizeOptionalText (createCompanySize payload)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    description <-
        case prepareCompanyDescription (createCompanyDescription payload) of
            Left err -> jsonError status400 "invalid_description" err
            Right value -> pure value
    when (T.null name) $ jsonError status400 "invalid_name" "Name is required."
    when (textContainsBlockedTerm blockedWords (name <> " " <> description)) $
        jsonError status400 "blocked_terms" "Content contains blocked terms."
    (mLatitudeValue, mLongitudeValue) <- requireCoordinatePairJson (createCompanyLatitude payload) (createCompanyLongitude payload)
    let (mCountryCodeValue, mStateValue) = userRegionFields (entityVal viewer)
    now <- liftIO getCurrentTime
    companyId <- runDB $ insert Company
        { companyName = name
        , companyCategory = createCompanyCategoryId payload
        , companyWebsite = website
        , companySize = sizeValue
        , companyCountryCode = mCountryCodeValue
        , companyState = mStateValue
        , companyLatitude = mLatitudeValue
        , companyLongitude = mLongitudeValue
        , companyDescription = description
        , companyAuthor = viewerId
        , companyCreatedAt = now
        , companyUpdatedAt = now
        }
    created <- requireDbEntity companyId "company_not_found" "Company not found."
    sendResponseStatus status201 $
        object
            [ "company" .= companyValue
                (Map.singleton viewerId (entityVal viewer))
                (Map.singleton (entityKey category) (entityVal category))
                created
            ]

patchApiCompanyR :: CompanyId -> Handler Value
patchApiCompanyR companyId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    company <- requireDbEntity companyId "company_not_found" "Company not found."
    let currentCompany = entityVal company
        canEdit = companyAuthor currentCompany == viewerId || userRole (entityVal viewer) == ("admin" :: Text)
    unless canEdit $
        jsonError status403 "forbidden" "Not allowed."
    settingMap <- loadSettingMap
    unless (siteSettingBool "companies_enabled" True settingMap) $
        jsonError status403 "companies_disabled" "Companies are currently disabled."
    payload <- requireCheckJsonBody :: Handler UpdateCompanyPayload
    category <- requireDbEntity (updateCompanyCategoryId payload) "category_not_found" "Category not found."
    unless (companyGroupIsSystem (entityVal category)) $
        jsonError status400 "invalid_category" "categoryId is invalid"
    let name = T.strip (updateCompanyName payload)
        website = normalizeOptionalText (updateCompanyWebsite payload)
        sizeValue = normalizeOptionalText (updateCompanySize payload)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    description <-
        case prepareCompanyDescription (updateCompanyDescription payload) of
            Left err -> jsonError status400 "invalid_description" err
            Right value -> pure value
    when (T.null name) $ jsonError status400 "invalid_name" "Name is required."
    when (textContainsBlockedTerm blockedWords (name <> " " <> description)) $
        jsonError status400 "blocked_terms" "Content contains blocked terms."
    (mLatitudeValue, mLongitudeValue) <- requireCoordinatePairJson (updateCompanyLatitude payload) (updateCompanyLongitude payload)
    now <- liftIO getCurrentTime
    runDB $
        update companyId
            [ CompanyName =. name
            , CompanyCategory =. updateCompanyCategoryId payload
            , CompanyWebsite =. website
            , CompanySize =. sizeValue
            , CompanyLatitude =. mLatitudeValue
            , CompanyLongitude =. mLongitudeValue
            , CompanyDescription =. description
            , CompanyUpdatedAt =. now
            ]
    updated <- requireDbEntity companyId "company_not_found" "Company not found."
    authors <-
        if viewerId == companyAuthor (entityVal updated)
            then pure (Map.singleton viewerId (entityVal viewer))
            else do
                author <- requireDbEntity (companyAuthor (entityVal updated)) "user_not_found" "User not found."
                pure (Map.singleton (entityKey author) (entityVal author))
    returnJson $
        object
            [ "company" .= companyValue
                authors
                (Map.singleton (entityKey category) (entityVal category))
                updated
            ]

deleteApiCompanyR :: CompanyId -> Handler Value
deleteApiCompanyR companyId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    company <- requireDbEntity companyId "company_not_found" "Company not found."
    let currentCompany = entityVal company
        canDelete = companyAuthor currentCompany == viewerId || userRole (entityVal viewer) == ("admin" :: Text)
    unless canDelete $
        jsonError status403 "forbidden" "Not allowed."
    runDB $ delete companyId
    returnJson $ object ["message" .= ("Company deleted." :: Text)]
