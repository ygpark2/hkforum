{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Handler.User.Profile
    ( getProfileR
    , postProfileR
    ) where

import Import
import qualified Data.Text as T
import Text.Blaze (preEscapedText)

getProfileR :: Handler Html
getProfileR = do
    userId <- requireAuthId
    user <- runDB $ get404 userId
    req <- getRequest
    let mCsrfToken = reqToken req
    renderProfilePage user mCsrfToken Nothing

postProfileR :: Handler Html
postProfileR = do
    userId <- requireAuthId
    user <- runDB $ get404 userId
    req <- getRequest
    let mCsrfToken = reqToken req
    mNameRaw <- runInputPost $ iopt textField "name"
    mDescriptionRaw <- runInputPost $ iopt textField "description"
    countryCodeRaw <- runInputPost $ ireq textField "countryCode"
    stateRaw <- runInputPost $ ireq textField "state"
    mLocalRegionOnlyRaw <- runInputPost $ iopt textField "localRegionOnly"
    mLatitude <- runInputPost $ iopt doubleField "latitude"
    mLongitude <- runInputPost $ iopt doubleField "longitude"
    let nameValue = normalizeOptionalText mNameRaw
        descriptionValue = normalizeOptionalText mDescriptionRaw
        countryCodeValue = T.toUpper (T.strip countryCodeRaw)
        stateValue = T.strip stateRaw
        localRegionOnlyValue = isJust mLocalRegionOnlyRaw
    validationResult <- validateProfileInput countryCodeValue stateValue mLatitude mLongitude
    case validationResult of
        Left err ->
            renderProfilePage
                user
                    { userName = nameValue
                    , userDescription = descriptionValue
                    , userCountryCode = Just countryCodeValue
                    , userState = Just stateValue
                    , userLocalRegionOnly = localRegionOnlyValue
                    , userLatitude = mLatitude
                    , userLongitude = mLongitude
                    }
                mCsrfToken
                (Just err)
        Right (mLatitudeValue, mLongitudeValue) -> do
            runDB $ update userId
                [ UserName =. nameValue
                , UserDescription =. descriptionValue
                , UserCountryCode =. Just countryCodeValue
                , UserState =. Just stateValue
                , UserLocalRegionOnly =. localRegionOnlyValue
                , UserLatitude =. mLatitudeValue
                , UserLongitude =. mLongitudeValue
                ]
            setMessage "Profile updated."
            redirect ProfileR

renderProfilePage :: User -> Maybe Text -> Maybe Text -> Handler Html
renderProfilePage user mCsrfToken formError = do
    (profileCountries, profileCountryStates) <- loadProfileRegionOptions
    let defaultCountryCode =
            fromMaybe "" $
                listToMaybe [countryCode country | Entity _ country <- profileCountries]
        effectiveCountryCode =
            case userCountryCode user of
                Just code | not (T.null code) -> code
                _ -> defaultCountryCode
        defaultStateCode =
            fromMaybe "" $
                listToMaybe
                    [ countryStateCode stateRow
                    | Entity _ stateRow <- profileCountryStates
                    , countryStateCountryCode stateRow == effectiveCountryCode
                    ]
        effectiveStateCode =
            case userState user of
                Just code | not (T.null code) -> code
                _ -> defaultStateCode
        profileNameValue = fromMaybe "" (userName user)
        profileDescriptionValue = fromMaybe "" (userDescription user)
        profileCountryCodeValue = effectiveCountryCode
        profileStateValue = effectiveStateCode
        profileLocalRegionOnlyValue = userLocalRegionOnly user
        profileLatitudeValue = maybe "" (\value -> T.pack (show value)) (userLatitude user)
        profileLongitudeValue = maybe "" (\value -> T.pack (show value)) (userLongitude user)
        profileLocationSummary = coordinateSummary (userLatitude user) (userLongitude user)
    defaultLayout $ do
        setTitle $ preEscapedText "Edit profile"
        $(widgetFile "profile")

validateProfileInput
    :: Text
    -> Text
    -> Maybe Double
    -> Maybe Double
    -> Handler (Either Text (Maybe Double, Maybe Double))
validateProfileInput countryCodeValue stateValue mLatitude mLongitude
    | T.null countryCodeValue = pure (Left "Country is required.")
    | T.null stateValue = pure (Left "State is required.")
    | otherwise = do
        mCountry <- runDB $ getBy $ UniqueCountryCode countryCodeValue
        case mCountry of
            Nothing -> pure (Left "Choose a valid country.")
            Just _ -> do
                mState <- runDB $ getBy $ UniqueCountryStateCode countryCodeValue stateValue
                case mState of
                    Nothing -> pure (Left "Choose a valid state for the selected country.")
                    Just _ -> pure (validateCoordinatePair mLatitude mLongitude)

validateCoordinatePair :: Maybe Double -> Maybe Double -> Either Text (Maybe Double, Maybe Double)
validateCoordinatePair Nothing Nothing = Right (Nothing, Nothing)
validateCoordinatePair (Just lat) (Just lng) = Right (Just lat, Just lng)
validateCoordinatePair _ _ = Left "Latitude and longitude must be provided together."

normalizeOptionalText :: Maybe Text -> Maybe Text
normalizeOptionalText Nothing = Nothing
normalizeOptionalText (Just raw) =
    let trimmed = T.strip raw
    in if T.null trimmed then Nothing else Just trimmed

coordinateSummary :: Maybe Double -> Maybe Double -> Text
coordinateSummary (Just lat) (Just lng) = T.pack (show lat) <> ", " <> T.pack (show lng)
coordinateSummary _ _ = "No coordinates selected"

loadProfileRegionOptions :: Handler ([Entity Country], [Entity CountryState])
loadProfileRegionOptions =
    runDB $ do
        countries <- selectList [] [Asc CountrySortOrder, Asc CountryCode]
        states <- selectList [] [Asc CountryStateCountryCode, Asc CountryStateSortOrder, Asc CountryStateCode]
        pure (countries, states)
