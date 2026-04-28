{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Jobs where

import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Data.Aeson.Key as Key
import Handler.Api.Common
import Import
import SiteSettings
import qualified Prelude as P

getApiJobsR :: Handler Value
getApiJobsR = do
    ensureApiReadAllowed
    settingMap <- loadSettingMap
    unless (siteSettingBool "jobs_enabled" True settingMap) $
        jsonError status403 "jobs_disabled" "Jobs are currently disabled."
    autoCloseExpiredJobs
    (page, size, offset) <- paginationParams
    mViewer <- maybeApiAuth
    employmentTypeFilter <- lookupOptionalAllowedJobQueryParam "invalid_employment_type" "employmentType" jobEmploymentTypeOptions
    workplaceTypeFilter <- lookupOptionalAllowedJobQueryParam "invalid_workplace_type" "workplaceType" jobWorkplaceTypeOptions
    seniorityFilter <- lookupOptionalAllowedJobQueryParam "invalid_seniority" "seniority" jobSeniorityOptions
    salaryMinFilter <- lookupOptionalIntQueryParam "salaryMin"
    salaryMaxFilter <- lookupOptionalIntQueryParam "salaryMax"
    skillFilter <- lookupOptionalTextQueryParam "skill"
    validateSalaryRange salaryMinFilter salaryMaxFilter
    skillJobIds <- case fmap T.toLower skillFilter of
        Nothing -> pure Nothing
        Just skillName -> do
            skillRows <- runDB $ selectList [JobSkillName ==. skillName] []
            pure $ Just (L.nub $ map (jobSkillJob . entityVal) skillRows)
    let baseFilters =
            case activeRegionFilter mViewer of
                RegionFilterUnavailable -> []
                RegionFilterDisabled -> []
                RegionFilterEnabled countryCodeValue stateValue ->
                    [ JobCountryCode ==. Just countryCodeValue
                    , JobState ==. Just stateValue
                    ]
        structuredFilters =
            concat
                [ maybe [] (\value -> [JobEmploymentType ==. value]) employmentTypeFilter
                , maybe [] (\value -> [JobWorkplaceType ==. Just value]) workplaceTypeFilter
                , maybe [] (\value -> [JobSeniority ==. Just value]) seniorityFilter
                , maybe [] (\value -> [FilterOr [JobSalaryMax >=. Just value, JobSalaryMin >=. Just value]]) salaryMinFilter
                , maybe [] (\value -> [FilterOr [JobSalaryMin <=. Just value, JobSalaryMax <=. Just value]]) salaryMaxFilter
                ]
        skillFilters = maybe [] (\jobIds -> [JobId <-. jobIds]) skillJobIds
        filters = baseFilters <> structuredFilters <> skillFilters
    jobs <- case activeRegionFilter mViewer of
        RegionFilterUnavailable -> pure []
        _ | maybe False P.null skillJobIds -> pure []
        _ -> runDB $ selectList filters [Desc JobCreatedAt, OffsetBy offset, LimitTo (size + 1)]
    let hasNext = P.length jobs > size
        pageRows = P.take size jobs
        authorIds = L.nub $ map (jobAuthor . entityVal) pageRows
        jobIds = map entityKey pageRows
    users <- if P.null authorIds then pure [] else runDB $ selectList [UserId <-. authorIds] []
    (skillMap, benefitMap, applicationCountMap, viewerAppliedMap) <- loadJobMeta mViewer jobIds
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) users
        jobAutoCloseDays = max 0 (siteSettingInt "job_auto_close_days" 0 settingMap)
        items = map (jobValueWithMeta skillMap benefitMap applicationCountMap viewerAppliedMap userMap jobAutoCloseDays) pageRows
    returnJson $
        object
            [ "items" .= items
            , "page" .= page
            , "size" .= size
            , "hasNext" .= hasNext
            ]

getApiJobSkillsR :: Handler Value
getApiJobSkillsR = do
    ensureApiReadAllowed
    q <- lookupOptionalTextQueryParam "q"
    rows <- runDB $ selectList [] [Asc JobSkillName, LimitTo 200]
    let normalizedQuery = fmap T.toLower q
        names =
            L.nub
                [ skillName
                | row <- rows
                , let skillName = jobSkillName (entityVal row)
                , maybe True (`T.isInfixOf` T.toLower skillName) normalizedQuery
                ]
    returnJson $ object ["items" .= P.take 20 names]

