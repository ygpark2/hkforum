{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Thread (getThreadR) where

import Import
import qualified Data.List as L
import qualified Data.Text as T
import qualified Data.Map.Strict as Map
import Text.Blaze (preEscapedText)
import qualified Prelude as P

getThreadR :: ThreadId -> Handler Html
getThreadR threadId = do
    thread <- runDB $ get404 threadId
    posts <- runDB $ selectList [PostThread ==. threadId] [Asc PostCreatedAt]
    let postIds = map entityKey posts
    comments <- if P.null postIds
        then return []
        else runDB $ selectList [CommentPost <-. postIds] [Asc CommentCreatedAt]
    let commentsByPost =
            P.foldl
                (\acc (Entity cId c) ->
                    Map.insertWith (P.<>) (commentPost c) [Entity cId c] acc)
                Map.empty
                comments
    let postAuthorIds = map (postAuthor . entityVal) posts
        commentAuthorIds = map (commentAuthor . entityVal) comments
        authorIds = L.nub $ threadAuthor thread : (postAuthorIds P.++ commentAuthorIds)
    users <- if P.null authorIds
        then return []
        else runDB $ selectList [UserId <-. authorIds] []
    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        authorName uid = Map.findWithDefault (T.pack "Unknown") uid userMap
    board <- runDB $ get404 (threadBoard thread)
    maybeAuth <- maybeAuthId
    isAdminUser <- case maybeAuth of
        Nothing -> pure False
        Just userId -> do
            mUser <- runDB $ get userId
            pure $ maybe False (\user -> userRole user == T.pack "admin") mUser
    ads <- runDB $ selectList [AdIsActive ==. True, AdPosition ==. T.pack "sidebar-right"] [Asc AdSortOrder, Desc AdCreatedAt]
    req <- getRequest
    let mCsrfToken = reqToken req
    let commentsFor pid = Map.findWithDefault [] pid commentsByPost
    defaultLayout $ do
        setTitle $ preEscapedText $ threadTitle thread <> T.pack " - HKForum"
        $(widgetFile "forum/thread")
