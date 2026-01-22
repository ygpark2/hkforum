module Handler.AuthSpec where

import TestImport

spec :: Spec
spec = withApp $ do
    describe "Auth flow" $ do
        it "allows the seeded user to log in" $ do
            get AuthR
            statusIs 200
            request $ do
                setMethod "POST"
                setUrl $ AuthR LoginR
                addToken
                addPostParam "username" "ygpark2"
                addPostParam "password" "1234"
            statusIs 303
            followRedirect
            statusIs 200
            bodyContains "Logout"

        it "rejects invalid credentials" $ do
            get AuthR
            statusIs 200
            request $ do
                setMethod "POST"
                setUrl $ AuthR LoginR
                addToken
                addPostParam "username" "ygpark2"
                addPostParam "password" "wrong"
            statusIs 303
            followRedirect
            statusIs 200
            bodyContains "Invalid username/password combination"
