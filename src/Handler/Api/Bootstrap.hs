{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Bootstrap
    ( getApiBootstrapR
    ) where

import Company.Categories (companyMajorCategoryName, findCompanyMajorCategory)
import qualified Data.Set as Set
import qualified Data.Text as T
import Data.Time (getCurrentTime, utctDay)
import Handler.Api.Common
import Import
import SiteSettings
import qualified Prelude as P

getApiBootstrapR :: Handler Value
getApiBootstrapR = do
    settingMap <- loadSettingMap
    appConfig <- getsYesod appSettings
    mViewerId <- maybeApiAuthId
    req <- getRequest
    let siteTitle = siteSettingText "site_title" "HKForum" settingMap
        siteSubtitle = siteSettingText "site_subtitle" "x.com inspired discussion hub" settingMap
        siteDescription = siteSettingText "site_description" siteSubtitle settingMap
        siteKeywords = siteSettingText "site_keywords" "" settingMap
        siteLogoUrl = siteSettingMaybeText "site_logo_url" settingMap
        siteFaviconUrl = siteSettingMaybeText "site_favicon_url" settingMap
        footerText = siteSettingText "footer_text" siteTitle settingMap
        defaultLocale = siteSettingText "default_locale" "en" settingMap
        allowUserRegistration = siteSettingBool "allow_user_registration" True settingMap
        allowPostReporting = siteSettingBool "allow_post_reporting" True settingMap
        allowUserBlocking = siteSettingBool "allow_user_blocking" True settingMap
        showCompaniesNav = siteSettingBool "companies_enabled" True settingMap
        showJobsNav = siteSettingBool "jobs_enabled" True settingMap
        mapsEnabled = siteSettingBool "maps_enabled" True settingMap
        defaultMapLatitude = siteSettingDouble "default_map_latitude" 37.5665 settingMap
        defaultMapLongitude = siteSettingDouble "default_map_longitude" 126.9780 settingMap
        defaultMapZoom = siteSettingInt "default_map_zoom" 11 settingMap
        adsEnabled = siteSettingBool "ads_enabled" True settingMap
        sidebarAdsEnabled = siteSettingBool "ad_slots_sidebar_enabled" True settingMap
        localRegionFilterEnabled = siteSettingBool "local_region_filter_enabled" True settingMap
    boards <- runDB $ selectList [] [Asc BoardName]
    mViewerEntity <-
        case mViewerId of
            Nothing -> pure Nothing
            Just viewerId -> fmap (Entity viewerId) <$> runDB (get viewerId)
    suggestedUsers <-
        case mViewerId of
            Nothing -> runDB $ selectList [] [Asc UserIdent, LimitTo 5]
            Just viewerId -> runDB $ selectList [UserId !=. viewerId] [Asc UserIdent, LimitTo 5]
    blockedRows <-
        case mViewerId of
            Nothing -> pure []
            Just viewerId ->
                runDB $
                    selectList
                        [ FilterOr
                            [ UserBlockBlocker ==. viewerId
                            , UserBlockBlocked ==. viewerId
                            ]
                        ]
                        []
    let suggestedIds = map entityKey suggestedUsers
    followingRows <-
        case mViewerId of
            Nothing -> pure []
            Just viewerId ->
                if P.null suggestedIds
                    then pure []
                    else runDB $ selectList [UserFollowFollower ==. viewerId, UserFollowFollowing <-. suggestedIds] []
    unreadNotificationCount <-
        case mViewerId of
            Nothing -> pure (0 :: Int)
            Just viewerId -> runDB $ count [NotificationUser ==. viewerId, NotificationIsRead ==. False]
    today <- liftIO $ utctDay <$> getCurrentTime
    sidebarAds <-
        if adsEnabled && sidebarAdsEnabled
            then runDB $ selectList
                [ AdPosition ==. "sidebar-right"
                , AdIsActive ==. True
                , FilterOr [AdStartDate ==. Nothing, AdStartDate <=. Just today]
                , FilterOr [AdEndDate ==. Nothing, AdEndDate >=. Just today]
                ]
                [Asc AdSortOrder, Desc AdCreatedAt]
            else pure []
    companyCategories <- runDB $ selectList [CompanyGroupIsSystem ==. True] [Asc CompanyGroupSortOrder, Asc CompanyGroupName]
    let followingSet = Set.fromList $ map (userFollowFollowing . entityVal) followingRows
        blockedSet =
            Set.fromList $
                concatMap
                    (\(Entity _ row) -> [userBlockBlocker row, userBlockBlocked row])
                    blockedRows
        filteredSuggestedUsers =
            case mViewerId of
                Nothing -> suggestedUsers
                Just viewerId ->
                    filter
                        (\(Entity userId _) ->
                            not (Set.member userId blockedSet) || userId == viewerId
                        )
                        suggestedUsers
    returnJson $
        object
            [ "site" .= object
                [ "title" .= siteTitle
                , "subtitle" .= siteSubtitle
                , "description" .= siteDescription
                , "keywords" .= siteKeywords
                , "logoUrl" .= siteLogoUrl
                , "faviconUrl" .= siteFaviconUrl
                , "footerText" .= footerText
                , "defaultLocale" .= defaultLocale
                , "allowUserRegistration" .= allowUserRegistration
                , "allowPostReporting" .= allowPostReporting
                , "allowUserBlocking" .= allowUserBlocking
                , "showCompaniesNav" .= showCompaniesNav
                , "showJobsNav" .= showJobsNav
                , "mapsEnabled" .= mapsEnabled
                , "defaultMapLatitude" .= defaultMapLatitude
                , "defaultMapLongitude" .= defaultMapLongitude
                , "defaultMapZoom" .= defaultMapZoom
                , "adsEnabled" .= adsEnabled
                , "sidebarAdsEnabled" .= sidebarAdsEnabled
                , "localRegionFilterEnabled" .= localRegionFilterEnabled
                ]
            , "auth" .= object
                [ "isAuthenticated" .= isJust mViewerId
                , "csrfParam" .= defaultCsrfParamName
                , "csrfToken" .= reqToken req
                , "providers" .= providerValues appConfig
                ]
            , "viewer" .= maybe Null viewerValue mViewerEntity
            , "boards" .= map boardSummaryValue boards
            , "suggestedUsers" .= map (suggestionValue followingSet) (P.take 3 filteredSuggestedUsers)
            , "sidebarAds" .= map adValue sidebarAds
            , "unreadNotificationCount" .= unreadNotificationCount
            , "companyCategories" .= map categoryValue companyCategories
            ]
  where
    viewerValue (Entity viewerId viewer) =
        object
            [ "id" .= keyToInt viewerId
            , "ident" .= userIdent viewer
            , "name" .= userName viewer
            , "role" .= userRole viewer
            , "description" .= userDescription viewer
            , "countryCode" .= userCountryCode viewer
            , "state" .= userState viewer
            , "localRegionOnly" .= userLocalRegionOnly viewer
            , "latitude" .= userLatitude viewer
            , "longitude" .= userLongitude viewer
            , "authProvider" .= authProviderForUser viewer
            ]

    suggestionValue followingSet (Entity userId user) =
        object
            [ "id" .= keyToInt userId
            , "ident" .= userIdent user
            , "name" .= userName user
            , "isFollowing" .= Set.member userId followingSet
            ]

    adValue (Entity adId ad) =
        object
            [ "id" .= keyToInt adId
            , "title" .= adTitle ad
            , "body" .= adBody ad
            , "link" .= adLink ad
            ]

    categoryValue (Entity categoryId category) =
        object
            [ "id" .= keyToInt categoryId
            , "name" .= companyGroupName category
            , "description" .= companyGroupDescription category
            , "code" .= companyGroupCode category
            , "majorCode" .= companyGroupMajorCode category
            , "majorName" .= (companyGroupMajorCode category >>= fmap companyMajorCategoryName . findCompanyMajorCategory)
            ]

    providerValues settings =
        map
            (\(key, labelText) -> object ["key" .= key, "label" .= labelText, "url" .= ("/auth/page/" <> key)])
            ( [ ("google" :: Text, "Google" :: Text) | isJust (appGoogleClientId settings) && isJust (appGoogleClientSecret settings) ]
                <> [ ("kakao" :: Text, "Kakao" :: Text) | isJust (appKakaoClientId settings) && isJust (appKakaoClientSecret settings) ]
                <> [ ("naver" :: Text, "Naver" :: Text) | isJust (appNaverClientId settings) && isJust (appNaverClientSecret settings) ]
            )

    authProviderForUser viewer =
        case T.breakOn ":" (userIdent viewer) of
            (prefix, rest)
                | not (T.null rest) && prefix `elem` ["google", "kakao", "naver"] -> prefix
            _ -> ("password" :: Text)
