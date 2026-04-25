{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module SiteSettings
    ( SiteSettingMap
    , adsSettingKeys
    , featureSettingKeys
    , forumSettingKeys
    , managedSiteSettingKeys
    , moderationSettingKeys
    , siteBasicsSettingKeys
    , siteSettingBool
    , siteSettingBoolFormValue
    , siteSettingCsv
    , siteSettingDouble
    , siteSettingInt
    , siteSettingMapFromEntities
    , siteSettingMaybeText
    , siteSettingText
    , textContainsBlockedTerm
    , uploadSettingKeys
    ) where

import Import.NoFoundation
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Text.Read (readMaybe)

type SiteSettingMap = Map.Map Text Text

siteBasicsSettingKeys :: [Text]
siteBasicsSettingKeys =
    [ "site_title"
    , "site_subtitle"
    , "site_description"
    , "site_keywords"
    , "site_template"
    , "site_logo_url"
    , "site_favicon_url"
    , "footer_text"
    , "home_feed_title"
    , "default_locale"
    , "timezone"
    , "maintenance_mode"
    , "maintenance_message"
    ]

forumSettingKeys :: [Text]
forumSettingKeys =
    [ "allow_user_registration"
    , "allow_social_login"
    , "allow_anonymous_read"
    , "posts_per_page"
    , "comments_per_page"
    , "max_post_title_length"
    , "max_post_body_length"
    , "max_comment_length"
    , "rich_text_enabled"
    ]

uploadSettingKeys :: [Text]
uploadSettingKeys =
    [ "max_upload_size_mb"
    , "allowed_upload_extensions"
    , "allowed_upload_mime_types"
    , "image_max_width"
    , "image_max_height"
    , "auto_delete_orphan_uploads"
    ]

moderationSettingKeys :: [Text]
moderationSettingKeys =
    [ "post_flag_threshold"
    , "auto_hide_flagged_posts"
    , "blocked_words"
    , "rate_limit_posts_per_minute"
    , "rate_limit_comments_per_minute"
    , "allow_user_blocking"
    , "allow_post_reporting"
    ]

adsSettingKeys :: [Text]
adsSettingKeys =
    [ "ads_enabled"
    , "ad_slots_sidebar_enabled"
    , "default_ad_position"
    , "ad_click_tracking_enabled"
    ]

featureSettingKeys :: [Text]
featureSettingKeys =
    [ "maps_enabled"
    , "default_map_latitude"
    , "default_map_longitude"
    , "default_map_zoom"
    , "local_region_filter_enabled"
    , "companies_enabled"
    , "jobs_enabled"
    , "require_company_category_on_create"
    , "job_auto_close_days"
    ]

managedSiteSettingKeys :: [Text]
managedSiteSettingKeys =
    siteBasicsSettingKeys
        <> forumSettingKeys
        <> uploadSettingKeys
        <> moderationSettingKeys
        <> adsSettingKeys
        <> featureSettingKeys

siteSettingMapFromEntities :: [Entity SiteSetting] -> SiteSettingMap
siteSettingMapFromEntities =
    Map.fromList
        . map (\(Entity _ setting) -> (siteSettingKey setting, siteSettingValue setting))

siteSettingMaybeText :: Text -> SiteSettingMap -> Maybe Text
siteSettingMaybeText key settingMap =
    normalizeSettingValue =<< Map.lookup key settingMap

siteSettingText :: Text -> Text -> SiteSettingMap -> Text
siteSettingText key fallback settingMap =
    fromMaybe fallback (siteSettingMaybeText key settingMap)

siteSettingBool :: Text -> Bool -> SiteSettingMap -> Bool
siteSettingBool key fallback settingMap =
    maybe fallback parseBoolText (siteSettingMaybeText key settingMap)

siteSettingBoolFormValue :: Text -> Bool -> SiteSettingMap -> Text
siteSettingBoolFormValue key fallback settingMap =
    if siteSettingBool key fallback settingMap then "true" else "false"

siteSettingInt :: Text -> Int -> SiteSettingMap -> Int
siteSettingInt key fallback settingMap =
    fromMaybe fallback $ do
        raw <- siteSettingMaybeText key settingMap
        readMaybe (unpack raw)

siteSettingDouble :: Text -> Double -> SiteSettingMap -> Double
siteSettingDouble key fallback settingMap =
    fromMaybe fallback $ do
        raw <- siteSettingMaybeText key settingMap
        readMaybe (unpack raw)

siteSettingCsv :: Text -> SiteSettingMap -> [Text]
siteSettingCsv key settingMap =
    case siteSettingMaybeText key settingMap of
        Nothing -> []
        Just raw ->
            filter (not . T.null) $
                map T.strip $
                    T.split (\char -> char == ',' || char == '\n' || char == ';') raw

textContainsBlockedTerm :: [Text] -> Text -> Bool
textContainsBlockedTerm blockedTerms content =
    let loweredContent = T.toLower content
        normalizedTerms =
            filter (not . T.null) $
                map (T.toLower . T.strip) blockedTerms
    in any (`T.isInfixOf` loweredContent) normalizedTerms

normalizeSettingValue :: Text -> Maybe Text
normalizeSettingValue raw =
    let trimmed = T.strip raw
    in if T.null trimmed then Nothing else Just trimmed

parseBoolText :: Text -> Bool
parseBoolText raw =
    case T.toLower (T.strip raw) of
        "1" -> True
        "true" -> True
        "yes" -> True
        "on" -> True
        _ -> False
