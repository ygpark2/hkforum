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
    let localRegionFilterEnabled = maybe False (userLocalRegionOnly . entityVal) mViewer
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
    jobs <-
        case (localRegionFilterEnabled, mActiveLocalRegion) of
            (True, Nothing) -> pure []
            (True, Just (countryCodeValue, stateValue)) ->
                runDB $ selectList [JobCountryCode ==. Just countryCodeValue, JobState ==. Just stateValue] [Desc JobCreatedAt]
            (False, _) ->
                runDB $ selectList [] [Desc JobCreatedAt]
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
    companiesList <- runDB $ selectList [] [Asc CompanyName]
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Jobs"
        $(widgetFile "job/jobs")

postJobsR :: Handler Html
postJobsR = do
    userId <- requireAuthId
    user <- runDB $ get404 userId
    titleRaw <- runInputPost $ ireq textField "title"
    companyRaw <- runInputPost $ ireq textField "company"
    mSalaryRaw <- runInputPost $ iopt textField "salary"
    mWorkingHoursRaw <- runInputPost $ iopt textField "workingHours"
    mDeadline <- runInputPost $ iopt dayField "deadline"
    mExperienceRaw <- runInputPost $ iopt textField "experience"
    mEmploymentTypeRaw <- runInputPost $ iopt textField "employmentType"
    mLatitude <- runInputPost $ iopt doubleField "latitude"
    mLongitude <- runInputPost $ iopt doubleField "longitude"
    contentRaw <- runInputPost $ ireq textField "content"
    let title = T.strip titleRaw
        company = T.strip companyRaw
        mSalary = normalizeOptionalText mSalaryRaw
        mWorkingHours = normalizeOptionalText mWorkingHoursRaw
        mExperience = normalizeOptionalText mExperienceRaw
        mEmploymentType = normalizeOptionalText mEmploymentTypeRaw
        content = T.strip contentRaw
    when (T.null title) $ invalidArgs ["title is required"]
    when (T.null company) $ invalidArgs ["company is required"]
    when (T.null content) $ invalidArgs ["content is required"]
    (mLatitudeValue, mLongitudeValue) <- requireCoordinatePair mLatitude mLongitude
    let (mCountryCodeValue, mStateValue) = userRegionFields user
    now <- liftIO getCurrentTime
    _ <- runDB $ insert Job
        { jobTitle = title
        , jobCompany = company
        , jobSalary = mSalary
        , jobWorkingHours = mWorkingHours
        , jobDeadline = mDeadline
        , jobIsClosed = False
        , jobExperience = mExperience
        , jobEmploymentType = mEmploymentType
        , jobCountryCode = mCountryCodeValue
        , jobState = mStateValue
        , jobLatitude = mLatitudeValue
        , jobLongitude = mLongitudeValue
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
