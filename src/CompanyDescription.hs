{-# LANGUAGE OverloadedStrings #-}

module CompanyDescription
    ( prepareCompanyDescription
    ) where

import Import.NoFoundation
import qualified Data.Text as T
import qualified Prelude as P

prepareCompanyDescription :: Text -> Either Text Text
prepareCompanyDescription raw
    | containsDangerousHtml trimmed = Left "description contains unsupported HTML"
    | isVisuallyEmptyHtml normalized = Left "description is required"
    | looksLikeHtml trimmed = Right trimmed
    | otherwise = Right (plainTextToHtml trimmed)
  where
    trimmed = T.strip raw
    normalized =
        T.strip $
            T.replace "&nbsp;" " " $
            T.replace "&#160;" " " trimmed

containsDangerousHtml :: Text -> Bool
containsDangerousHtml raw =
    let lowered = T.toLower raw
        blockedPatterns =
            [ "<script"
            , "</script"
            , "javascript:"
            , "vbscript:"
            , "data:text/html"
            , "srcdoc="
            , "<iframe"
            , "<object"
            , "<embed"
            , "<form"
            , "<input"
            , "<button"
            , "<style"
            , "<link"
            , "<meta"
            , "onerror="
            , "onload="
            , "onclick="
            , "onmouseenter="
            , "onfocus="
            ]
    in any (`T.isInfixOf` lowered) blockedPatterns

isVisuallyEmptyHtml :: Text -> Bool
isVisuallyEmptyHtml raw =
    let plainText =
            T.strip $
                T.replace "\160" " " $
                T.replace "&nbsp;" " " $
                stripHtmlTags raw
    in T.null plainText

stripHtmlTags :: Text -> Text
stripHtmlTags = go False
  where
    go _ "" = ""
    go inside text =
        case T.uncons text of
            Nothing -> ""
            Just (ch, rest)
                | ch == '<' -> go True rest
                | ch == '>' -> go False rest
                | inside -> go True rest
                | otherwise -> T.cons ch (go False rest)

looksLikeHtml :: Text -> Bool
looksLikeHtml raw =
    let lowered = T.toLower raw
        tagHints =
            [ "<p"
            , "<div"
            , "<br"
            , "<span"
            , "<strong"
            , "<b"
            , "<em"
            , "<i"
            , "<u"
            , "<ol"
            , "<ul"
            , "<li"
            , "<img"
            , "<a"
            , "<blockquote"
            , "<h1"
            , "<h2"
            , "<h3"
            , "<h4"
            , "<h5"
            , "<h6"
            ]
    in any (`T.isInfixOf` lowered) tagHints

plainTextToHtml :: Text -> Text
plainTextToHtml raw =
    T.concat $ map renderParagraph (splitParagraphs (T.lines raw))
  where
    renderParagraph paragraphLines =
        "<p>" <> T.intercalate "<br>" (map escapeHtml paragraphLines) <> "</p>"

splitParagraphs :: [Text] -> [[Text]]
splitParagraphs = go [] []
  where
    go current acc [] =
        reverse $
            if P.null current
                then acc
                else reverse current : acc
    go current acc (line:rest)
        | T.null (T.strip line) =
            if P.null current
                then go [] acc rest
                else go [] (reverse current : acc) rest
        | otherwise = go (line : current) acc rest

escapeHtml :: Text -> Text
escapeHtml =
    T.concatMap escapeChar
  where
    escapeChar '&' = "&amp;"
    escapeChar '<' = "&lt;"
    escapeChar '>' = "&gt;"
    escapeChar '"' = "&quot;"
    escapeChar '\'' = "&#39;"
    escapeChar ch = T.singleton ch
