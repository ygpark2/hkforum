{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Handler.Forum.Board (getBoardR, postBoardR) where

import Import
import Data.Time (getCurrentTime)
import Yesod.Form (fsLabel)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import Text.Blaze (preEscapedText)
import Text.Read (readMaybe)
import qualified Prelude as P

getBoardR :: BoardId -> Handler Html
getBoardR boardId = do
    board <- runDB $ get404 boardId
    boards <- runDB $ selectList [] [Asc BoardName]
    threads <- runDB $ selectList [ThreadBoard ==. boardId] [Desc ThreadCreatedAt]
    let authorIds = L.nub $ map (threadAuthor . entityVal) threads
    users <- if P.null authorIds
        then return []
        else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
    maybeAuth <- maybeAuthId
    isAdminUser <- case maybeAuth of
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
        setTitle $ preEscapedText $ boardName board <> T.pack " - HKForum"
        $(widgetFile "forum/board")

postBoardR :: BoardId -> Handler Html
postBoardR boardId = do
    userId <- requireAuthId
    board <- runDB $ get404 boardId
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
