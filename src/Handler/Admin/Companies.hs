{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE QuasiQuotes #-}
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

import Company.Categories
    ( CompanyMajorCategory(..)
    , companyMajorCategories
    , findCompanyMajorCategory
    )
import Company.Description (prepareCompanyDescription)
import Import
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as T
import Text.Blaze (preEscapedText)
import qualified Prelude as P

data AdminCategoryTreeEntry
    = AdminCategoryTreeGroup Text Text [AdminCategoryTreeNode]
    | AdminCategoryTreeNodeEntry AdminCategoryTreeNode

data AdminCategoryTreeNode = AdminCategoryTreeNode
    { adminCategoryTreeEntity :: Entity CompanyGroup
    , adminCategoryTreeCompanyCount :: Int
    , adminCategoryTreeChildren :: [AdminCategoryTreeNode]
    }

getAdminCompaniesR :: Handler Html
getAdminCompaniesR = do
    companies <- runDB $ selectList [] [Desc CompanyUpdatedAt, Asc CompanyName]
    categories <- loadAdminCompanyCategories
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
        let adminBody = $(widgetFile "admin/company/list")
            activeKey = ("companies" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminCompanyNewR :: Handler Html
getAdminCompanyNewR = do
    categories <- loadAdminCompanyCategories
    req <- getRequest
    let mCsrfToken = reqToken req
        mCompany = (Nothing :: Maybe (Entity Company))
        isNew = True
        categoryAuthorName = Nothing :: Maybe Text
        majorOptions = companyMajorOptions categories
        selectedMajorKey = defaultSelectedMajorKey majorOptions
        selectedCategoryId = defaultCategoryIdForMajor categories selectedMajorKey
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New Company"
        let adminBody = $(widgetFile "admin/company/detail")
            activeKey = ("companies" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminCompanyR :: CompanyId -> Handler Html
getAdminCompanyR companyId = do
    company <- runDB $ get404 companyId
    categories <- loadAdminCompanyCategories
    mAuthor <- runDB $ get (companyAuthor company)
    req <- getRequest
    let mCsrfToken = reqToken req
        mCompany = Just (Entity companyId company)
        isNew = False
        categoryAuthorName = userIdent <$> mAuthor
        majorOptions = companyMajorOptions categories
        selectedCategoryId = Just (companyCategory company)
        selectedMajorKey =
            maybe
                (defaultSelectedMajorKey majorOptions)
                (companyMajorKeyForCategory . entityVal)
                (L.find ((== companyCategory company) . entityKey) categories)
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit Company"
        let adminBody = $(widgetFile "admin/company/detail")
            activeKey = ("companies" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminCompanyCategoriesR :: Handler Html
getAdminCompanyCategoriesR = do
    categories <- loadAdminCompanyCategories
    companies <- runDB $ selectList [] []
    mSelectedParam <- lookupGetParam "selected"
    modeParam <- fromMaybe "" <$> lookupGetParam "mode"
    mParentParam <- lookupGetParam "parent"
    let companyCountMap =
            Map.fromListWith (+) $
                map (\(Entity _ company) -> (companyCategory company, 1 :: Int)) companies
        categoryMap = Map.fromList $ map (\ent@(Entity categoryId _) -> (categoryId, ent)) categories
        mSelectedCategoryId = mSelectedParam >>= fromPathPiece
        mSelectedCategory = mSelectedCategoryId >>= (`Map.lookup` categoryMap)
        isCreateCategoryMode = modeParam == "create"
        mParentCategoryId = mParentParam >>= fromPathPiece
        mParentCategory = mParentCategoryId >>= (`Map.lookup` categoryMap)
        mFormCategory =
            if isCreateCategoryMode
                then Nothing
                else mSelectedCategory
        mFormParentCategory =
            if isCreateCategoryMode
                then mParentCategory
                else do
                    Entity _ category <- mSelectedCategory
                    parentCode <- companyGroupMajorCode category
                    findCategoryByCode parentCode categories
        activeTreeCategoryId =
            if isCreateCategoryMode
                then entityKey <$> mParentCategory
                else mSelectedCategoryId
        formCompanyCount =
            maybe
                0
                (\(Entity categoryId _) -> Map.findWithDefault 0 categoryId companyCountMap)
                mFormCategory
        formAuthorIds =
            L.nub $
                map
                    (companyGroupAuthor . entityVal)
                    (maybeToList mFormCategory)
        treeEntries = buildAdminCategoryTree companyCountMap categories
        canDeleteSelected =
            maybe
                False
                (\(Entity categoryId category) ->
                    not (companyGroupIsSystem category)
                        && Map.findWithDefault 0 categoryId companyCountMap == 0
                )
                mSelectedCategory
        parentDisplayLabel =
            maybe
                ("Top level" :: Text)
                (\(Entity _ category) -> companyGroupName category <> " (" <> companyGroupCode category <> ")")
                mFormParentCategory
    formAuthors <-
        if P.null formAuthorIds
            then pure []
            else runDB $ selectList [UserId <-. formAuthorIds] []
    req <- getRequest
    let formAuthorMap = Map.fromList $ map (\(Entity userId user) -> (userId, userIdent user)) formAuthors
        formCategoryAuthorName =
            mFormCategory >>= \(Entity _ category) ->
                Map.lookup (companyGroupAuthor category) formAuthorMap
        mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Company Categories"
        let adminBody = $(widgetFile "admin/company/category/list")
            activeKey = ("company-categories" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminCompanyCategoryNewR :: Handler Html
getAdminCompanyCategoryNewR =
    redirect (AdminCompanyCategoriesR, [("mode", "create")])

getAdminCompanyCategoryR :: CompanyGroupId -> Handler Html
getAdminCompanyCategoryR categoryId =
    redirect (AdminCompanyCategoriesR, [("selected", toPathPiece categoryId)])

postAdminCompaniesR :: Handler Html
postAdminCompaniesR = do
    adminId <- requireAuthId
    admin <- runDB $ get404 adminId
    nameRaw <- runInputPost $ ireq textField "name"
    categoryId <- parsePostedCompanyCategoryId
    mWebsite <- runInputPost $ iopt textField "website"
    mSize <- runInputPost $ iopt textField "size"
    descriptionRaw <- runInputPost $ ireq textField "description"
    _ <- runDB $ get404 categoryId
    now <- liftIO getCurrentTime
    let name = T.strip nameRaw
        website = normalizeOptionalText mWebsite
        size = normalizeOptionalText mSize
        (mCountryCodeValue, mStateValue) = userRegionFields admin
    descriptionResult <- pure $ prepareCompanyDescription descriptionRaw
    if T.null name
        then setMessage "Company name is required."
                else case descriptionResult of
                    Left err -> setMessage (preEscapedText err)
                    Right description -> do
                        _ <- runDB $ insert Company
                            { companyName = name
                            , companyCategory = categoryId
                            , companyWebsite = website
                            , companySize = size
                            , companyCountryCode = mCountryCodeValue
                            , companyState = mStateValue
                            , companyLatitude = Nothing
                            , companyLongitude = Nothing
                            , companyDescription = description
                            , companyAuthor = adminId
                            , companyCreatedAt = now
                            , companyUpdatedAt = now
                            }
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
            categoryId <- parsePostedCompanyCategoryId
            mWebsite <- runInputPost $ iopt textField "website"
            mSize <- runInputPost $ iopt textField "size"
            descriptionRaw <- runInputPost $ ireq textField "description"
            _ <- runDB $ get404 categoryId
            now <- liftIO getCurrentTime
            let name = T.strip nameRaw
                website = normalizeOptionalText mWebsite
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
    mParentCategoryId <- runInputPost $ iopt hiddenField "parentCategoryId"
    mParentCategory <- traverse (runDB . get404) mParentCategoryId
    now <- liftIO getCurrentTime
    let name = T.strip nameRaw
        code = T.strip codeRaw
        mDescription = normalizeOptionalTextarea description
    if T.null name
        then setMessage "Category name is required."
        else if T.null code
            then setMessage "Category code is required."
        else do
            inserted <- runDB $ insertBy $
                CompanyGroup
                    name
                    mDescription
                    adminId
                    now
                    code
                    (companyGroupCode <$> mParentCategory)
                    0
                    False
            case inserted of
                Left _ -> setMessage "Company category code already exists."
                Right categoryId -> do
                    setMessage "Company category created."
                    redirect (AdminCompanyCategoriesR, [("selected", toPathPiece categoryId)])
    redirect (AdminCompanyCategoriesR, companyCategoryCreateParams mParentCategoryId)

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
                    mParentCategoryId <-
                        case companyGroupMajorCode category of
                            Nothing -> pure Nothing
                            Just parentCode -> fmap entityKey <$> runDB (selectFirst [CompanyGroupCode ==. parentCode] [])
                    case mParentCategoryId of
                        Just parentCategoryId ->
                            redirect (AdminCompanyCategoriesR, [("selected", toPathPiece parentCategoryId)])
                        Nothing ->
                            redirect AdminCompanyCategoriesR
            redirect (AdminCompanyCategoriesR, [("selected", toPathPiece categoryId)])
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
            redirect (AdminCompanyCategoriesR, [("selected", toPathPiece categoryId)])
        _ -> do
            setMessage "Unknown action."
            redirect (AdminCompanyCategoriesR, [("selected", toPathPiece categoryId)])

normalizeOptionalTextarea :: Maybe Textarea -> Maybe Text
normalizeOptionalTextarea = normalizeOptionalText . fmap unTextarea

normalizeOptionalText :: Maybe Text -> Maybe Text
normalizeOptionalText Nothing = Nothing
normalizeOptionalText (Just raw) =
    let trimmed = T.strip raw
    in if T.null trimmed then Nothing else Just trimmed

normalizeRegionField :: Maybe Text -> Maybe Text
normalizeRegionField = normalizeOptionalText . fmap T.strip

userRegionFields :: User -> (Maybe Text, Maybe Text)
userRegionFields user = (normalizeRegionField (userCountryCode user), normalizeRegionField (userState user))

loadAdminCompanyCategories :: Handler [Entity CompanyGroup]
loadAdminCompanyCategories =
    runDB $
        selectList
            []
            [ Desc CompanyGroupIsSystem
            , Asc CompanyGroupSortOrder
            , Asc CompanyGroupName
            ]

parsePostedCompanyCategoryId :: Handler CompanyGroupId
parsePostedCompanyCategoryId = do
    categoryIdRaw <- runInputPost $ ireq textField "categoryId"
    case fromPathPiece (T.strip categoryIdRaw) of
        Just categoryId -> pure categoryId
        Nothing -> invalidArgs ["categoryId is invalid"]

customCompanyMajorKey :: Text
customCompanyMajorKey = "__custom__"

customCompanyMajorLabel :: Text
customCompanyMajorLabel = "Custom categories"

companyMajorKeyForCategory :: CompanyGroup -> Text
companyMajorKeyForCategory category =
    fromMaybe customCompanyMajorKey (companyGroupMajorCode category)

companyMajorLabelForKey :: Text -> Text
companyMajorLabelForKey majorKey
    | majorKey == customCompanyMajorKey = customCompanyMajorLabel
    | otherwise =
        maybe majorKey companyMajorCategoryName (findCompanyMajorCategory majorKey)

companyMajorOptions :: [Entity CompanyGroup] -> [(Text, Text)]
companyMajorOptions categories =
    let presentKeys =
            Set.fromList $
                map (companyMajorKeyForCategory . entityVal) categories
        seededOptions =
            [ (companyMajorCategoryCode major, companyMajorCategoryName major)
            | major <- companyMajorCategories
            , Set.member (companyMajorCategoryCode major) presentKeys
            ]
        seededKeys = Set.fromList (map fst seededOptions)
        extraKeys =
            filter
                (\majorKey ->
                    majorKey /= customCompanyMajorKey
                        && Set.notMember majorKey seededKeys
                )
                (L.nub (map (companyMajorKeyForCategory . entityVal) categories))
        extraOptions = map (\majorKey -> (majorKey, companyMajorLabelForKey majorKey)) extraKeys
        customOptions =
            [ (customCompanyMajorKey, customCompanyMajorLabel)
            | Set.member customCompanyMajorKey presentKeys
            ]
    in seededOptions <> extraOptions <> customOptions

defaultSelectedMajorKey :: [(Text, Text)] -> Text
defaultSelectedMajorKey majorOptions =
    maybe "" fst (listToMaybe majorOptions)

defaultCategoryIdForMajor :: [Entity CompanyGroup] -> Text -> Maybe CompanyGroupId
defaultCategoryIdForMajor categories selectedMajorKey =
    entityKey
        <$> L.find
            ((== selectedMajorKey) . companyMajorKeyForCategory . entityVal)
            categories

companyCategoryCreateParams :: Maybe CompanyGroupId -> [(Text, Text)]
companyCategoryCreateParams Nothing = [("mode", "create")]
companyCategoryCreateParams (Just categoryId) =
    [("mode", "create"), ("parent", toPathPiece categoryId)]

buildAdminCategoryTree :: Map.Map CompanyGroupId Int -> [Entity CompanyGroup] -> [AdminCategoryTreeEntry]
buildAdminCategoryTree companyCountMap categories =
    let categoriesByCode =
            Map.fromList $
                map (\ent@(Entity _ category) -> (companyGroupCode category, ent)) categories
        childrenByParent =
            L.foldl'
                (\acc ent@(Entity _ category) ->
                    Map.insertWith
                        (\new old -> old <> new)
                        (companyGroupMajorCode category)
                        [ent]
                        acc
                )
                Map.empty
                categories
        buildNode ent@(Entity categoryId category) =
            AdminCategoryTreeNode
                ent
                (Map.findWithDefault 0 categoryId companyCountMap)
                (map buildNode (Map.findWithDefault [] (Just (companyGroupCode category)) childrenByParent))
        rootNodes =
            map buildNode (Map.findWithDefault [] Nothing childrenByParent)
        orphanParentCodes =
            L.nub $
                mapMaybe
                    (\(Entity _ category) -> do
                        parentCode <- companyGroupMajorCode category
                        guard (Map.notMember parentCode categoriesByCode)
                        pure parentCode
                    )
                    categories
        orphanGroups =
            map
                (\parentCode ->
                    AdminCategoryTreeGroup
                        parentCode
                        (companyMajorLabelForKey parentCode)
                        (map buildNode (Map.findWithDefault [] (Just parentCode) childrenByParent))
                )
                orphanParentCodes
    in orphanGroups <> map AdminCategoryTreeNodeEntry rootNodes

findCategoryByCode :: Text -> [Entity CompanyGroup] -> Maybe (Entity CompanyGroup)
findCategoryByCode code =
    L.find (\(Entity _ category) -> companyGroupCode category == code)

renderAdminCategoryTreeEntries :: Maybe CompanyGroupId -> [AdminCategoryTreeEntry] -> Widget
renderAdminCategoryTreeEntries activeTreeCategoryId entries =
    [whamlet|
      $forall entry <- entries
        $case entry
          $of AdminCategoryTreeGroup _ groupLabel children
            <div class="space-y-2">
              <div class="rounded-lg bg-slate-100 px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                #{groupLabel}
              <div class="space-y-2 border-l border-slate-200 pl-3">
                ^{renderAdminCategoryTreeNodes activeTreeCategoryId children}
          $of AdminCategoryTreeNodeEntry node
            ^{renderAdminCategoryTreeNodes activeTreeCategoryId [node]}
    |]

renderAdminCategoryTreeNodes :: Maybe CompanyGroupId -> [AdminCategoryTreeNode] -> Widget
renderAdminCategoryTreeNodes activeTreeCategoryId nodes =
    [whamlet|
      $forall node <- nodes
        $with Entity categoryId category <- adminCategoryTreeEntity node
          <div class="space-y-2">
            <a
              href=@{AdminCompanyCategoriesR}?selected=#{toPathPiece categoryId}
              class=#{adminCategoryNodeLinkClass activeTreeCategoryId categoryId}
              >
              <div class="flex items-center justify-between gap-3">
                <div class="min-w-0">
                  <div class="truncate text-sm font-semibold">#{companyGroupName category}
                  <div class=#{adminCategoryNodeMetaClass activeTreeCategoryId categoryId}>
                    #{companyGroupCode category} · #{adminCategoryTreeCompanyCount node} companies
                $if companyGroupIsSystem category
                  <span class=#{adminCategoryNodeBadgeClass activeTreeCategoryId categoryId}>System
            $if not (null (adminCategoryTreeChildren node))
              <div class="space-y-2 border-l border-slate-200 pl-3">
                ^{renderAdminCategoryTreeNodes activeTreeCategoryId (adminCategoryTreeChildren node)}
    |]

adminCategoryNodeLinkClass :: Maybe CompanyGroupId -> CompanyGroupId -> Text
adminCategoryNodeLinkClass activeTreeCategoryId categoryId =
    if Just categoryId == activeTreeCategoryId
        then "block rounded-xl border border-slate-900 bg-slate-900 px-3 py-2 text-white transition"
        else "block rounded-xl border border-slate-200 bg-white px-3 py-2 text-slate-900 transition hover:border-slate-300 hover:bg-slate-50"

adminCategoryNodeMetaClass :: Maybe CompanyGroupId -> CompanyGroupId -> Text
adminCategoryNodeMetaClass activeTreeCategoryId categoryId =
    if Just categoryId == activeTreeCategoryId
        then "truncate text-xs text-slate-300"
        else "truncate text-xs text-slate-500"

adminCategoryNodeBadgeClass :: Maybe CompanyGroupId -> CompanyGroupId -> Text
adminCategoryNodeBadgeClass activeTreeCategoryId categoryId =
    if Just categoryId == activeTreeCategoryId
        then "rounded-full border border-slate-700 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-300"
        else "rounded-full border border-slate-200 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-500"
