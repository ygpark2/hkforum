{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}

module Handler.Admin.Companies
    ( getAdminCompaniesR
    , getAdminCompanyNewR
    , getAdminCompanyR
    , postAdminCompaniesR
    , postAdminCompanyR
    , getAdminCompanyCategoriesR
    , getAdminCompanyCategoryNewR
    , getAdminCompanyCategoryR
    , postAdminCompanyCategoriesR
    , postAdminCompanyCategoryR
    ) where

import Company.Description (prepareCompanyDescription)
import Import
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Text.Blaze (preEscapedText)
import qualified Prelude as P

getAdminCompaniesR :: Handler Html
getAdminCompaniesR = do
    companies <- runDB $ selectList [] [Desc CompanyUpdatedAt, Asc CompanyName]
    categories <- runDB $ selectList [] [Asc CompanyGroupName]
    let categoryIds = L.nub $ map (companyCategory . entityVal) companies
        authorIds = L.nub $ map (companyAuthor . entityVal) companies
    categoryRows <-
        if P.null categoryIds
            then pure []
            else runDB $ selectList [CompanyGroupId <-. categoryIds] []
    authors <-
        if P.null authorIds
            then pure []
            else runDB $ selectList [UserId <-. authorIds] []
    let categoryMap = Map.fromList $ map (\(Entity categoryId category) -> (categoryId, companyGroupName category)) categoryRows
        authorMap = Map.fromList $ map (\(Entity userId user) -> (userId, userIdent user)) authors
        totalCategories = length categories
        categoryNameFor categoryId = Map.findWithDefault ("Unknown" :: Text) categoryId categoryMap
        authorNameFor userId = Map.findWithDefault ("Unknown" :: Text) userId authorMap
    req <- getRequest
    let mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Companies"
        let adminBody = $(widgetFile "admin/admin-companies")
            activeKey = ("companies" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminCompanyNewR :: Handler Html
getAdminCompanyNewR = do
    categories <- runDB $ selectList [] [Asc CompanyGroupName]
    req <- getRequest
    let mCsrfToken = reqToken req
        mCompany = (Nothing :: Maybe (Entity Company))
        isNew = True
        categoryAuthorName = Nothing :: Maybe Text
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New Company"
        let adminBody = $(widgetFile "admin/admin-company-detail")
            activeKey = ("companies" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminCompanyR :: CompanyId -> Handler Html
getAdminCompanyR companyId = do
    company <- runDB $ get404 companyId
    categories <- runDB $ selectList [] [Asc CompanyGroupName]
    mAuthor <- runDB $ get (companyAuthor company)
    req <- getRequest
    let mCsrfToken = reqToken req
        mCompany = Just (Entity companyId company)
        isNew = False
        categoryAuthorName = userIdent <$> mAuthor
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit Company"
        let adminBody = $(widgetFile "admin/admin-company-detail")
            activeKey = ("companies" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminCompanyCategoriesR :: Handler Html
getAdminCompanyCategoriesR = do
    categories <- runDB $ selectList [] [Asc CompanyGroupName]
    companies <- runDB $ selectList [] []
    let companyCountMap =
            Map.fromListWith (+) $
                map (\(Entity _ company) -> (companyCategory company, 1 :: Int)) companies
        categoryRows =
            map
                (\ent@(Entity categoryId _) ->
                    (ent, Map.findWithDefault 0 categoryId companyCountMap))
                categories
    req <- getRequest
    let mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Company Categories"
        let adminBody = $(widgetFile "admin/admin-company-categories")
            activeKey = ("company-categories" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminCompanyCategoryNewR :: Handler Html
getAdminCompanyCategoryNewR = do
    req <- getRequest
    let mCsrfToken = reqToken req
        mCategory = (Nothing :: Maybe (Entity CompanyGroup))
        isNew = True
        companyCount = 0 :: Int
        categoryAuthorName = Nothing :: Maybe Text
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New Company Category"
        let adminBody = $(widgetFile "admin/admin-company-category-detail")
            activeKey = ("company-categories" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminCompanyCategoryR :: CompanyGroupId -> Handler Html
getAdminCompanyCategoryR categoryId = do
    category <- runDB $ get404 categoryId
    companyCount <- runDB $ count [CompanyCategory ==. categoryId]
    mAuthor <- runDB $ get (companyGroupAuthor category)
    req <- getRequest
    let mCsrfToken = reqToken req
        mCategory = Just (Entity categoryId category)
        isNew = False
        categoryAuthorName = userIdent <$> mAuthor
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit Company Category"
        let adminBody = $(widgetFile "admin/admin-company-category-detail")
            activeKey = ("company-categories" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

postAdminCompaniesR :: Handler Html
postAdminCompaniesR = do
    adminId <- requireAuthId
    nameRaw <- runInputPost $ ireq textField "name"
    categoryId <- runInputPost $ ireq hiddenField "categoryId"
    mWebsite <- runInputPost $ iopt textField "website"
    mLocation <- runInputPost $ iopt textField "location"
    mSize <- runInputPost $ iopt textField "size"
    descriptionRaw <- runInputPost $ ireq textField "description"
    _ <- runDB $ get404 categoryId
    now <- liftIO getCurrentTime
    let name = T.strip nameRaw
        website = normalizeOptionalText mWebsite
        location = normalizeOptionalText mLocation
        size = normalizeOptionalText mSize
    descriptionResult <- pure $ prepareCompanyDescription descriptionRaw
    if T.null name
        then setMessage "Company name is required."
        else case descriptionResult of
            Left err -> setMessage (preEscapedText err)
            Right description -> do
                _ <- runDB $ insert $ Company name categoryId website location size description adminId now now
                setMessage "Company created."
    redirect AdminCompaniesR

postAdminCompanyR :: CompanyId -> Handler Html
postAdminCompanyR companyId = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            runDB $ delete companyId
            setMessage "Company deleted."
            redirect AdminCompaniesR
        "update" -> do
            nameRaw <- runInputPost $ ireq textField "name"
            categoryId <- runInputPost $ ireq hiddenField "categoryId"
            mWebsite <- runInputPost $ iopt textField "website"
            mLocation <- runInputPost $ iopt textField "location"
            mSize <- runInputPost $ iopt textField "size"
            descriptionRaw <- runInputPost $ ireq textField "description"
            _ <- runDB $ get404 categoryId
            now <- liftIO getCurrentTime
            let name = T.strip nameRaw
                website = normalizeOptionalText mWebsite
                location = normalizeOptionalText mLocation
                size = normalizeOptionalText mSize
            descriptionResult <- pure $ prepareCompanyDescription descriptionRaw
            if T.null name
                then setMessage "Company name is required."
                else case descriptionResult of
                    Left err -> setMessage (preEscapedText err)
                    Right description -> do
                        runDB $ update companyId
                            [ CompanyName =. name
                            , CompanyCategory =. categoryId
                            , CompanyWebsite =. website
                            , CompanyLocation =. location
                            , CompanySize =. size
                            , CompanyDescription =. description
                            , CompanyUpdatedAt =. now
                            ]
                        setMessage "Company updated."
            redirect (AdminCompanyR companyId)
        _ -> do
            setMessage "Unknown action."
            redirect AdminCompaniesR

postAdminCompanyCategoriesR :: Handler Html
postAdminCompanyCategoriesR = do
    adminId <- requireAuthId
    nameRaw <- runInputPost $ ireq textField "name"
    codeRaw <- runInputPost $ ireq textField "code"
    description <- runInputPost $ iopt textareaField "description"
    now <- liftIO getCurrentTime
    let name = T.strip nameRaw
        code = T.strip codeRaw
        mDescription = normalizeOptionalTextarea description
    if T.null name
        then setMessage "Category name is required."
        else if T.null code
            then setMessage "Category code is required."
        else do
            inserted <- runDB $ insertBy $ CompanyGroup name mDescription adminId now code Nothing 0 False
            case inserted of
                Left _ -> setMessage "Company category code already exists."
                Right _ -> setMessage "Company category created."
    redirect AdminCompanyCategoriesR

postAdminCompanyCategoryR :: CompanyGroupId -> Handler Html
postAdminCompanyCategoryR categoryId = do
    action <- runInputPost $ ireq textField "action"
    category <- runDB $ get404 categoryId
    case action of
        "delete" -> do
            companyCount <- runDB $ count [CompanyCategory ==. categoryId]
            if companyGroupIsSystem category
                then setMessage "System category cannot be deleted."
                else if companyCount > 0
                then setMessage "Category has companies and cannot be deleted."
                else do
                    runDB $ delete categoryId
                    setMessage "Company category deleted."
            redirect AdminCompanyCategoriesR
        "update" -> do
            nameRaw <- runInputPost $ ireq textField "name"
            codeRaw <- runInputPost $ ireq textField "code"
            description <- runInputPost $ iopt textareaField "description"
            let name = T.strip nameRaw
                code = T.strip codeRaw
                mDescription = normalizeOptionalTextarea description
            if companyGroupIsSystem category
                then setMessage "System category cannot be edited."
                else if T.null name
                then setMessage "Category name is required."
                else if T.null code
                then setMessage "Category code is required."
                else do
                    mExistingCode <- runDB $ getBy $ UniqueCompanyGroupCode code
                    case mExistingCode of
                        Just (Entity existingId _) | existingId /= categoryId ->
                            setMessage "Company category code already exists."
                        _ -> do
                            runDB $ update categoryId
                                [ CompanyGroupName =. name
                                , CompanyGroupCode =. code
                                , CompanyGroupDescription =. mDescription
                                ]
                            setMessage "Company category updated."
            redirect (AdminCompanyCategoryR categoryId)
        _ -> do
            setMessage "Unknown action."
            redirect AdminCompanyCategoriesR

normalizeOptionalTextarea :: Maybe Textarea -> Maybe Text
normalizeOptionalTextarea = normalizeOptionalText . fmap unTextarea

normalizeOptionalText :: Maybe Text -> Maybe Text
normalizeOptionalText Nothing = Nothing
normalizeOptionalText (Just raw) =
    let trimmed = T.strip raw
    in if T.null trimmed then Nothing else Just trimmed