getApiJobR :: JobId -> Handler Value
getApiJobR jobId = do
    ensureApiReadAllowed
    settingMap <- loadSettingMap
    unless (siteSettingBool "jobs_enabled" True settingMap) $
        jsonError status403 "jobs_disabled" "Jobs are currently disabled."
    autoCloseExpiredJobs
    mViewer <- maybeApiAuth
    job <- requireDbEntity jobId "job_not_found" "Job not found."
    author <- requireDbEntity (jobAuthor (entityVal job)) "user_not_found" "User not found."
    (skillMap, benefitMap, applicationCountMap, viewerAppliedMap) <- loadJobMeta mViewer [jobId]
    let userMap = Map.singleton (entityKey author) (entityVal author)
        jobAutoCloseDays = max 0 (siteSettingInt "job_auto_close_days" 0 settingMap)
    returnJson $
        object
            [ "job" .= jobValueWithMeta skillMap benefitMap applicationCountMap viewerAppliedMap userMap jobAutoCloseDays job
            ]

getApiEmployerDashboardR :: Handler Value
getApiEmployerDashboardR = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    ensureEmployerAccess viewerId (entityVal viewer)
    now <- liftIO getCurrentTime
    let isAdmin = userRole (entityVal viewer) == ("admin" :: Text)
        filters = if isAdmin then [] else [JobAuthor ==. viewerId]
    jobs <- runDB $ selectList filters [Desc JobCreatedAt, LimitTo 100]
    let jobIds = map entityKey jobs
        authorIds = L.nub $ map (jobAuthor . entityVal) jobs
    users <- if P.null authorIds then pure [] else runDB $ selectList [UserId <-. authorIds] []
    (skillMap, benefitMap, applicationCountMap, viewerAppliedMap) <- loadJobMeta (Just viewer) jobIds
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) users
        items = map (jobValueWithMeta skillMap benefitMap applicationCountMap viewerAppliedMap userMap 0) jobs
    quota <- employerQuotaValue viewerId (entityVal viewer) now
    returnJson $
        object
            [ "quota" .= quota
            , "jobs" .= items
            , "plans" .= map employerPlanValue employerPlans
            ]

postApiJobsR :: Handler Value
postApiJobsR = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    settingMap <- loadSettingMap
    unless (siteSettingBool "jobs_enabled" True settingMap) $
        jsonError status403 "jobs_disabled" "Jobs are currently disabled."
    enforceEmployerPostingQuota viewerId (entityVal viewer)
    payload <- requireCheckJsonBody :: Handler CreateJobPayload
    let title = T.strip (createJobTitle payload)
        company = T.strip (createJobCompany payload)
        salary = normalizeOptionalText (createJobSalary payload)
        salaryCurrency = normalizeOptionalText (createJobSalaryCurrency payload)
        workingHours = normalizeOptionalText (createJobWorkingHours payload)
        experience = normalizeOptionalText (createJobExperience payload)
        applyUrl = normalizeOptionalText (createJobApplyUrl payload)
        applyEmail = normalizeOptionalText (createJobApplyEmail payload)
        content = T.strip (createJobContent payload)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    employmentType <- requireAllowedJobOption "invalid_employment_type" "employmentType" jobEmploymentTypeOptions (createJobEmploymentType payload)
    workplaceType <- requireOptionalAllowedJobOption "invalid_workplace_type" "workplaceType" jobWorkplaceTypeOptions (createJobWorkplaceType payload)
    seniority <- requireOptionalAllowedJobOption "invalid_seniority" "seniority" jobSeniorityOptions (createJobSeniority payload)
    salaryPeriod <- requireOptionalAllowedJobOption "invalid_salary_period" "salaryPeriod" jobSalaryPeriodOptions (createJobSalaryPeriod payload)
    let skills = normalizeJobSkills (createJobSkills payload)
        benefits = normalizeJobBenefits (createJobBenefits payload)
    when (T.null title) $ jsonError status400 "invalid_title" "Title is required."
    when (T.null company) $ jsonError status400 "invalid_company" "Company is required."
    when (T.null content) $ jsonError status400 "invalid_content" "Content is required."
    validateSalaryRange (createJobSalaryMin payload) (createJobSalaryMax payload)
    when (textContainsBlockedTerm blockedWords (title <> " " <> company <> " " <> content)) $
        jsonError status400 "blocked_terms" "Content contains blocked terms."
    validateJobCompanyRef (createJobCompanyId payload)
    (mLatitudeValue, mLongitudeValue) <- requireCoordinatePairJson (createJobLatitude payload) (createJobLongitude payload)
    let (mCountryCodeValue, mStateValue) = userRegionFields (entityVal viewer)
    now <- liftIO getCurrentTime
    jobId <- runDB $ do
        insertedJobId <- insert Job
            { jobTitle = title
        , jobCompany = company
        , jobCompanyRef = createJobCompanyId payload
        , jobSalary = salary
        , jobSalaryMin = createJobSalaryMin payload
        , jobSalaryMax = createJobSalaryMax payload
        , jobSalaryCurrency = salaryCurrency
        , jobSalaryPeriod = salaryPeriod
        , jobWorkingHours = workingHours
        , jobDeadline = createJobDeadline payload
        , jobIsClosed = False
        , jobClosedAt = Nothing
        , jobExperience = experience
        , jobSeniority = seniority
        , jobEmploymentType = employmentType
        , jobWorkplaceType = workplaceType
        , jobApplyUrl = applyUrl
        , jobApplyEmail = applyEmail
        , jobPublishedAt = Just now
        , jobCountryCode = mCountryCodeValue
        , jobState = mStateValue
        , jobLatitude = mLatitudeValue
        , jobLongitude = mLongitudeValue
        , jobContent = content
        , jobAuthor = viewerId
        , jobCreatedAt = now
        , jobUpdatedAt = now
            }
        replaceJobMeta insertedJobId skills benefits
        pure insertedJobId
    created <- requireDbEntity jobId "job_not_found" "Job not found."
    (skillMap, benefitMap, applicationCountMap, viewerAppliedMap) <- loadJobMeta (Just (Entity viewerId (entityVal viewer))) [jobId]
    sendResponseStatus status201 $
        object
            [ "job" .= jobValueWithMeta skillMap benefitMap applicationCountMap viewerAppliedMap (Map.singleton viewerId (entityVal viewer)) (max 0 (siteSettingInt "job_auto_close_days" 0 settingMap)) created
            ]

