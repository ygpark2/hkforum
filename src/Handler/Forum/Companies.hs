{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Handler.Forum.Companies
    ( getCompaniesR
    , postCompaniesR
    , postCompanyCategoriesR
    ) where

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
    mSelectedCategoryParam <- lookupGetParam "category"
    categories <- runDB $ selectList [] [Asc CompanyGroupName]
    companies <- runDB $ selectList [] [Desc CompanyUpdatedAt, Asc CompanyName]
    now <- liftIO getCurrentTime
    let authorIds = L.nub $ map (companyAuthor . entityVal) companies
    users <-
        if P.null authorIds
            then pure []
            else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) users
        categoryMap = Map.fromList $ map (\ent@(Entity categoryId _) -> (categoryId, ent)) categories
        companyCountMap = Map.fromListWith (+) $ map (\(Entity _ company) -> (companyCategory company, 1 :: Int)) companies
        selectedCategoryId = mSelectedCategoryParam >>= fromPathPiece
        selectedCategory = selectedCategoryId >>= (`Map.lookup` categoryMap)
        visibleCategories =
            case selectedCategory of
                Just categoryEnt -> [categoryEnt]
                Nothing -> categories
        addCompanyByCategory acc ent@(Entity _ company) =
            Map.insertWith (\new old -> old P.++ new) (companyCategory company) [ent] acc
        companiesByCategory = P.foldl' addCompanyByCategory Map.empty companies
        companiesFor categoryId = Map.findWithDefault [] categoryId companiesByCategory
        totalCompanyCount = length companies
        visibleCompanyRows = concatMap (companiesFor . entityKey) visibleCategories
        viewerId = entityKey <$> mViewer
        allCategoryFilterClass =
            if isNothing selectedCategory
                then ("bg-slate-900 text-white" :: Text)
                else "border border-slate-200 text-slate-700 hover:border-slate-900 hover:text-slate-900"
        categoryFilterClass categoryId =
            if selectedCategoryId == Just categoryId
                then ("bg-slate-900 text-white" :: Text)
                else "border border-slate-200 text-slate-700 hover:border-slate-900 hover:text-slate-900"
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        authorHandle uid = T.toLower $ T.filter (/= ' ') (authorName uid)
        relativeTime ts =
            let minutes = floor (diffUTCTime now ts / 60) :: Int
                hours = minutes `div` 60
                days = hours `div` 24
            in if minutes < 60 then tshow minutes <> " min ago"
               else if hours < 24 then tshow hours <> " hours ago"
               else if days < 30 then tshow days <> " days ago"
               else tshow $ formatTime defaultTimeLocale "%b %e, %Y" ts
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
    _ <- runDB $ get404 categoryId
    let name = T.strip nameRaw
        mWebsite = normalizeOptionalText mWebsiteRaw
        mLocation = normalizeOptionalText mLocationRaw
        mSize = normalizeOptionalText mSizeRaw
        description = T.strip descriptionRaw
    when (T.null name) $ invalidArgs ["name is required"]
    when (T.null description) $ invalidArgs ["description is required"]
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
    mDescriptionRaw <- runInputPost $ iopt textField "description"
    let name = T.strip nameRaw
        mDescription = normalizeOptionalText mDescriptionRaw
    when (T.null name) $ invalidArgs ["name is required"]
    now <- liftIO getCurrentTime
    inserted <- runDB $ insertBy CompanyGroup
        { companyGroupName = name
        , companyGroupDescription = mDescription
        , companyGroupAuthor = userId
        , companyGroupCreatedAt = now
        }
    case inserted of
        Left _ -> setMessage "Category already exists."
        Right _ -> setMessage "Company category created."
    redirect CompaniesR

normalizeOptionalText :: Maybe Text -> Maybe Text
normalizeOptionalText Nothing = Nothing
normalizeOptionalText (Just raw) =
    let trimmed = T.strip raw
    in if T.null trimmed then Nothing else Just trimmed
