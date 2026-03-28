{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Location.Regions
    ( CountrySeed(..)
    , CountryStateSeed(..)
    , countrySeedsForSuffixes
    , countryStateSeedsForSuffixes
    ) where

import Import.NoFoundation
import Data.FileEmbed (embedFile)
import qualified Data.Set as Set
import qualified Data.Text as T
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.Read as TextRead
import qualified Prelude as P

data CountrySeed = CountrySeed
    { countrySeedCode :: Text
    , countrySeedName :: Text
    , countrySeedLocalName :: Maybe Text
    , countrySeedSortOrder :: Int
    }

data CountryStateSeed = CountryStateSeed
    { countryStateSeedCountryCode :: Text
    , countryStateSeedCountryName :: Text
    , countryStateSeedCode :: Text
    , countryStateSeedName :: Text
    , countryStateSeedLocalName :: Maybe Text
    , countryStateSeedType :: Maybe Text
    , countryStateSeedSortOrder :: Int
    }

countrySeedsForSuffixes :: [Text] -> Either Text [CountrySeed]
countrySeedsForSuffixes suffixes = do
    texts <- traverse lookupCountrySeedCsv (normalizeSuffixes suffixes)
    parseCountrySeeds (T.intercalate "\n" texts)

countryStateSeedsForSuffixes :: [Text] -> Either Text [CountryStateSeed]
countryStateSeedsForSuffixes suffixes = do
    texts <- traverse lookupCountryStateSeedCsv (normalizeSuffixes suffixes)
    parseCountryStateSeeds (T.intercalate "\n" texts)

embeddedCountriesKoCsv :: Text
embeddedCountriesKoCsv =
    TextEncoding.decodeUtf8 $(embedFile "config/seeds/countries_ko.csv")

embeddedCountriesAnzCsv :: Text
embeddedCountriesAnzCsv =
    TextEncoding.decodeUtf8 $(embedFile "config/seeds/countries_anz.csv")

embeddedCountriesEuCsv :: Text
embeddedCountriesEuCsv =
    TextEncoding.decodeUtf8 $(embedFile "config/seeds/countries_eu.csv")

embeddedCountryStatesKoCsv :: Text
embeddedCountryStatesKoCsv =
    TextEncoding.decodeUtf8 $(embedFile "config/seeds/country_states_ko.csv")

embeddedCountryStatesAnzCsv :: Text
embeddedCountryStatesAnzCsv =
    TextEncoding.decodeUtf8 $(embedFile "config/seeds/country_states_anz.csv")

embeddedCountryStatesEuCsv :: Text
embeddedCountryStatesEuCsv =
    TextEncoding.decodeUtf8 $(embedFile "config/seeds/country_states_eu.csv")

normalizeSuffixes :: [Text] -> [Text]
normalizeSuffixes rawSuffixes =
    let cleaned = P.map (T.toLower . T.strip) rawSuffixes
        nonEmpty = P.filter (not . T.null) cleaned
        step (seen, acc) suffix
            | Set.member suffix seen = (seen, acc)
            | otherwise = (Set.insert suffix seen, acc <> [suffix])
        (_, deduped) = P.foldl step (Set.empty, []) nonEmpty
    in if P.null deduped then ["ko"] else deduped

lookupCountrySeedCsv :: Text -> Either Text Text
lookupCountrySeedCsv suffix =
    case suffix of
        "ko" -> Right embeddedCountriesKoCsv
        "anz" -> Right embeddedCountriesAnzCsv
        "eu" -> Right embeddedCountriesEuCsv
        _ -> Left ("unsupported country seed suffix: " <> suffix)

lookupCountryStateSeedCsv :: Text -> Either Text Text
lookupCountryStateSeedCsv suffix =
    case suffix of
        "ko" -> Right embeddedCountryStatesKoCsv
        "anz" -> Right embeddedCountryStatesAnzCsv
        "eu" -> Right embeddedCountryStatesEuCsv
        _ -> Left ("unsupported country state seed suffix: " <> suffix)

parseCountrySeeds :: Text -> Either Text [CountrySeed]
parseCountrySeeds raw =
    traverse parseCountryRow (dropCsvHeader "country_code,country_name,country_name_local,sort_order" (csvLines raw))

parseCountryStateSeeds :: Text -> Either Text [CountryStateSeed]
parseCountryStateSeeds raw =
    traverse parseCountryStateRow (dropCsvHeader "country_code,country_name,state_code,state_name,state_name_local,state_type,sort_order" (csvLines raw))

csvLines :: Text -> [Text]
csvLines raw =
    P.filter (\line -> not (T.null line)) (P.map T.strip (T.lines raw))

dropCsvHeader :: Text -> [Text] -> [Text]
dropCsvHeader _ [] = []
dropCsvHeader expectedHeader (header:rows)
    | T.toLower header == expectedHeader = rows
    | otherwise = header : rows

parseCountryRow :: Text -> Either Text CountrySeed
parseCountryRow rawLine =
    case P.map T.strip (T.splitOn "," rawLine) of
        [code, name, localName, sortOrderText] ->
            CountrySeed
                <$> validateField "country_code" code
                <*> validateField "country_name" name
                <*> pure (optionalField localName)
                <*> parseNumber "sort_order" sortOrderText
        _ ->
            Left ("invalid country seed row: " <> rawLine)

parseCountryStateRow :: Text -> Either Text CountryStateSeed
parseCountryStateRow rawLine =
    case P.map T.strip (T.splitOn "," rawLine) of
        [countryCode, countryName, stateCode, stateName, stateLocalName, stateType, sortOrderText] ->
            CountryStateSeed
                <$> validateField "country_code" countryCode
                <*> validateField "country_name" countryName
                <*> validateField "state_code" stateCode
                <*> validateField "state_name" stateName
                <*> pure (optionalField stateLocalName)
                <*> pure (optionalField stateType)
                <*> parseNumber "sort_order" sortOrderText
        _ ->
            Left ("invalid country state seed row: " <> rawLine)

validateField :: Text -> Text -> Either Text Text
validateField fieldName value
    | T.null value = Left ("location seed field is empty: " <> fieldName)
    | otherwise = Right value

optionalField :: Text -> Maybe Text
optionalField value
    | T.null value = Nothing
    | otherwise = Just value

parseNumber :: Text -> Text -> Either Text Int
parseNumber fieldName rawValue =
    case TextRead.decimal rawValue of
        Right (value, rest)
            | T.null (T.strip rest) -> Right value
        _ -> Left ("invalid number in location seed for " <> fieldName <> ": " <> rawValue)
