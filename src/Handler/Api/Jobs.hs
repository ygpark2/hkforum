{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Jobs where

import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
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
    (page, size, offset) <- paginationParams
    mViewer <- maybeApiAuth
    let baseFilters =
            case activeRegionFilter mViewer of
                RegionFilterUnavailable -> []
                RegionFilterDisabled -> []
                RegionFilterEnabled countryCodeValue stateValue ->
                    [ JobCountryCode ==. Just countryCodeValue
                    , JobState ==. Just stateValue
                    ]
    jobs <- case activeRegionFilter mViewer of
        RegionFilterUnavailable -> pure []
        _ -> runDB $ selectList baseFilters [Desc JobCreatedAt, OffsetBy offset, LimitTo (size + 1)]
    let hasNext = P.length jobs > size
        pageRows = P.take size jobs
        authorIds = L.nub $ map (jobAuthor . entityVal) pageRows
    users <- if P.null authorIds then pure [] else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, user)) users
        jobAutoCloseDays = max 0 (siteSettingInt "job_auto_close_days" 0 settingMap)
        items = map (jobValue userMap jobAutoCloseDays) pageRows
    returnJson $
        object
            [ "items" .= items
            , "page" .= page
            , "size" .= size
            , "hasNext" .= hasNext
            ]

postApiJobsR :: Handler Value
postApiJobsR = do
    viewerId <- requireApiAuthId
    viewer <- requireDbEntity viewerId "user_not_found" "User not found."
    settingMap <- loadSettingMap
    unless (siteSettingBool "jobs_enabled" True settingMap) $
        jsonError status403 "jobs_disabled" "Jobs are currently disabled."
    payload <- requireCheckJsonBody :: Handler CreateJobPayload
    let title = T.strip (createJobTitle payload)
        company = T.strip (createJobCompany payload)
        salary = normalizeOptionalText (createJobSalary payload)
        workingHours = normalizeOptionalText (createJobWorkingHours payload)
        experience = normalizeOptionalText (createJobExperience payload)
        employmentType = normalizeOptionalText (createJobEmploymentType payload)
        content = T.strip (createJobContent payload)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    when (T.null title) $ jsonError status400 "invalid_title" "Title is required."
    when (T.null company) $ jsonError status400 "invalid_company" "Company is required."
    when (T.null content) $ jsonError status400 "invalid_content" "Content is required."
    when (textContainsBlockedTerm blockedWords (title <> " " <> company <> " " <> content)) $
        jsonError status400 "blocked_terms" "Content contains blocked terms."
    (mLatitudeValue, mLongitudeValue) <- requireCoordinatePairJson (createJobLatitude payload) (createJobLongitude payload)
    let (mCountryCodeValue, mStateValue) = userRegionFields (entityVal viewer)
    now <- liftIO getCurrentTime
    jobId <- runDB $ insert Job
        { jobTitle = title
        , jobCompany = company
        , jobSalary = salary
        , jobWorkingHours = workingHours
        , jobDeadline = createJobDeadline payload
        , jobIsClosed = False
        , jobExperience = experience
        , jobEmploymentType = employmentType
        , jobCountryCode = mCountryCodeValue
        , jobState = mStateValue
        , jobLatitude = mLatitudeValue
        , jobLongitude = mLongitudeValue
        , jobContent = content
        , jobAuthor = viewerId
        , jobCreatedAt = now
        , jobUpdatedAt = now
        }
    created <- requireDbEntity jobId "job_not_found" "Job not found."
    sendResponseStatus status201 $
        object
            [ "job" .= jobValue (Map.singleton viewerId (entityVal viewer)) (max 0 (siteSettingInt "job_auto_close_days" 0 settingMap)) created
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
    runDB $ update jobId [JobIsClosed =. True, JobUpdatedAt =. now]
    returnJson $ object ["message" .= ("Job post closed." :: Text)]

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
        workingHours = normalizeOptionalText (updateJobWorkingHours payload)
        experience = normalizeOptionalText (updateJobExperience payload)
        employmentType = normalizeOptionalText (updateJobEmploymentType payload)
        content = T.strip (updateJobContent payload)
        blockedWords = siteSettingCsv "blocked_words" settingMap
    when (T.null title) $ jsonError status400 "invalid_title" "Title is required."
    when (T.null company) $ jsonError status400 "invalid_company" "Company is required."
    when (T.null content) $ jsonError status400 "invalid_content" "Content is required."
    when (textContainsBlockedTerm blockedWords (title <> " " <> company <> " " <> content)) $
        jsonError status400 "blocked_terms" "Content contains blocked terms."
    (mLatitudeValue, mLongitudeValue) <- requireCoordinatePairJson (updateJobLatitude payload) (updateJobLongitude payload)
    now <- liftIO getCurrentTime
    runDB $
        update jobId
            [ JobTitle =. title
            , JobCompany =. company
            , JobSalary =. salary
            , JobWorkingHours =. workingHours
            , JobDeadline =. updateJobDeadline payload
            , JobExperience =. experience
            , JobEmploymentType =. employmentType
            , JobLatitude =. mLatitudeValue
            , JobLongitude =. mLongitudeValue
            , JobContent =. content
            , JobUpdatedAt =. now
            ]
    updated <- requireDbEntity jobId "job_not_found" "Job not found."
    authors <-
        if viewerId == jobAuthor (entityVal updated)
            then pure (Map.singleton viewerId (entityVal viewer))
            else do
                author <- requireDbEntity (jobAuthor (entityVal updated)) "user_not_found" "User not found."
                pure (Map.singleton (entityKey author) (entityVal author))
    returnJson $
        object
            [ "job" .= jobValue authors (max 0 (siteSettingInt "job_auto_close_days" 0 settingMap)) updated
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
    runDB $ delete jobId
    returnJson $ object ["message" .= ("Job post deleted." :: Text)]
