{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}

module Handler.Admin.Settings
    ( getAdminSettingsR
    , getAdminSettingNewR
    , getAdminSettingR
    , postAdminSettingsR
    ) where

import Import
import qualified Prelude as P
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import SiteSettings
import Text.Blaze (preEscapedText)

getAdminSettingsR :: Handler Html
getAdminSettingsR = do
    settings <- runDB $ selectList [] [Asc SiteSettingKey]
    req <- getRequest
    let mCsrfToken = reqToken req
        settingMap = siteSettingMapFromEntities settings
        settingValue key fallback = siteSettingText key fallback settingMap
        settingBoolValue key fallback = siteSettingBoolFormValue key fallback settingMap
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Settings"
        let adminBody = $(widgetFile "admin/setting/list")
            activeKey = ("settings" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminSettingNewR :: Handler Html
getAdminSettingNewR = redirect AdminSettingsR

getAdminSettingR :: SiteSettingId -> Handler Html
getAdminSettingR _ = redirect AdminSettingsR

postAdminSettingsR :: Handler Html
postAdminSettingsR = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "save-site-basics" ->
            saveSettingGroup siteBasicsSettingKeys "Site settings updated."
        "save-forum" ->
            saveSettingGroup forumSettingKeys "Forum settings updated."
        "save-upload" ->
            saveSettingGroup uploadSettingKeys "Upload settings updated."
        "save-moderation" ->
            saveSettingGroup moderationSettingKeys "Moderation settings updated."
        "save-ads" ->
            saveSettingGroup adsSettingKeys "Ad settings updated."
        "save-features" ->
            saveSettingGroup featureSettingKeys "Feature settings updated."
        "upsert" -> do
            setMessage "Use the grouped settings form."
            redirect AdminSettingsR
        "delete" -> do
            setMessage "Use the grouped settings form."
            redirect AdminSettingsR
        _ -> do
            setMessage "Unknown action."
            redirect AdminSettingsR

saveSettingGroup :: [Text] -> Html -> Handler Html
saveSettingGroup keys successMessage = do
    (params, _) <- runRequestBody
    let paramMap = Map.fromList params
        settingPairs =
            map
                (\key -> (key, T.strip (fromMaybe "" (Map.lookup key paramMap))))
                keys
    runDB $
        forM_ settingPairs $ \(key, value) ->
            if T.null value
                then deleteBy (UniqueSiteSetting key)
                else void $ upsert (SiteSetting key value) [SiteSettingValue =. value]
    setMessage successMessage
    redirect AdminSettingsR
