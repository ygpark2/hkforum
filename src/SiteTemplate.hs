{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module SiteTemplate
    ( availableSiteTemplateKeys
    , defaultSiteTemplateKey
    , normalizeSiteTemplateKey
    ) where

import Import.NoFoundation
import qualified Data.Text as T

availableSiteTemplateKeys :: [Text]
availableSiteTemplateKeys = ["base", "eu", "anz"]

defaultSiteTemplateKey :: Text
defaultSiteTemplateKey = "base"

normalizeSiteTemplateKey :: Text -> Maybe Text
normalizeSiteTemplateKey raw =
    let cleaned = T.toLower (T.strip raw)
    in if cleaned `elem` availableSiteTemplateKeys then Just cleaned else Nothing
