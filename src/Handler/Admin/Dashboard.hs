{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}

module Handler.Admin.Dashboard
    ( getAdminR
    ) where

import Import
import Text.Blaze (preEscapedText)

getAdminR :: Handler Html
getAdminR = do
    defaultLayout $ do
        setTitle $ preEscapedText "Admin"
        let adminBody = $(widgetFile "admin/index")
            activeKey = ("overview" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")
