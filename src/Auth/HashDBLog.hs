{-# LANGUAGE CPP #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Auth.HashDBLog
    ( authHashDBLog
    , authHashDBLogWithForm
    ) where

import Data.Aeson (FromJSON(..), (.:?))
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Yesod.Auth
import Yesod.Auth.HashDB (HashDBUser, validateUser)
import Yesod.Auth.Message (AuthMessage (InvalidUsernamePass))
import Yesod.Core
import Yesod.Form
import Yesod.Persist
import Database.Persist (PersistEntity (..), PersistEntityBackend, PersistUnique)
import Database.Persist.Sql (BaseBackend)

#if !MIN_VERSION_yesod_core(1,6,0)
#define liftHandler lift
#endif

#if !MIN_VERSION_yesod_core(1,6,11)
#define requireInsecureJsonBody requireJsonBody
#endif

-- | Constraint copied from 'Yesod.Auth.HashDB'.
type HashDBPersist master user =
    ( YesodAuthPersist master
    , PersistUnique (YesodPersistBackend master)
    , AuthEntity master ~ user
#if MIN_VERSION_persistent(2,5,0)
    , PersistEntityBackend user ~ BaseBackend (YesodPersistBackend master)
#else
    , PersistEntityBackend user ~ YesodPersistBackend master
#endif
    , HashDBUser user
    , PersistEntity user
    )

-- Internal data type for the username/password wrapper
data UserPass = UserPass (Maybe Text) (Maybe Text)

instance FromJSON UserPass where
    parseJSON (Object v) = UserPass
                           <$> v .:? "username"
                           <*> v .:? "password"
    parseJSON _          = pure $ UserPass Nothing Nothing

hashdbRoute :: AuthRoute
hashdbRoute = PluginR "hashdb" ["login"]

-- | Handle the login form and log every attempt.
postLoginR :: HashDBPersist site user
           => (Text -> Maybe (Unique user))
           -> AuthHandler site TypedContent
postLoginR uniq = do
    ct <- lookupHeader "Content-Type"
    let jsonContent = ((== "application/json") . simpleContentType) <$> ct
    UserPass mu mp <-
        case jsonContent of
          Just True -> requireInsecureJsonBody
          _         -> liftHandler $ runInputPost $ UserPass
                       <$> iopt textField "username"
                       <*> iopt textField "password"
    let usernameForLog = fromMaybe "<missing>" mu
    isValid <- liftHandler $ fromMaybe (return False)
                 (validateUser <$> (uniq =<< mu) <*> mp)
    case (mu, mp) of
        (Just uname, Just _) ->
            if isValid
                then do
                    $(logInfo) $ "Authentication succeeded: " <> uname
                    liftHandler $ setCredsRedirect $ Creds "hashdb" uname []
                else do
                    $(logWarn) $ "Authentication failed: invalid password for " <> uname
                    loginErrorMessageI LoginR InvalidUsernamePass
        (Nothing, _) -> do
            $(logWarn) $ "Authentication failed: username missing"
            loginErrorMessageI LoginR InvalidUsernamePass
        (_, Nothing) -> do
            $(logWarn) $ "Authentication failed: password missing for " <> usernameForLog
            loginErrorMessageI LoginR InvalidUsernamePass

-- | Default HashDB widget with logging.
authHashDBLog :: HashDBPersist site user
              => (Text -> Maybe (Unique user)) -> AuthPlugin site
authHashDBLog = authHashDBLogWithForm defaultForm

-- | Like 'authHashDBLog', but with custom form builder.
authHashDBLogWithForm :: forall site user.
                         HashDBPersist site user
                      => (Route site -> WidgetFor site ())
                      -> (Text -> Maybe (Unique user))
                      -> AuthPlugin site
authHashDBLogWithForm form uniq =
    AuthPlugin "hashdb" dispatch $ \tm -> form (tm hashdbRoute)
  where
    dispatch :: Text -> [Text] -> AuthHandler site TypedContent
    dispatch "POST" ["login"] = (postLoginR uniq :: AuthHandler site TypedContent) >>= sendResponse
    dispatch _ _ = notFound

-- | Default login form copied from 'Yesod.Auth.HashDB'.
defaultForm :: Yesod app => Route app -> WidgetFor app ()
defaultForm loginR = do
    request <- getRequest
    let mtok = reqToken request
    toWidget [hamlet|
      $newline never
      <div id="header">
        <h1>Login

      <div id="login">
        <form method="post" action="@{loginR}">
          $maybe tok <- mtok
            <input type=hidden name=#{defaultCsrfParamName} value=#{tok}>
          <table>
            <tr>
              <th>Username:
              <td>
                <input id="username" name="username" autofocus="" required>
            <tr>
              <th>Password:
              <td>
                <input type="password" name="password" required>
            <tr>
              <td>&nbsp;
              <td>
                <input type="submit" value="Login">

          <script>
            if (!("autofocus" in document.createElement("input"))) {
                document.getElementById("username").focus();
            }

    |]
