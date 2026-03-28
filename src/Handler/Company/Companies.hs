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
    mViewer <- maybeAuth
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
        if P.null visibleCategoryIds
            then pure []
            else runDB $ selectList [CompanyCategory <-. visibleCategoryIds] [Desc CompanyCreatedAt, Desc CompanyUpdatedAt, Asc CompanyName]
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
        $(widgetFile "forum/companies")

postCompaniesR :: Handler Html
postCompaniesR = do
    userId <- requireAuthId
    nameRaw <- runInputPost $ ireq textField "name"
    categoryIdRaw <- runInputPost $ ireq textField "categoryId"
    mWebsiteRaw <- runInputPost $ iopt textField "website"
    mLocationRaw <- runInputPost $ iopt textField "location"
    mSizeRaw <- runInputPost $ iopt textField "size"
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
        mLocation = normalizeOptionalText mLocationRaw
        mSize = normalizeOptionalText mSizeRaw
    description <-
        case prepareCompanyDescription descriptionRaw of
            Left err -> invalidArgs [err]
            Right value -> pure value
    when (T.null name) $ invalidArgs ["name is required"]
    now <- liftIO getCurrentTime
    _ <- runDB $ insert Company
        { companyName = name
        , companyCategory = categoryId
        , companyWebsite = mWebsite
        , companyLocation = mLocation
        , companySize = mSize
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
