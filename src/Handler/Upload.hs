{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

module Handler.Upload (getFileR) where

import qualified Data.Text as T
import Import
import Storage (storageOpen)

getFileR :: [Text] -> Handler TypedContent
getFileR keySegments = do
    let cleanedSegments = filter (not . T.null) keySegments
        storageKey = T.intercalate "/" cleanedSegments
    when (T.null storageKey) notFound
    storage <- appStorage <$> getYesod
    mStored <- storageOpen storage storageKey
    case mStored of
        Nothing -> notFound
        Just (contentType, path) ->
            sendFile contentType path
