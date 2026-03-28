{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}

module Company.Categories
    ( CompanyMajorCategory(..)
    , CompanyMinorCategory(..)
    , companyMajorCategories
    , allCompanyMinorCategories
    , findCompanyMajorCategory
    , findCompanyMinorCategory
    , loadCompanyMajorCategories
    , loadAllCompanyMinorCategories
    ) where

import Import.NoFoundation
import Data.FileEmbed (embedFile)
import qualified Data.List as L
import qualified Data.Text as T
import qualified Data.Text.Encoding as TextEncoding
import qualified Data.Text.IO as TextIO
import qualified Data.Text.Read as TextRead
import qualified Prelude as P

data CompanyMajorCategory = CompanyMajorCategory
    { companyMajorCategoryCode :: Text
    , companyMajorCategoryName :: Text
    , companyMajorCategoryChildren :: [CompanyMinorCategory]
    }

data CompanyMinorCategory = CompanyMinorCategory
    { companyMinorCategoryCode :: Text
    , companyMinorCategoryName :: Text
    , companyMinorCategoryMajorCode :: Text
    , companyMinorCategoryMajorName :: Text
    , companyMinorCategorySortOrder :: Int
    }

data CompanyCategorySeedRow = CompanyCategorySeedRow
    { seedMajorCode :: Text
    , seedMajorName :: Text
    , seedMajorSort :: Int
    , seedMinorCode :: Text
    , seedMinorName :: Text
    , seedMinorSort :: Int
    }

companyCategoriesSeedFilePath :: FilePath
companyCategoriesSeedFilePath = "config/seeds/company_categories.csv"

companyMajorCategories :: [CompanyMajorCategory]
companyMajorCategories =
    either (error . unpack) id $
        parseCompanyMajorCategories embeddedCompanyCategoriesCsv

allCompanyMinorCategories :: [CompanyMinorCategory]
allCompanyMinorCategories =
    P.concatMap companyMajorCategoryChildren companyMajorCategories

findCompanyMajorCategory :: Text -> Maybe CompanyMajorCategory
findCompanyMajorCategory majorCode =
    L.find (\major -> companyMajorCategoryCode major == majorCode) companyMajorCategories

findCompanyMinorCategory :: Text -> Maybe CompanyMinorCategory
findCompanyMinorCategory minorCode =
    L.find (\minor -> companyMinorCategoryCode minor == minorCode) allCompanyMinorCategories

loadCompanyMajorCategories :: IO [CompanyMajorCategory]
loadCompanyMajorCategories = do
    csvText <- TextIO.readFile companyCategoriesSeedFilePath
    pure $
        either (error . unpack) id $
            parseCompanyMajorCategories csvText

loadAllCompanyMinorCategories :: IO [CompanyMinorCategory]
loadAllCompanyMinorCategories =
    P.concatMap companyMajorCategoryChildren <$> loadCompanyMajorCategories

embeddedCompanyCategoriesCsv :: Text
embeddedCompanyCategoriesCsv =
    TextEncoding.decodeUtf8 $(embedFile "config/seeds/company_categories.csv")

parseCompanyMajorCategories :: Text -> Either Text [CompanyMajorCategory]
parseCompanyMajorCategories raw = do
    rows <- traverse parseSeedRow (dropCsvHeader (csvLines raw))
    let groupedRows =
            L.groupBy
                (\left right -> seedMajorCode left == seedMajorCode right)
                (L.sortOn (\row -> (seedMajorSort row, seedMinorSort row)) rows)
    traverse buildMajorCategory groupedRows

buildMajorCategory :: [CompanyCategorySeedRow] -> Either Text CompanyMajorCategory
buildMajorCategory [] =
    Left "company category seed is empty"
buildMajorCategory rows@(firstRow:_) =
    Right $
        CompanyMajorCategory
            { companyMajorCategoryCode = seedMajorCode firstRow
            , companyMajorCategoryName = seedMajorName firstRow
            , companyMajorCategoryChildren = map buildMinorCategory rows
            }

buildMinorCategory :: CompanyCategorySeedRow -> CompanyMinorCategory
buildMinorCategory row =
    CompanyMinorCategory
        { companyMinorCategoryCode = seedMinorCode row
        , companyMinorCategoryName = seedMinorName row
        , companyMinorCategoryMajorCode = seedMajorCode row
        , companyMinorCategoryMajorName = seedMajorName row
        , companyMinorCategorySortOrder = seedMajorSort row * 100 + seedMinorSort row
        }

csvLines :: Text -> [Text]
csvLines =
    filter (not . T.null) . map T.strip . T.lines

dropCsvHeader :: [Text] -> [Text]
dropCsvHeader [] = []
dropCsvHeader (header:rows)
    | T.toLower header == "major_code,major_name,major_sort,minor_code,minor_name,minor_sort" = rows
    | otherwise = header : rows

parseSeedRow :: Text -> Either Text CompanyCategorySeedRow
parseSeedRow rawLine =
    case map T.strip (T.splitOn "," rawLine) of
        [majorCode, majorName, majorSortText, minorCode, minorName, minorSortText] ->
            CompanyCategorySeedRow
                <$> validateField "major_code" majorCode
                <*> validateField "major_name" majorName
                <*> parseNumber "major_sort" majorSortText
                <*> validateField "minor_code" minorCode
                <*> validateField "minor_name" minorName
                <*> parseNumber "minor_sort" minorSortText
        _ ->
            Left ("invalid company category seed row: " <> rawLine)

validateField :: Text -> Text -> Either Text Text
validateField fieldName value
    | T.null value = Left ("company category seed field is empty: " <> fieldName)
    | otherwise = Right value

parseNumber :: Text -> Text -> Either Text Int
parseNumber fieldName rawValue =
    case TextRead.decimal rawValue of
        Right (value, rest)
            | T.null (T.strip rest) -> Right value
        _ -> Left ("invalid number in company category seed for " <> fieldName <> ": " <> rawValue)
