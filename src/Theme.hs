{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Theme
    ( availableThemeKeys
    , defaultThemeKey
    , normalizeThemeKey
    , userThemeKey
    ) where

import Import.NoFoundation
import qualified Data.Text as T

availableThemeKeys :: [Text]
availableThemeKeys = ["forum", "forest", "midnight"]

defaultThemeKey :: Text
defaultThemeKey = "forum"

normalizeThemeKey :: Text -> Maybe Text
normalizeThemeKey raw =
    let cleaned = T.toLower (T.strip raw)
    in if cleaned `elem` availableThemeKeys then Just cleaned else Nothing

userThemeKey :: User -> Text
userThemeKey user =
    fromMaybe defaultThemeKey (userTheme user >>= normalizeThemeKey)
