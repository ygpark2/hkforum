{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Auth where

import Auth.Jwt (issueJwt)
import qualified Data.Text as T
import Handler.Api.Common
import Import
import SiteSettings
import Yesod.Auth.HashDB (setPassword, validatePass)
import qualified Prelude as P

postApiAuthRegisterR :: Handler Value
postApiAuthRegisterR = do
    payload <- requireCheckJsonBody :: Handler AuthPayload
    settingMap <- loadSettingMap
    unless (siteSettingBool "allow_user_registration" True settingMap) $
        jsonError status403 "registration_disabled" "Registration is currently disabled."
    let username = T.strip (authPayloadUsername payload)
        password = authPayloadPassword payload
        accountType = T.toLower $ T.strip (authPayloadAccountType payload)
        employerPlan = normalizeOptionalText (authPayloadEmployerPlan payload)
        realEstatePlan = normalizeOptionalText (authPayloadRealEstatePlan payload)
    when (T.null username) $
        jsonError status400 "invalid_username" "Username is required."
    when (T.null password) $
        jsonError status400 "invalid_password" "Password is required."
    unless (accountType `P.elem` ["personal", "employer", "real_estate"]) $
        jsonError status400 "invalid_account_type" "accountType is invalid."
    when (accountType == "employer" && maybe True (`P.notElem` employerPlanKeys) employerPlan) $
        jsonError status400 "invalid_employer_plan" "employerPlan is invalid."
    when (accountType == "real_estate" && maybe True (`P.notElem` realEstatePlanKeys) realEstatePlan) $
        jsonError status400 "invalid_real_estate_plan" "realEstatePlan is invalid."
    existing <- runDB $ getBy $ UniqueUser username
    case existing of
        Just _ -> jsonError status400 "user_exists" "Username already exists."
        Nothing -> do
            now <- liftIO getCurrentTime
            let normalizedPlan =
                    if accountType == "employer"
                        then Just (fromMaybe "starter" employerPlan)
                        else Nothing
                planStartedAt =
                    if accountType == "employer" then Just now else Nothing
                normalizedRealEstatePlan =
                    if accountType == "real_estate"
                        then Just (fromMaybe "starter" realEstatePlan)
                        else Nothing
                realEstatePlanStartedAt =
                    if accountType == "real_estate" then Just now else Nothing
            user <- liftIO $ setPassword password (User username Nothing "user" Nothing Nothing Nothing Nothing False Nothing Nothing Nothing accountType normalizedPlan planStartedAt normalizedRealEstatePlan realEstatePlanStartedAt)
            userId <- runDB $ insert user
            setCreds False (Creds "hashdb" username [])
            created <- requireDbEntity userId "user_not_found" "User not found."
            settings <- getsYesod appSettings
            let token = issueJwt settings (keyToInt userId) now
            sendResponseStatus status201 $
                object
                    [ "message" .= ("Registration successful." :: Text)
                    , "token" .= token
                    , "user" .= userProfileValue Nothing created 0 0 Nothing
                    ]

postApiAuthLoginR :: Handler Value
postApiAuthLoginR = do
    payload <- requireCheckJsonBody :: Handler AuthPayload
    let username = T.strip (authPayloadUsername payload)
        password = authPayloadPassword payload
    when (T.null username || T.null password) $
        jsonError status400 "invalid_credentials" "Username and password are required."
    existing <- runDB $ getBy $ UniqueUser username
    case existing of
        Nothing -> jsonError status401 "invalid_credentials" "Invalid username or password."
        Just (Entity userId user) ->
            case validatePass user password of
                Just True -> do
                    setCreds False (Creds "hashdb" username [])
                    followerCount <- runDB $ count [UserFollowFollowing ==. userId]
                    followingCount <- runDB $ count [UserFollowFollower ==. userId]
                    settings <- getsYesod appSettings
                    now <- liftIO getCurrentTime
                    let token = issueJwt settings (keyToInt userId) now
                    returnJson $
                        object
                            [ "message" .= ("Login successful." :: Text)
                            , "token" .= token
                            , "user" .= userProfileValue Nothing (Entity userId user) followerCount followingCount Nothing
                            ]
                _ -> jsonError status401 "invalid_credentials" "Invalid username or password."

postApiAuthLogoutR :: Handler Value
postApiAuthLogoutR = do
    clearCreds False
    returnJson $ object ["message" .= ("Logout successful." :: Text)]

employerPlanKeys :: [Text]
employerPlanKeys = ["starter", "growth", "scale", "enterprise"]

realEstatePlanKeys :: [Text]
realEstatePlanKeys = ["starter", "growth", "scale", "enterprise"]
