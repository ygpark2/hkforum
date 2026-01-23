{-# LANGUAGE TemplateHaskell, OverloadedStrings #-}
module Handler.Forum.Boards (getBoardsR, postBoardsR) where

import Import
import Text.Blaze (preEscapedText)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import Database.Persist.Sql (fromSqlKey)
import qualified Data.Text as T
import qualified Prelude as P
import Text.Read (readMaybe)

getBoardsR :: Handler Html
getBoardsR = do
    boards <- runDB $ selectList [] [Asc BoardName]
    threads <- runDB $ selectList [] [Desc ThreadCreatedAt]
    let authorIds = L.nub $ map (threadAuthor . entityVal) threads
    users <- if P.null authorIds
        then return []
        else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
    maybeAuthValue <- maybeAuthId
    isAdminUser <- case maybeAuthValue of
        Nothing -> pure False
        Just userId -> do
            mUser <- runDB $ get userId
            pure $ maybe False (\user -> userRole user == T.pack "admin") mUser
    ads <- runDB $ selectList [AdIsActive ==. True, AdPosition ==. T.pack "sidebar-right"] [Asc AdSortOrder, Desc AdCreatedAt]
    req <- getRequest
    let mCsrfToken = reqToken req
    previewLimit <- getPreviewLimit
    let previewText = buildPreview previewLimit . threadContent
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum - Home"
        $(widgetFile "forum/boards")

postBoardsR :: Handler Html
postBoardsR = do
    userId <- requireAuthId
    boardId <- runInputPost $ ireq hiddenField "boardId"
    title <- runInputPost $ ireq textField "title"
    content <- runInputPost $ ireq textField "content"
    now <- liftIO getCurrentTime
    _ <- runDB $ insert Thread
        { threadTitle = title
        , threadContent = content
        , threadAuthor = userId
        , threadBoard = boardId
        , threadCreatedAt = now
        , threadUpdatedAt = now
        }
    runDB $ update boardId [BoardThreadCount +=. 1]
    redirect $ BoardR boardId

getPreviewLimit :: Handler Int
getPreviewLimit = do
    mSetting <- runDB $ getBy $ UniqueSiteSetting "thread_preview_chars"
    case mSetting of
        Nothing -> pure 200
        Just (Entity _ s) ->
            case readMaybe (T.unpack (siteSettingValue s)) of
                Just n | n > 0 -> pure n
                _ -> pure 200

buildPreview :: Int -> Text -> Text
buildPreview n raw =
    let plain = stripTags raw
        trimmed = T.take n plain
    in if T.length plain > n then trimmed <> "…" else trimmed

stripTags :: Text -> Text
stripTags = T.pack . go False . T.unpack
  where
    go _ [] = []
    go True ('>':xs) = go False xs
    go True (_:xs) = go True xs
    go False ('<':xs) = go True xs
    go False (x:xs) = x : go False xs
