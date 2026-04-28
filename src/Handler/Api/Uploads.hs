{-# LANGUAGE OverloadedStrings #-}

module Handler.Api.Uploads where

import Handler.Api.Common
import Import
import SiteSettings
import Storage (storagePut, storageUrl)
import System.FilePath (takeExtension)
import Text.Read (readMaybe)
import qualified Data.Text as T
import qualified Prelude as P

postApiUploadsR :: Handler Value
postApiUploadsR = do
    uid <- requireApiAuthId
    settingMap <- loadSettingMap
    let maxUploadSizeMb = max 1 (siteSettingInt "max_upload_size_mb" 10 settingMap)
        maxUploadBytes = maxUploadSizeMb * 1024 * 1024
        allowedUploadExtensions =
            map (T.toLower . T.dropWhile (== '.')) $
                siteSettingCsv "allowed_upload_extensions" settingMap
        allowedUploadMimeTypes =
            map T.toLower $
                siteSettingCsv "allowed_upload_mime_types" settingMap
    storage <- getsYesod appStorage
    now <- liftIO getCurrentTime
    mContentLengthHeader <- lookupHeader "Content-Length"
    let mContentLengthBytes =
            mContentLengthHeader >>= readMaybe . unpack . decodeUtf8
    (_params, files) <- runRequestBody
    let mFileInfo =
            P.lookup "file" files
                <|> P.lookup "image" files
                <|> P.lookup "upload" files
                <|> fmap snd (listToMaybe files)
    when (maybe False (> maxUploadBytes) mContentLengthBytes) $
        sendResponseStatus
            status413
            (object
                [ "error" .= ("upload_too_large" :: Text)
                , "message" .= ("Upload exceeds the configured size limit." :: Text)
                ]
            )
    case mFileInfo of
        Nothing ->
            sendResponseStatus
                status400
                (object
                    [ "error" .= ("upload_failed" :: Text)
                    , "message" .= ("No upload file was provided." :: Text)
                    ]
                )
        Just fileInfo -> do
            let fileExtension =
                    T.toLower $
                        T.dropWhile (== '.') $
                            T.pack $
                                takeExtension $
                                    unpack (fileName fileInfo)
                contentType = T.toLower (fileContentType fileInfo)
            when (not (P.null allowedUploadExtensions) && fileExtension `notElem` allowedUploadExtensions) $
                sendResponseStatus
                    status415
                    (object
                        [ "error" .= ("upload_extension_not_allowed" :: Text)
                        , "message" .= ("This file extension is not allowed." :: Text)
                        ]
                    )
            when (not (P.null allowedUploadMimeTypes) && contentType `notElem` allowedUploadMimeTypes) $
                sendResponseStatus
                    status415
                    (object
                        [ "error" .= ("upload_content_type_not_allowed" :: Text)
                        , "message" .= ("This file type is not allowed." :: Text)
                        ]
                    )
            let prefix = "users/" <> toPathPiece uid
            (do
                key <- storagePut storage fileInfo prefix
                _ <- runDB $ insert $ Upload
                    { uploadOwnerId = uid
                    , uploadStorageKey = key
                    , uploadOriginalName = fileName fileInfo
                    , uploadContentType = Just (fileContentType fileInfo)
                    , uploadSizeBytes = Nothing
                    , uploadCreatedAt = now
                    }
                url <- storageUrl storage key
                returnJson $ object ["key" .= key, "url" .= url]
                )
                `catchAny` \err ->
                    sendResponseStatus
                        status500
                        (object
                            [ "error" .= ("upload_failed" :: Text)
                            , "message" .= ("Upload failed: " <> T.pack (show err))
                            ]
                        )
