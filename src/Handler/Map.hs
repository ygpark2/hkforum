{-# LANGUAGE OverloadedStrings #-}

module Handler.Map
    ( getMapMarkersR
    ) where

import Import
getMapMarkersR :: Handler Value
getMapMarkersR = do
    renderUrl <- getUrlRender
    posts <- runDB $ selectList [PostLatitude !=. Nothing, PostLongitude !=. Nothing] [Desc PostCreatedAt, LimitTo 200]
    jobs <- runDB $ selectList [JobLatitude !=. Nothing, JobLongitude !=. Nothing] [Desc JobCreatedAt, LimitTo 200]
    companies <- runDB $ selectList [CompanyLatitude !=. Nothing, CompanyLongitude !=. Nothing] [Desc CompanyCreatedAt, LimitTo 200]
    let postMarkers =
            flip mapMaybe posts $ \(Entity postId post) ->
                case (postLatitude post, postLongitude post) of
                    (Just lat, Just lng) ->
                        Just $
                            object
                                [ "kind" .= ("post" :: Text)
                                , "title" .= postTitle post
                                , "subtitle" .= ("" :: Text)
                                , "latitude" .= lat
                                , "longitude" .= lng
                                , "url" .= renderUrl (PostR postId)
                                ]
                    _ -> Nothing
        jobMarkers =
            flip mapMaybe jobs $ \(Entity _ job) ->
                case (jobLatitude job, jobLongitude job) of
                    (Just lat, Just lng) ->
                        Just $
                            object
                                [ "kind" .= ("job" :: Text)
                                , "title" .= jobTitle job
                                , "subtitle" .= jobCompany job
                                , "latitude" .= lat
                                , "longitude" .= lng
                                , "url" .= renderUrl JobsR
                                ]
                    _ -> Nothing
        companyMarkers =
            flip mapMaybe companies $ \(Entity _ company) ->
                case (companyLatitude company, companyLongitude company) of
                    (Just lat, Just lng) ->
                        Just $
                            object
                                [ "kind" .= ("company" :: Text)
                                , "title" .= companyName company
                                , "subtitle" .= companyName company
                                , "latitude" .= lat
                                , "longitude" .= lng
                                , "url" .= renderUrl CompaniesR
                                ]
                    _ -> Nothing
    returnJson $
        object
            [ "markers" .= (postMarkers <> jobMarkers <> companyMarkers)
            , "count" .= (Prelude.length postMarkers + Prelude.length jobMarkers + Prelude.length companyMarkers)
            ]