postApiJobCloseR :: JobId -> Handler Value
postApiJobCloseR jobId = do
    viewerId <- requireApiAuthId
    settingMap <- loadSettingMap
    unless (siteSettingBool "jobs_enabled" True settingMap) $
        jsonError status403 "jobs_disabled" "Jobs are currently disabled."
    now <- liftIO getCurrentTime
    job <- requireDbEntity jobId "job_not_found" "Job not found."
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    let canClose = jobAuthor (entityVal job) == viewerId || userRole (entityVal viewer) == ("admin" :: Text)
    unless canClose $
        jsonError status403 "forbidden" "Only the author or admin can close this job."
    runDB $ update jobId [JobIsClosed =. True, JobClosedAt =. Just now, JobUpdatedAt =. now]
    returnJson $ object ["message" .= ("Job post closed." :: Text)]

postApiJobApplyR :: JobId -> Handler Value
postApiJobApplyR jobId = do
    viewerId <- requireApiAuthId
    settingMap <- loadSettingMap
    unless (siteSettingBool "jobs_enabled" True settingMap) $
        jsonError status403 "jobs_disabled" "Jobs are currently disabled."
    payload <- requireCheckJsonBody :: Handler ApplyJobPayload
    job <- requireDbEntity jobId "job_not_found" "Job not found."
    when (jobAuthor (entityVal job) == viewerId) $
        jsonError status400 "cannot_apply_own_job" "You cannot apply to your own job post."
    when (jobIsClosed (entityVal job)) $
        jsonError status400 "job_closed" "This job is closed."
    existing <- runDB $ getBy (UniqueJobApplication jobId viewerId)
    case existing of
        Just _ ->
            jsonError status409 "already_applied" "You already applied to this job."
        Nothing -> do
            now <- liftIO getCurrentTime
            let note = normalizeOptionalText (applyJobNote payload)
            runDB $ insert_ JobApplication
                { jobApplicationJob = jobId
                , jobApplicationApplicant = viewerId
                , jobApplicationNote = note
                , jobApplicationManagerNote = Nothing
                , jobApplicationRating = Nothing
                , jobApplicationStatus = "submitted"
                , jobApplicationCreatedAt = now
                , jobApplicationUpdatedAt = now
                }
            when (jobAuthor (entityVal job) /= viewerId) $
                runDB $ insert_ Notification
                    { notificationUser = jobAuthor (entityVal job)
                    , notificationActor = Just viewerId
                    , notificationKind = "job-application"
                    , notificationPost = Nothing
                    , notificationComment = Nothing
                    , notificationJob = Just jobId
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
            returnJson $ object ["message" .= ("Application submitted." :: Text)]

deleteApiJobApplyR :: JobId -> Handler Value
deleteApiJobApplyR jobId = do
    viewerId <- requireApiAuthId
    job <- requireDbEntity jobId "job_not_found" "Job not found."
    existing <- runDB $ getBy (UniqueJobApplication jobId viewerId)
    case existing of
        Nothing ->
            jsonError status404 "application_not_found" "Application not found."
        Just (Entity applicationId _) -> do
            now <- liftIO getCurrentTime
            runDB $ delete applicationId
            when (jobAuthor (entityVal job) /= viewerId) $
                runDB $ insert_ Notification
                    { notificationUser = jobAuthor (entityVal job)
                    , notificationActor = Just viewerId
                    , notificationKind = "job-application-withdrawn"
                    , notificationPost = Nothing
                    , notificationComment = Nothing
                    , notificationJob = Just jobId
                    , notificationIsRead = False
                    , notificationCreatedAt = now
                    }
            returnJson $ object ["message" .= ("Application withdrawn." :: Text)]

getApiJobApplicationsR :: JobId -> Handler Value
getApiJobApplicationsR jobId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    job <- requireDbEntity jobId "job_not_found" "Job not found."
    requireJobApplicationManager viewerId (entityVal viewer) (entityVal job)
    statusFilter <- lookupOptionalAllowedJobQueryParam "invalid_application_status" "status" jobApplicationStatusOptions
    qFilter <- lookupOptionalTextQueryParam "q"
    format <- lookupOptionalTextQueryParam "format"
    allRows <- runDB $ selectList [JobApplicationJob ==. jobId] [Desc JobApplicationCreatedAt]
    let applicantIds = L.nub $ map (jobApplicationApplicant . entityVal) allRows
    users <- if P.null applicantIds then pure [] else runDB $ selectList [UserId <-. applicantIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) users
        statusCounts = jobApplicationStatusCounts allRows
        rows =
            filter
                (\row ->
                    maybe True (== jobApplicationStatus (entityVal row)) statusFilter
                        && maybe True (applicationMatchesQuery userMap row) qFilter
                )
                allRows
        items = map (jobApplicationValue userMap) rows
    case format of
        Just "csv" -> sendJobApplicationsCsv userMap rows
        _ ->
            returnJson $
                object
                    [ "items" .= items
                    , "statusCounts" .= statusCounts
                    ]

patchApiJobApplicationR :: JobId -> JobApplicationId -> Handler Value
patchApiJobApplicationR jobId applicationId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    job <- requireDbEntity jobId "job_not_found" "Job not found."
    requireJobApplicationManager viewerId (entityVal viewer) (entityVal job)
    application <- requireDbEntity applicationId "application_not_found" "Application not found."
    when (jobApplicationJob (entityVal application) /= jobId) $
        jsonError status404 "application_not_found" "Application not found."
    payload <- requireCheckJsonBody :: Handler UpdateJobApplicationPayload
    statusValue <- requireAllowedJobOption "invalid_application_status" "status" jobApplicationStatusOptions (updateJobApplicationStatus payload)
    validateApplicationRating (updateJobApplicationRating payload)
    now <- liftIO getCurrentTime
    runDB $
        update applicationId
            [ JobApplicationStatus =. statusValue
            , JobApplicationManagerNote =. normalizeOptionalText (updateJobApplicationManagerNote payload)
            , JobApplicationRating =. updateJobApplicationRating payload
            , JobApplicationUpdatedAt =. now
            ]
    updated <- requireDbEntity applicationId "application_not_found" "Application not found."
    when (jobApplicationApplicant (entityVal updated) /= viewerId) $
        runDB $ insert_ Notification
            { notificationUser = jobApplicationApplicant (entityVal updated)
            , notificationActor = Just viewerId
            , notificationKind = "job-application-status"
            , notificationPost = Nothing
            , notificationComment = Nothing
            , notificationJob = Just jobId
            , notificationIsRead = False
            , notificationCreatedAt = now
            }
    applicant <- requireDbEntity (jobApplicationApplicant (entityVal updated)) "user_not_found" "User not found."
    returnJson $
        object
            [ "application" .= jobApplicationValue (Map.singleton (entityKey applicant) (entityVal applicant)) updated
            ]

patchApiJobR :: JobId -> Handler Value
patchApiJobR jobId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    job <- requireDbEntity jobId "job_not_found" "Job not found."
    let currentJob = entityVal job
        canEdit = jobAuthor currentJob == viewerId || userRole (entityVal viewer) == ("admin" :: Text)
    unless canEdit $
        jsonError status403 "forbidden" "Not allowed."
    settingMap <- loadSettingMap
    unless (siteSettingBool "jobs_enabled" True settingMap) $
        jsonError status403 "jobs_disabled" "Jobs are currently disabled."
    payload <- requireCheckJsonBody :: Handler UpdateJobPayload
    let title = T.strip (updateJobTitle payload)
        company = T.strip (updateJobCompany payload)
        salary = normalizeOptionalText (updateJobSalary payload)
        salaryCurrency = normalizeOptionalText (updateJobSalaryCurrency payload)
        workingHours = normalizeOptionalText (updateJobWorkingHours payload)
        experience = normalizeOptionalText (updateJobExperience payload)
        applyUrl = normalizeOptionalText (updateJobApplyUrl payload)
        applyEmail = normalizeOptionalText (updateJobApplyEmail payload)
        content = T.strip (updateJobContent payload)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    employmentType <- requireAllowedJobOption "invalid_employment_type" "employmentType" jobEmploymentTypeOptions (updateJobEmploymentType payload)
    workplaceType <- requireOptionalAllowedJobOption "invalid_workplace_type" "workplaceType" jobWorkplaceTypeOptions (updateJobWorkplaceType payload)
    seniority <- requireOptionalAllowedJobOption "invalid_seniority" "seniority" jobSeniorityOptions (updateJobSeniority payload)
    salaryPeriod <- requireOptionalAllowedJobOption "invalid_salary_period" "salaryPeriod" jobSalaryPeriodOptions (updateJobSalaryPeriod payload)
    let skills = normalizeJobSkills (updateJobSkills payload)
        benefits = normalizeJobBenefits (updateJobBenefits payload)
    when (T.null title) $ jsonError status400 "invalid_title" "Title is required."
    when (T.null company) $ jsonError status400 "invalid_company" "Company is required."
    when (T.null content) $ jsonError status400 "invalid_content" "Content is required."
    validateSalaryRange (updateJobSalaryMin payload) (updateJobSalaryMax payload)
    when (textContainsBlockedTerm blockedWords (title <> " " <> company <> " " <> content)) $
        jsonError status400 "blocked_terms" "Content contains blocked terms."
    validateJobCompanyRef (updateJobCompanyId payload)
    (mLatitudeValue, mLongitudeValue) <- requireCoordinatePairJson (updateJobLatitude payload) (updateJobLongitude payload)
    now <- liftIO getCurrentTime
    runDB $ do
        update jobId
            [ JobTitle =. title
            , JobCompany =. company
            , JobCompanyRef =. updateJobCompanyId payload
            , JobSalary =. salary
            , JobSalaryMin =. updateJobSalaryMin payload
            , JobSalaryMax =. updateJobSalaryMax payload
            , JobSalaryCurrency =. salaryCurrency
            , JobSalaryPeriod =. salaryPeriod
            , JobWorkingHours =. workingHours
            , JobDeadline =. updateJobDeadline payload
            , JobExperience =. experience
            , JobSeniority =. seniority
            , JobEmploymentType =. employmentType
            , JobWorkplaceType =. workplaceType
            , JobApplyUrl =. applyUrl
            , JobApplyEmail =. applyEmail
            , JobLatitude =. mLatitudeValue
            , JobLongitude =. mLongitudeValue
            , JobContent =. content
            , JobUpdatedAt =. now
            ]
        replaceJobMeta jobId skills benefits
    updated <- requireDbEntity jobId "job_not_found" "Job not found."
    (skillMap, benefitMap, applicationCountMap, viewerAppliedMap) <- loadJobMeta (Just (Entity viewerId (entityVal viewer))) [jobId]
    authors <-
        if viewerId == jobAuthor (entityVal updated)
            then pure (Map.singleton viewerId (entityVal viewer))
            else do
                author <- requireDbEntity (jobAuthor (entityVal updated)) "user_not_found" "User not found."
                pure (Map.singleton (entityKey author) (entityVal author))
    returnJson $
        object
            [ "job" .= jobValueWithMeta skillMap benefitMap applicationCountMap viewerAppliedMap authors (max 0 (siteSettingInt "job_auto_close_days" 0 settingMap)) updated
            ]

deleteApiJobR :: JobId -> Handler Value
deleteApiJobR jobId = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    job <- requireDbEntity jobId "job_not_found" "Job not found."
    let currentJob = entityVal job
        canDelete = jobAuthor currentJob == viewerId || userRole (entityVal viewer) == ("admin" :: Text)
    unless canDelete $
        jsonError status403 "forbidden" "Not allowed."
    runDB $ do
        deleteWhere [JobSkillJob ==. jobId]
        deleteWhere [JobBenefitJob ==. jobId]
        deleteWhere [JobApplicationJob ==. jobId]
        deleteWhere [NotificationJob ==. Just jobId]
        delete jobId
    returnJson $ object ["message" .= ("Job post deleted." :: Text)]

jobEmploymentTypeOptions :: [Text]
jobEmploymentTypeOptions =
    [ "full_time"
    , "part_time"
    , "contract"
    , "temporary"
    , "internship"
    , "freelance"
    , "casual"
    ]

jobWorkplaceTypeOptions :: [Text]
jobWorkplaceTypeOptions =
    ["on_site", "hybrid", "remote"]

jobSeniorityOptions :: [Text]
jobSeniorityOptions =
    ["entry", "junior", "mid", "senior", "lead"]

jobSalaryPeriodOptions :: [Text]
jobSalaryPeriodOptions =
    ["hourly", "monthly", "annual"]

jobApplicationStatusOptions :: [Text]
jobApplicationStatusOptions =
    ["submitted", "reviewing", "accepted", "rejected", "withdrawn"]

data EmployerPlan = EmployerPlan
    { employerPlanKey :: Text
    , employerPlanName :: Text
    , employerPlanMonthlyPrice :: Maybe Int
    , employerPlanMonthlyJobLimit :: Maybe Int
    , employerPlanDescription :: Text
    }

employerPlans :: [EmployerPlan]
employerPlans =
    [ EmployerPlan "starter" "Starter" (Just 100000) (Just 3) "월 10만원 · 구인 공고 3개"
    , EmployerPlan "growth" "Growth" (Just 300000) (Just 10) "월 30만원 · 구인 공고 10개"
    , EmployerPlan "scale" "Scale" (Just 500000) (Just 20) "월 50만원 · 구인 공고 20개"
    , EmployerPlan "enterprise" "Enterprise" Nothing Nothing "20개 초과는 협의"
    ]

employerPlanValue :: EmployerPlan -> Value
employerPlanValue plan =
    object
        [ "key" .= employerPlanKey plan
        , "name" .= employerPlanName plan
        , "monthlyPrice" .= employerPlanMonthlyPrice plan
        , "monthlyJobLimit" .= employerPlanMonthlyJobLimit plan
        , "description" .= employerPlanDescription plan
        ]

lookupEmployerPlan :: Maybe Text -> EmployerPlan
lookupEmployerPlan mPlanKey =
    fromMaybe defaultEmployerPlan $
        mPlanKey >>= \planKey -> L.find ((== planKey) . employerPlanKey) employerPlans

defaultEmployerPlan :: EmployerPlan
defaultEmployerPlan = EmployerPlan "starter" "Starter" (Just 100000) (Just 3) "월 10만원 · 구인 공고 3개"

ensureEmployerAccess :: UserId -> User -> Handler ()
ensureEmployerAccess _ viewer =
    unless (userRole viewer == ("admin" :: Text) || userAccountType viewer == ("employer" :: Text)) $
        jsonError status403 "employer_required" "Employer membership is required."

enforceEmployerPostingQuota :: UserId -> User -> Handler ()
enforceEmployerPostingQuota viewerId viewer = do
    ensureEmployerAccess viewerId viewer
    unless (userRole viewer == ("admin" :: Text)) $ do
        now <- liftIO getCurrentTime
        quota <- employerQuota viewerId viewer now
        case employerQuotaLimit quota of
            Nothing -> pure ()
            Just limitValue ->
                when (employerQuotaUsed quota >= limitValue) $
                    jsonError status402 "job_quota_exceeded" "Monthly job posting quota exceeded."

data EmployerQuota = EmployerQuota
    { employerQuotaPlan :: EmployerPlan
    , employerQuotaUsed :: Int
    , employerQuotaLimit :: Maybe Int
    , employerQuotaPeriodStart :: Day
    }

employerQuota :: UserId -> User -> UTCTime -> Handler EmployerQuota
employerQuota viewerId viewer now = do
    let plan = lookupEmployerPlan (userEmployerPlan viewer)
        (year, month, _) = toGregorian (utctDay now)
        periodStart = fromGregorian year month 1
    used <- runDB $ count [JobAuthor ==. viewerId, JobCreatedAt >=. UTCTime periodStart 0]
    pure $
        EmployerQuota
            { employerQuotaPlan = plan
            , employerQuotaUsed = used
            , employerQuotaLimit = employerPlanMonthlyJobLimit plan
            , employerQuotaPeriodStart = periodStart
            }

employerQuotaValue :: UserId -> User -> UTCTime -> Handler Value
employerQuotaValue viewerId viewer now = do
    quota <- employerQuota viewerId viewer now
    pure $
        object
            [ "plan" .= employerPlanValue (employerQuotaPlan quota)
            , "usedThisMonth" .= employerQuotaUsed quota
            , "monthlyJobLimit" .= employerQuotaLimit quota
            , "periodStart" .= employerQuotaPeriodStart quota
            ]

requireAllowedJobOption :: Text -> Text -> [Text] -> Text -> Handler Text
requireAllowedJobOption errCode fieldName allowedValues raw = do
    let value = T.toLower $ T.strip raw
    when (T.null value) $
        jsonError status400 errCode (fieldName <> " is required.")
    unless (value `elem` allowedValues) $
        jsonError status400 errCode (fieldName <> " is invalid.")
    pure value

requireOptionalAllowedJobOption :: Text -> Text -> [Text] -> Maybe Text -> Handler (Maybe Text)
requireOptionalAllowedJobOption _ _ _ Nothing = pure Nothing
requireOptionalAllowedJobOption errCode fieldName allowedValues (Just raw) = do
    let value = T.toLower $ T.strip raw
    if T.null value
        then pure Nothing
        else do
            unless (value `elem` allowedValues) $
                jsonError status400 errCode (fieldName <> " is invalid.")
            pure (Just value)

lookupOptionalAllowedJobQueryParam :: Text -> Text -> [Text] -> Handler (Maybe Text)
lookupOptionalAllowedJobQueryParam errCode fieldName allowedValues = do
    raw <- lookupGetParam fieldName
    requireOptionalAllowedJobOption errCode fieldName allowedValues raw

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

lookupOptionalTextQueryParam :: Text -> Handler (Maybe Text)
lookupOptionalTextQueryParam fieldName = do
    raw <- fmap T.strip <$> lookupGetParam fieldName
    pure $ normalizeOptionalText raw

validateSalaryRange :: Maybe Int -> Maybe Int -> Handler ()
validateSalaryRange mMin mMax = do
    forM_ mMin $ \minValue ->
        when (minValue < 0) $
            jsonError status400 "invalid_salary_range" "salaryMin must be zero or greater."
    forM_ mMax $ \maxValue ->
        when (maxValue < 0) $
            jsonError status400 "invalid_salary_range" "salaryMax must be zero or greater."
    case (mMin, mMax) of
        (Just minValue, Just maxValue) | minValue > maxValue ->
            jsonError status400 "invalid_salary_range" "salaryMin must be less than or equal to salaryMax."
        _ ->
            pure ()

validateJobCompanyRef :: Maybe CompanyId -> Handler ()
validateJobCompanyRef Nothing = pure ()
validateJobCompanyRef (Just companyId) =
    void $ requireDbEntity companyId "company_not_found" "Company not found."

autoCloseExpiredJobs :: Handler ()
autoCloseExpiredJobs = do
    now <- liftIO getCurrentTime
    let today = utctDay now
    runDB $
        updateWhere
            [ JobIsClosed ==. False
            , JobDeadline <. Just today
            ]
            [ JobIsClosed =. True
            , JobClosedAt =. Just now
            , JobUpdatedAt =. now
            ]

requireJobApplicationManager :: UserId -> User -> Job -> Handler ()
requireJobApplicationManager viewerId viewer job = do
    let allowed = jobAuthor job == viewerId || userRole viewer == ("admin" :: Text)
    unless allowed $
        jsonError status403 "forbidden" "Only the job author or admin can manage applications."

normalizeJobSkills :: [Text] -> [Text]
normalizeJobSkills =
    P.take 20 . L.nub . map (T.toLower . T.strip) . filter (not . T.null . T.strip)

normalizeJobBenefits :: [Text] -> [Text]
normalizeJobBenefits =
    P.take 20 . L.nub . map T.strip . filter (not . T.null . T.strip)

replaceJobMeta :: JobId -> [Text] -> [Text] -> ReaderT SqlBackend Handler ()
replaceJobMeta jobId skills benefits = do
    deleteWhere [JobSkillJob ==. jobId]
    deleteWhere [JobBenefitJob ==. jobId]
    insertMany_ $
        zipWith
            (\indexValue name ->
                JobSkill
                    { jobSkillJob = jobId
                    , jobSkillName = name
                    , jobSkillSortOrder = indexValue
                    }
            )
            [0..]
            skills
    insertMany_ $
        zipWith
            (\indexValue name ->
                JobBenefit
                    { jobBenefitJob = jobId
                    , jobBenefitName = name
                    , jobBenefitSortOrder = indexValue
                    }
            )
            [0..]
            benefits

loadJobMeta :: Maybe (Entity User) -> [JobId] -> Handler (Map.Map JobId [Text], Map.Map JobId [Text], Map.Map JobId Int, Map.Map JobId Bool)
loadJobMeta _ [] = pure (Map.empty, Map.empty, Map.empty, Map.empty)
loadJobMeta mViewer jobIds = do
    skillRows <- runDB $ selectList [JobSkillJob <-. jobIds] [Asc JobSkillSortOrder]
    benefitRows <- runDB $ selectList [JobBenefitJob <-. jobIds] [Asc JobBenefitSortOrder]
    applicationRows <- runDB $ selectList [JobApplicationJob <-. jobIds] []
    let skillMap = appendTextMap jobSkillJob jobSkillName skillRows
        benefitMap = appendTextMap jobBenefitJob jobBenefitName benefitRows
        applicationCountMap = P.foldl' (\acc row -> Map.insertWith (+) (jobApplicationJob (entityVal row)) 1 acc) Map.empty applicationRows
        viewerAppliedMap =
            case mViewer of
                Nothing -> Map.empty
                Just (Entity viewerId _) ->
                    P.foldl'
                        (\acc row ->
                            if jobApplicationApplicant (entityVal row) == viewerId
                                then Map.insert (jobApplicationJob (entityVal row)) True acc
                                else acc
                        )
                        Map.empty
                        applicationRows
    pure (skillMap, benefitMap, applicationCountMap, viewerAppliedMap)

appendTextMap :: Ord key => (value -> key) -> (value -> Text) -> [Entity value] -> Map.Map key [Text]
appendTextMap keyFn valueFn =
    P.foldl'
        (\acc row ->
            let value = entityVal row
                key = keyFn value
            in Map.insertWith (P.flip (<>)) key [valueFn value] acc
        )
        Map.empty

jobApplicationValue :: Map.Map UserId User -> Entity JobApplication -> Value
jobApplicationValue userMap (Entity applicationId application) =
    let applicantId = jobApplicationApplicant application
    in object
        [ "id" .= keyToInt applicationId
        , "jobId" .= keyToInt (jobApplicationJob application)
        , "applicant" .= maybe Null (\user -> userRefValue (Entity applicantId user)) (Map.lookup applicantId userMap)
        , "note" .= jobApplicationNote application
        , "managerNote" .= jobApplicationManagerNote application
        , "rating" .= jobApplicationRating application
        , "status" .= jobApplicationStatus application
        , "createdAt" .= jobApplicationCreatedAt application
        , "updatedAt" .= jobApplicationUpdatedAt application
        ]

validateApplicationRating :: Maybe Int -> Handler ()
validateApplicationRating Nothing = pure ()
validateApplicationRating (Just rating) =
    unless (rating >= 1 && rating <= 5) $
        jsonError status400 "invalid_application_rating" "rating must be between 1 and 5."

jobApplicationStatusCounts :: [Entity JobApplication] -> Value
jobApplicationStatusCounts rows =
    object $
        map
            (\statusValue ->
                Key.fromText statusValue .= P.length (filter ((== statusValue) . jobApplicationStatus . entityVal) rows)
            )
            jobApplicationStatusOptions

applicationMatchesQuery :: Map.Map UserId User -> Entity JobApplication -> Text -> Bool
applicationMatchesQuery userMap (Entity _ application) query =
    let normalizedQuery = T.toLower $ T.strip query
        applicantText =
            maybe "" (\user -> userIdent user <> " " <> fromMaybe "" (userName user)) $
                Map.lookup (jobApplicationApplicant application) userMap
        noteText = fromMaybe "" (jobApplicationNote application)
        managerNoteText = fromMaybe "" (jobApplicationManagerNote application)
    in T.null normalizedQuery || normalizedQuery `T.isInfixOf` T.toLower (applicantText <> " " <> noteText <> " " <> managerNoteText)

sendJobApplicationsCsv :: Map.Map UserId User -> [Entity JobApplication] -> Handler Value
sendJobApplicationsCsv userMap rows = do
    addHeader "Content-Disposition" "attachment; filename=\"job-applications.csv\""
    sendResponse (TypedContent "text/csv; charset=utf-8" (toContent csvText))
  where
    csvText =
        TL.fromStrict $
            T.unlines $
                "id,applicant,status,rating,note,manager_note,created_at,updated_at"
                    : map csvRow rows
    csvRow (Entity applicationId application) =
        T.intercalate
            ","
            [ csvCell (T.pack $ show $ keyToInt applicationId)
            , csvCell $ maybe "" userIdent (Map.lookup (jobApplicationApplicant application) userMap)
            , csvCell $ jobApplicationStatus application
            , csvCell $ maybe "" (T.pack . show) (jobApplicationRating application)
            , csvCell $ fromMaybe "" (jobApplicationNote application)
            , csvCell $ fromMaybe "" (jobApplicationManagerNote application)
            , csvCell $ T.pack $ show $ jobApplicationCreatedAt application
            , csvCell $ T.pack $ show $ jobApplicationUpdatedAt application
            ]
    csvCell value =
        "\"" <> T.replace "\"" "\"\"" value <> "\""
