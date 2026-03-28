{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}

module Handler.Admin.Users
    ( getAdminUsersR
    , getAdminUserNewR
    , getAdminUserR
    , postAdminUsersR
    , postAdminUserR
    ) where

import Import
import qualified Data.Text as T
import Text.Blaze (preEscapedText)
import Yesod.Auth.HashDB (setPassword)

getAdminUsersR :: Handler Html
getAdminUsersR = do
    users <- runDB $ selectList [] [Asc UserIdent]
    mUserId <- maybeAuthId
    req <- getRequest
    let mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Users"
        let adminBody = $(widgetFile "admin/user/list")
            activeKey = ("users" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminUserNewR :: Handler Html
getAdminUserNewR = do
    req <- getRequest
    let mCsrfToken = reqToken req
        mUser = (Nothing :: Maybe (Entity User))
        isNew = True
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - New User"
        let adminBody = $(widgetFile "admin/user/detail")
            activeKey = ("users" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminUserR :: UserId -> Handler Html
getAdminUserR userId = do
    user <- runDB $ get404 userId
    req <- getRequest
    let mCsrfToken = reqToken req
        mUser = Just (Entity userId user)
        isNew = False
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Edit User"
        let adminBody = $(widgetFile "admin/user/detail")
            activeKey = ("users" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

postAdminUsersR :: Handler Html
postAdminUsersR = do
    ident <- runInputPost $ ireq textField "ident"
    password <- runInputPost $ ireq passwordField "password"
    role <- normalizeRole <$> runInputPost (ireq textField "role")
    name <- runInputPost $ iopt textField "name"
    description <- runInputPost $ iopt textField "description"
    mExisting <- runDB $ getBy $ UniqueUser ident
    case mExisting of
        Just _ -> setMessage "User already exists."
        Nothing -> do
            user <- liftIO $ setPassword password (User ident Nothing role name description Nothing Nothing False Nothing Nothing)
            void $ runDB $ insert user
            setMessage "User created."
    redirect AdminUsersR

postAdminUserR :: UserId -> Handler Html
postAdminUserR userId = do
    action <- runInputPost $ ireq textField "action"
    case action of
        "delete" -> do
            mCurrent <- maybeAuthId
            if Just userId == mCurrent
                then setMessage "You cannot delete your own account."
                else do
                    postCount <- runDB $ count [PostAuthor ==. userId]
                    commentCount <- runDB $ count [CommentAuthor ==. userId]
                    if postCount + commentCount > 0
                        then setMessage "User has content and cannot be deleted."
                        else do
                            runDB $ delete userId
                            setMessage "User deleted."
            redirect AdminUsersR
        "update" -> do
            ident <- runInputPost $ ireq textField "ident"
            role <- normalizeRole <$> runInputPost (ireq textField "role")
            name <- runInputPost $ iopt textField "name"
            description <- runInputPost $ iopt textField "description"
            password <- runInputPost $ iopt passwordField "password"
            mExisting <- runDB $ getBy $ UniqueUser ident
            case mExisting of
                Just (Entity existingId _) | existingId /= userId ->
                    setMessage "Username already exists."
                _ -> do
                    user <- runDB $ get404 userId
                    let baseUser = user
                            { userIdent = ident
                            , userRole = role
                            , userName = name
                            , userDescription = description
                            }
                    updatedUser <- case password of
                        Nothing -> pure baseUser
                        Just pwd | T.null pwd -> pure baseUser
                        Just pwd -> liftIO $ setPassword pwd baseUser
                    runDB $ replace userId updatedUser
                    setMessage "User updated."
            redirect AdminUsersR
        _ -> do
            setMessage "Unknown action."
            redirect AdminUsersR

normalizeRole :: Text -> Text
normalizeRole role
    | role == "admin" = "admin"
    | otherwise = "user"
