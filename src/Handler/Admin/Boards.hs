{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}

module Handler.Admin.Boards
    ( getAdminBoardsR
    , getAdminBoardNewR
    , getAdminBoardR
    , postAdminBoardsR
    , postAdminBoardR
    ) where

import Import
import Text.Blaze (preEscapedText)

getAdminBoardsR :: Handler Html
getAdminBoardsR = do
    boards <- runDB $ selectList [] [Asc BoardName]
    req <- getRequest
    let mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Boards"
        let adminBody = $(widgetFile "admin/board/list")
            activeKey = ("boards" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminBoardNewR :: Handler Html
getAdminBoardNewR = do
    req <- getRequest
    let mCsrfToken = reqToken req
        mBoard = (Nothing :: Maybe (Entity Board))
        isNew = True
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New Board"
        let adminBody = $(widgetFile "admin/board/detail")
            activeKey = ("boards" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminBoardR :: BoardId -> Handler Html
getAdminBoardR boardId = do
    board <- runDB $ get404 boardId
    req <- getRequest
    let mCsrfToken = reqToken req
        mBoard = Just (Entity boardId board)
        isNew = False
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit Board"
        let adminBody = $(widgetFile "admin/board/detail")
            activeKey = ("boards" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

postAdminBoardsR :: Handler Html
postAdminBoardsR = do
    name <- runInputPost $ ireq textField "name"
    description <- runInputPost $ iopt textareaField "description"
    mExisting <- runDB $ getBy $ UniqueBoard name
    case mExisting of
        Just _ -> setMessage "Board already exists."
        Nothing -> do
            void $ runDB $ insert $ Board name (fmap unTextarea description) 0 0
            setMessage "Board created."
    redirect AdminBoardsR

postAdminBoardR :: BoardId -> Handler Html
postAdminBoardR boardId = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            postCount <- runDB $ count [PostBoard ==. boardId]
            if postCount > 0
                then setMessage "Board has posts and cannot be deleted."
                else do
                    runDB $ delete boardId
                    setMessage "Board deleted."
            redirect AdminBoardsR
        "update" -> do
            name <- runInputPost $ ireq textField "name"
            description <- runInputPost $ iopt textareaField "description"
            mExisting <- runDB $ getBy $ UniqueBoard name
            case mExisting of
                Just (Entity existingId _) | existingId /= boardId ->
                    setMessage "Board name already exists."
                _ -> do
                    runDB $ update boardId
                        [ BoardName =. name
                        , BoardDescription =. fmap unTextarea description
                        ]
                    setMessage "Board updated."
            redirect AdminBoardsR
        _ -> do
            setMessage "Unknown action."
            redirect AdminBoardsR
