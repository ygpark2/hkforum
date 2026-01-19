{-# LANGUAGE OverloadedStrings, TemplateHaskell #-}
module Handler.Register where

import Import
import Crypto.BCrypt
import Text.Blaze (preEscapedText)

renderRegister :: Widget -> Enctype -> Handler Html
renderRegister widget enctype = do
    mmsg <- getMessage
    defaultLayout $ do
        setTitle $ preEscapedText "Register"
        $(widgetFile "register")

getRegisterR :: Handler Html
getRegisterR = do
    (widget, enctype) <- generateFormPost registerForm
    renderRegister widget enctype

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
                      renderRegister widget enctype
        _ -> renderRegister widget enctype

registerForm :: Form (Text, Text)
registerForm = renderDivs $ (,)
    <$> areq textField "Username" Nothing
    <*> areq passwordField "Password" Nothing