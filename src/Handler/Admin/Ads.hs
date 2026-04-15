{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}

module Handler.Admin.Ads
    ( getAdminAdsR
    , getAdminAdNewR
    , getAdminAdR
    , postAdminAdsR
    , postAdminAdR
    ) where

import Import
import Text.Blaze (preEscapedText)

getAdminAdsR :: Handler Html
getAdminAdsR = do
    ads <- runDB $ selectList [] [Asc AdSortOrder, Desc AdCreatedAt]
    req <- getRequest
    let mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Ads"
        let adminBody = $(widgetFile "admin/ad/list")
            activeKey = ("ads" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminAdNewR :: Handler Html
getAdminAdNewR = do
    req <- getRequest
    let mCsrfToken = reqToken req
        mAd = (Nothing :: Maybe (Entity Ad))
        isNew = True
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New Ad"
        let adminBody = $(widgetFile "admin/ad/detail")
            activeKey = ("ads" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminAdR :: AdId -> Handler Html
getAdminAdR adId = do
    ad <- runDB $ get404 adId
    req <- getRequest
    let mCsrfToken = reqToken req
        mAd = Just (Entity adId ad)
        isNew = False
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit Ad"
        let adminBody = $(widgetFile "admin/ad/detail")
            activeKey = ("ads" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

postAdminAdsR :: Handler Html
postAdminAdsR = do
    title <- runInputPost $ ireq textField "title"
    body <- runInputPost $ ireq textField "body"
    mLink <- runInputPost $ iopt textField "link"
    isActive <- runInputPost $ ireq checkBoxField "isActive"
    mStartDate <- runInputPost $ iopt dayField "startDate"
    mEndDate <- runInputPost $ iopt dayField "endDate"
    position <- runInputPost $ ireq textField "position"
    sortOrder <- runInputPost $ ireq intField "sortOrder"
    now <- liftIO getCurrentTime
    if hasInvalidAdSchedule mStartDate mEndDate
        then setMessage "Start date must be on or before end date."
        else do
            _ <- runDB $ insert $ Ad
                { adTitle = title
                , adBody = body
                , adLink = mLink
                , adIsActive = isActive
                , adStartDate = mStartDate
                , adEndDate = mEndDate
                , adPosition = position
                , adSortOrder = sortOrder
                , adCreatedAt = now
                , adUpdatedAt = now
                }
            setMessage "Ad created."
    redirect AdminAdsR

postAdminAdR :: AdId -> Handler Html
postAdminAdR adId = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            runDB $ delete adId
            setMessage "Ad deleted."
            redirect AdminAdsR
        "update" -> do
            title <- runInputPost $ ireq textField "title"
            body <- runInputPost $ ireq textField "body"
            mLink <- runInputPost $ iopt textField "link"
            isActive <- runInputPost $ ireq checkBoxField "isActive"
            mStartDate <- runInputPost $ iopt dayField "startDate"
            mEndDate <- runInputPost $ iopt dayField "endDate"
            position <- runInputPost $ ireq textField "position"
            sortOrder <- runInputPost $ ireq intField "sortOrder"
            now <- liftIO getCurrentTime
            if hasInvalidAdSchedule mStartDate mEndDate
                then setMessage "Start date must be on or before end date."
                else do
                    runDB $ update adId
                        [ AdTitle =. title
                        , AdBody =. body
                        , AdLink =. mLink
                        , AdIsActive =. isActive
                        , AdStartDate =. mStartDate
                        , AdEndDate =. mEndDate
                        , AdPosition =. position
                        , AdSortOrder =. sortOrder
                        , AdUpdatedAt =. now
                        ]
                    setMessage "Ad updated."
            redirect AdminAdsR
        _ -> do
            setMessage "Unknown action."
            redirect AdminAdsR

hasInvalidAdSchedule :: Maybe Day -> Maybe Day -> Bool
hasInvalidAdSchedule (Just startDate) (Just endDate) = startDate > endDate
hasInvalidAdSchedule _ _ = False
