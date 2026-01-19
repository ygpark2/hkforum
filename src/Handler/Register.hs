{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Handler.Register where

import Import
import Crypto.BCrypt
import Text.Blaze (preEscapedText)

getRegisterR :: Handler Html
getRegisterR = do
    (widget, enctype) <- generateFormPost registerForm
    defaultLayout $ do
        setTitle $ preEscapedText "Register"
        $(widgetFile "register")

postRegisterR :: Handler Html
postRegisterR = do
    ((result, widget), enctype) <- runFormPost registerForm
    case result of
        FormSuccess (ident, pwd) -> do
            mUser <- runDB $ selectFirst [UserIdent ==. ident] []
            case mUser of
                Nothing -> do
                    mHashed <- liftIO $ hashPasswordUsingPolicy fastBcryptHashingPolicy (encodeUtf8 pwd)
                    case mHashed of
                        Just hashed -> do
                            let hashedPwd = decodeUtf8 hashed
                            _ <- runDB $ insert $ User ident (Just hashedPwd)
                            setMessage "Registration successful. Please login."
                            redirect $ AuthR LoginR
                        Nothing -> do
                            setMessage "Password hashing failed."
                            redirect RegisterR
                Just _ -> do
                      setMessage "Username already exists."
                      defaultLayout $ do
                          setTitle $ preEscapedText "Register"
                          $(widgetFile "register")
        _ -> defaultLayout $ do
            setTitle $ preEscapedText "Register"
            $(widgetFile "register")

registerForm :: Form (Text, Text)
registerForm = renderDivs $ (,)
    <$> areq textField "Username" Nothing
    <*> areq passwordField "Password" Nothing