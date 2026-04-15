{-# LANGUAGE OverloadedStrings #-}
module Handler.Upload (postUploadR, getFileR) where

import Import
import SiteSettings
import Storage (StorageBackendType(..), storagePut, storageOpen, storageUrl)
import Data.Time (getCurrentTime)
import qualified Data.Text as T
import qualified Prelude as P
import System.FilePath (takeExtension)
import Text.Read (readMaybe)

postUploadR :: Handler Value
postUploadR = do
    uid <- requireAuthId
    settingRows <- runDB $ selectList [] []
    let settingMap = siteSettingMapFromEntities settingRows
        maxUploadSizeMb = max 1 (siteSettingInt "max_upload_size_mb" 10 settingMap)
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
            ( object
                [ "error" .= ("upload_too_large" :: Text)
                , "message" .= ("Upload exceeds the configured size limit." :: Text)
                ]
            )
    case mFileInfo of
        Just fi -> do
            let fileExtension =
                    T.toLower $
                        T.dropWhile (== '.') $
                            T.pack $
                                takeExtension $
                                    unpack (fileName fi)
                contentType = T.toLower (fileContentType fi)
            when (not (P.null allowedUploadExtensions) && fileExtension `notElem` allowedUploadExtensions) $
                sendResponseStatus
                    status415
                    ( object
                        [ "error" .= ("upload_extension_not_allowed" :: Text)
                        , "message" .= ("This file extension is not allowed." :: Text)
                        ]
                    )
            when (not (P.null allowedUploadMimeTypes) && contentType `notElem` allowedUploadMimeTypes) $
                sendResponseStatus
                    status415
                    ( object
                        [ "error" .= ("upload_content_type_not_allowed" :: Text)
                        , "message" .= ("This file type is not allowed." :: Text)
                        ]
                    )
            let prefix = "users/" <> toPathPiece uid
            (do
                key <- storagePut storage fi prefix
                _ <- runDB $ insert $ Upload
                    { uploadOwnerId = uid
                    , uploadStorageKey = key
                    , uploadOriginalName = fileName fi
                    , uploadContentType = Just (fileContentType fi)
                    , uploadSizeBytes = Nothing
                    , uploadCreatedAt = now
                    }
                url <- storageUrl storage key
                returnJson $ object ["url" .= url]
                )
                `catchAny` \err ->
                    sendResponseStatus
                        status500
                        ( object
                            [ "error" .= ("upload_failed" :: Text)
                            , "message" .= ("Upload failed: " <> T.pack (show err))
                            ]
                        )
        _ ->
            sendResponseStatus
                status400
                ( object
                    [ "error" .= ("upload_failed" :: Text)
                    , "message" .= ("No upload file was provided." :: Text)
                    ]
                )

getFileR :: [Text] -> Handler TypedContent
getFileR keySegments = do
    let key = T.intercalate "/" keySegments
    storage <- getsYesod appStorage
    backend <- getsYesod appStorageBackendType
    case backend of
        StorageBackendLocal -> do
            m <- storageOpen storage key
            case m of
                Nothing -> notFound
                Just (ct, path) -> sendFile ct path
        StorageBackendS3 -> do
            url <- storageUrl storage key
            redirect url
