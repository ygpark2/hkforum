{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Meta where

import Import

getApiMetaRegionsR :: Handler Value
getApiMetaRegionsR = do
    countries <- runDB $ selectList [] [Asc CountrySortOrder, Asc CountryCode]
    states <- runDB $ selectList [] [Asc CountryStateCountryCode, Asc CountryStateSortOrder, Asc CountryStateCode]
    returnJson $
        object
            [ "countries" .= map countryValue countries
            , "states" .= map stateValue states
            ]
  where
    countryValue (Entity _ country) =
        object
            [ "code" .= countryCode country
            , "name" .= countryName country
            , "localName" .= countryLocalName country
            ]
    stateValue (Entity _ stateRow) =
        object
            [ "countryCode" .= countryStateCountryCode stateRow
            , "code" .= countryStateCode stateRow
            , "name" .= countryStateName stateRow
            , "localName" .= countryStateLocalName stateRow
            , "stateType" .= countryStateStateType stateRow
            ]
