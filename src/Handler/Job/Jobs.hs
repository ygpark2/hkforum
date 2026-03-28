{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Job.Jobs (getJobsR, postJobsR, postJobCloseR) where

import Import
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Data.Time (diffUTCTime)
import qualified Prelude as P
import Text.Blaze (preEscapedText)

getJobsR :: Handler Html
getJobsR = do
    req <- getRequest
    let mCsrfToken = reqToken req
    mViewer <- maybeAuth
    jobs <- runDB $ selectList [] [Desc JobCreatedAt]
    now <- liftIO getCurrentTime
    let today = utctDay now
        mViewerId = entityKey <$> mViewer
        viewerIsAdmin = maybe False (\(Entity _ user) -> userRole user == ("admin" :: Text)) mViewer
    let authorIds = L.nub $ map (jobAuthor . entityVal) jobs
    users <-
        if P.null authorIds
            then pure []
            else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        authorHandle uid = T.toLower $ T.filter (/= ' ') (authorName uid)
        isClosedByDeadline job = maybe False (< today) (jobDeadline job)
        isClosedNow job = jobIsClosed job || isClosedByDeadline job
        canCloseJob job =
            case mViewerId of
                Nothing -> False
                Just viewerId -> viewerId == jobAuthor job || viewerIsAdmin
        relativeTime ts =
            let minutes = floor (diffUTCTime now ts / 60) :: Int
                hours = minutes `div` 60
                days = hours `div` 24
            in if minutes < 60 then tshow minutes <> " min ago"
               else if hours < 24 then tshow hours <> " hours ago"
               else if days < 30 then tshow days <> " days ago"
               else tshow $ formatTime defaultTimeLocale "%b %e, %Y" ts
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Jobs"
        $(widgetFile "forum/jobs")

postJobsR :: Handler Html
postJobsR = do
    userId <- requireAuthId
    titleRaw <- runInputPost $ ireq textField "title"
    companyRaw <- runInputPost $ ireq textField "company"
    mSalaryRaw <- runInputPost $ iopt textField "salary"
    mWorkingHoursRaw <- runInputPost $ iopt textField "workingHours"
    mDeadline <- runInputPost $ iopt dayField "deadline"
    mExperienceRaw <- runInputPost $ iopt textField "experience"
    mLocationRaw <- runInputPost $ iopt textField "location"
    mEmploymentTypeRaw <- runInputPost $ iopt textField "employmentType"
    contentRaw <- runInputPost $ ireq textField "content"
    let title = T.strip titleRaw
        company = T.strip companyRaw
        mSalary = normalizeOptionalText mSalaryRaw
        mWorkingHours = normalizeOptionalText mWorkingHoursRaw
        mExperience = normalizeOptionalText mExperienceRaw
        mLocation = normalizeOptionalText mLocationRaw
        mEmploymentType = normalizeOptionalText mEmploymentTypeRaw
        content = T.strip contentRaw
    when (T.null title) $ invalidArgs ["title is required"]
    when (T.null company) $ invalidArgs ["company is required"]
    when (T.null content) $ invalidArgs ["content is required"]
    now <- liftIO getCurrentTime
    _ <- runDB $ insert Job
        { jobTitle = title
        , jobCompany = company
        , jobSalary = mSalary
        , jobWorkingHours = mWorkingHours
        , jobDeadline = mDeadline
        , jobIsClosed = False
        , jobExperience = mExperience
        , jobLocation = mLocation
        , jobEmploymentType = mEmploymentType
        , jobContent = content
        , jobAuthor = userId
        , jobCreatedAt = now
        , jobUpdatedAt = now
        }
    setMessage "Job post created."
    redirect JobsR

postJobCloseR :: JobId -> Handler Html
postJobCloseR jobId = do
    viewerId <- requireAuthId
    now <- liftIO getCurrentTime
    job <- runDB $ get404 jobId
    viewer <- runDB $ get404 viewerId
    let canClose = jobAuthor job == viewerId || userRole viewer == ("admin" :: Text)
    unless canClose $ permissionDenied "Only the author or admin can close this job."
    runDB $ update jobId [JobIsClosed =. True, JobUpdatedAt =. now]
    setMessage "Job post closed."
    redirect JobsR

normalizeOptionalText :: Maybe Text -> Maybe Text
normalizeOptionalText Nothing = Nothing
normalizeOptionalText (Just raw) =
    let trimmed = T.strip raw
    in if T.null trimmed then Nothing else Just trimmed
