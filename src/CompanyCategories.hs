{-# LANGUAGE OverloadedStrings #-}

module CompanyCategories
    ( CompanyMajorCategory(..)
    , CompanyMinorCategory(..)
    , companyMajorCategories
    , allCompanyMinorCategories
    , findCompanyMajorCategory
    , findCompanyMinorCategory
    ) where

import Import.NoFoundation
import qualified Data.List as L
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

companyMajorCategories :: [CompanyMajorCategory]
companyMajorCategories =
    P.zipWith buildMajor [0 :: Int ..]
        [ ("agri-forestry-fishery", "농/임/어업",
            [ ("01", "농업")
            , ("02", "임업")
            , ("03", "어업")
            ])
        , ("mining", "광업",
            [ ("05", "석탄/원유")
            , ("06", "금속광업")
            , ("07", "비금속광물")
            ])
        , ("manufacturing", "제조업(C)",
            [ ("10", "식료품")
            , ("11", "음료")
            , ("13", "섬유")
            , ("15", "가죽/가방")
            , ("17", "펄프/종이")
            , ("20", "화학")
            , ("21", "의약품")
            , ("23", "비금속광물")
            , ("24", "1차 금속")
            , ("25", "금속가공")
            , ("26", "전자부품/컴퓨터")
            , ("29", "기타기계")
            , ("30", "자동차")
            , ("31", "가구")
            ])
        , ("utilities-waste", "전기/폐기물",
            [ ("35", "전기/가스/증기")
            , ("38", "폐기물 수집/처리")
            ])
        , ("construction", "건설업(F)",
            [ ("41", "종합건설")
            , ("42", "전문공사")
            ])
        , ("commerce-service", "도소매/서비스",
            [ ("45", "자동차 도소매")
            , ("46", "도매업")
            , ("47", "소매업")
            , ("49-52", "운수업")
            , ("55", "숙박업")
            , ("56", "음식점업")
            ])
        , ("info-finance-professional", "정보/금융/전문",
            [ ("58", "출판")
            , ("61", "통신업")
            , ("62-63", "정보통신")
            , ("64-66", "금융/보험")
            , ("70-73", "전문/과학/기술")
            , ("74-75", "사업지원")
            ])
        , ("education-health-culture", "교육/보건/문화",
            [ ("80", "교육")
            , ("85", "보건/사회복지")
            , ("90-91", "예술/스포츠")
            ])
        ]
  where
    buildMajor majorIndex (majorCode, majorName, minors) =
        CompanyMajorCategory
            { companyMajorCategoryCode = majorCode
            , companyMajorCategoryName = majorName
            , companyMajorCategoryChildren =
                P.zipWith
                    (\minorIndex (minorCode, minorName) ->
                        CompanyMinorCategory
                            { companyMinorCategoryCode = minorCode
                            , companyMinorCategoryName = minorName
                            , companyMinorCategoryMajorCode = majorCode
                            , companyMinorCategoryMajorName = majorName
                            , companyMinorCategorySortOrder = majorIndex * 100 + minorIndex
                            })
                    [0 :: Int ..]
                    minors
            }

allCompanyMinorCategories :: [CompanyMinorCategory]
allCompanyMinorCategories =
    P.concatMap companyMajorCategoryChildren companyMajorCategories

findCompanyMajorCategory :: Text -> Maybe CompanyMajorCategory
findCompanyMajorCategory majorCode =
    L.find (\major -> companyMajorCategoryCode major == majorCode) companyMajorCategories

findCompanyMinorCategory :: Text -> Maybe CompanyMinorCategory
findCompanyMinorCategory minorCode =
    L.find (\minor -> companyMinorCategoryCode minor == minorCode) allCompanyMinorCategories
