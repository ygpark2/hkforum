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
import qualified Data.Text as T
import Text.Blaze (preEscapedText)

getAdminSettingsR :: Handler Html
getAdminSettingsR = do
    settings <- runDB $ selectList [] [Asc SiteSettingKey]
    mSiteTitle <- runDB $ getBy $ UniqueSiteSetting "site_title"
    mSiteSubtitle <- runDB $ getBy $ UniqueSiteSetting "site_subtitle"
    req <- getRequest
    let mCsrfToken = reqToken req
        siteTitleValue = maybe "HKForum" (siteSettingValue P.. entityVal) mSiteTitle
        siteSubtitleValue = maybe "x.com inspired discussion hub" (siteSettingValue P.. entityVal) mSiteSubtitle
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Settings"
        let adminBody = $(widgetFile "admin/admin-settings")
            activeKey = ("settings" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminSettingNewR :: Handler Html
getAdminSettingNewR = do
    req <- getRequest
    let mCsrfToken = reqToken req
        mSetting = (Nothing :: Maybe (Entity SiteSetting))
        isNew = True
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New Setting"
        let adminBody = $(widgetFile "admin/admin-setting-detail")
            activeKey = ("settings" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminSettingR :: SiteSettingId -> Handler Html
getAdminSettingR settingId = do
    setting <- runDB $ get404 settingId
    req <- getRequest
    let mCsrfToken = reqToken req
        mSetting = Just (Entity settingId setting)
        isNew = False
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit Setting"
        let adminBody = $(widgetFile "admin/admin-setting-detail")
            activeKey = ("settings" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

postAdminSettingsR :: Handler Html
postAdminSettingsR = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "site-identity" -> do
            title <- runInputPost $ ireq textField "site_title"
            subtitle <- runInputPost $ ireq textField "site_subtitle"
            _ <- runDB $ upsert (SiteSetting "site_title" title) [SiteSettingValue =. title]
            _ <- runDB $ upsert (SiteSetting "site_subtitle" subtitle) [SiteSettingValue =. subtitle]
            setMessage "Site identity updated."
            redirect AdminSettingsR
        "upsert" -> do
            key <- runInputPost $ ireq textField "key"
            value <- runInputPost $ ireq textField "value"
            if T.null key
                then setMessage "Key is required."
                else do
                    _ <- runDB $ upsert (SiteSetting key value) [SiteSettingValue =. value]
                    setMessage "Setting saved."
            redirect AdminSettingsR
        "delete" -> do
            key <- runInputPost $ ireq textField "key"
            runDB $ deleteBy $ UniqueSiteSetting key
            setMessage "Setting deleted."
            redirect AdminSettingsR
        _ -> do
            setMessage "Unknown action."
            redirect AdminSettingsR
