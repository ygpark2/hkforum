{-# LANGUAGE OverloadedStrings #-}

module Auth.Jwt
    ( issueJwt
    , verifyJwt
    , bearerTokenFromHeader
    ) where

import Crypto.Hash.Algorithms (SHA256)
import Crypto.MAC.HMAC (HMAC, hmac)
import Data.Int (Int64)
import Data.Aeson (FromJSON (..), ToJSON (..), eitherDecodeStrict', encode, object, withObject, (.:), (.:?), (.=))
import Data.ByteArray (constEq, convert)
import Data.ByteArray.Encoding (Base (Base64URLUnpadded), convertFromBase, convertToBase)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)
import Settings (AppSettings (..))

data JwtClaims = JwtClaims
    { jwtClaimsSub :: Int64
    , jwtClaimsExp :: Int64
    , jwtClaimsIat :: Int64
    , jwtClaimsIss :: Maybe Text
    }

instance ToJSON JwtClaims where
    toJSON claims =
        object $
            [ "sub" .= jwtClaimsSub claims
            , "exp" .= jwtClaimsExp claims
            , "iat" .= jwtClaimsIat claims
            ]
            <> maybe [] (\issuer -> ["iss" .= issuer]) (jwtClaimsIss claims)

instance FromJSON JwtClaims where
    parseJSON = withObject "JwtClaims" $ \o ->
        JwtClaims
            <$> o .: "sub"
            <*> o .: "exp"
            <*> o .: "iat"
            <*> o .:? "iss"

issueJwt :: AppSettings -> Int64 -> UTCTime -> Text
issueJwt settings userId now =
    let issuedAt = utcTimeToEpoch now
        expiresAt = issuedAt + fromIntegral (max 1 (appJwtExpiryMinutes settings) * 60)
        claims =
            JwtClaims
                { jwtClaimsSub = userId
                , jwtClaimsExp = expiresAt
                , jwtClaimsIat = issuedAt
                , jwtClaimsIss = normalizeIssuer settings
                }
        headerSegment = encodeSegment $ LBS.toStrict $ encode $ object ["alg" .= ("HS256" :: Text), "typ" .= ("JWT" :: Text)]
        payloadSegment = encodeSegment $ LBS.toStrict $ encode claims
        signingInput = BS.intercalate "." [headerSegment, payloadSegment]
        signatureSegment = signSegment settings signingInput
    in TE.decodeUtf8 $ BS.intercalate "." [headerSegment, payloadSegment, signatureSegment]

verifyJwt :: AppSettings -> UTCTime -> Text -> Either Text Int64
verifyJwt settings now rawToken = do
    let segments = BS8.split '.' (TE.encodeUtf8 (T.strip rawToken))
    case segments of
        [headerSegment, payloadSegment, signatureSegment] -> do
            let signingInput = BS.intercalate "." [headerSegment, payloadSegment]
                expectedSignature = signSegment settings signingInput
            if not (expectedSignature `constEq` signatureSegment)
                then Left "Invalid token signature."
                else do
                    payloadBytes <- firstText "Invalid token payload encoding." $ convertFromBase Base64URLUnpadded payloadSegment
                    claims <- firstText "Invalid token payload." $ eitherDecodeStrict' payloadBytes
                    validateClaims settings now claims
        _ -> Left "Invalid token format."

bearerTokenFromHeader :: Maybe BS.ByteString -> Either Text (Maybe Text)
bearerTokenFromHeader Nothing = Right Nothing
bearerTokenFromHeader (Just rawHeader) =
    case T.words (T.strip (TE.decodeUtf8 rawHeader)) of
        [] -> Right Nothing
        ["Bearer", token] | not (T.null token) -> Right (Just token)
        ["bearer", token] | not (T.null token) -> Right (Just token)
        _ -> Left "Invalid Authorization header."

validateClaims :: AppSettings -> UTCTime -> JwtClaims -> Either Text Int64
validateClaims settings now claims
    | jwtClaimsExp claims <= utcTimeToEpoch now = Left "Token expired."
    | maybe False (\issuer -> jwtClaimsIss claims /= Just issuer) (normalizeIssuer settings) = Left "Invalid token issuer."
    | otherwise = Right (jwtClaimsSub claims)

normalizeIssuer :: AppSettings -> Maybe Text
normalizeIssuer settings =
    case appJwtIssuer settings of
        Just issuer ->
            let trimmed = T.strip issuer
            in if T.null trimmed then Nothing else Just trimmed
        Nothing -> Nothing

signSegment :: AppSettings -> BS.ByteString -> BS.ByteString
signSegment settings input =
    let secret = TE.encodeUtf8 (appJwtSecret settings)
        digest = convert (hmac secret input :: HMAC SHA256)
    in encodeSegment digest

encodeSegment :: BS.ByteString -> BS.ByteString
encodeSegment = convertToBase Base64URLUnpadded

utcTimeToEpoch :: UTCTime -> Int64
utcTimeToEpoch = floor . utcTimeToPOSIXSeconds

firstText :: Text -> Either String a -> Either Text a
firstText prefix =
    either (\err -> Left (prefix <> " " <> T.pack err)) Right
