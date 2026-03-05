{-# LANGUAGE OverloadedStrings #-}
module Forum.Tag
    ( parseTagList
    , syncPostTags
    , loadPostTagsMap
    ) where

import Import
import qualified Data.Char as Char
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Text as T
import qualified Prelude as P

parseTagList :: Maybe Text -> [Text]
parseTagList mRaw =
    dedupe $ mapMaybe normalizeTag chunks
  where
    chunks =
        case mRaw of
            Nothing -> []
            Just raw ->
                let commaSplit = T.splitOn "," raw
                in concatMap T.words commaSplit
    dedupe = P.foldl' step []
    step acc t = if t `elem` acc then acc else acc P.++ [t]

normalizeTag :: Text -> Maybe Text
normalizeTag raw =
    let stripped = T.dropWhile (== '#') (T.strip raw)
        filtered = T.filter (\c -> Char.isAlphaNum c || c == '-' || c == '_') stripped
        lowered = T.toLower filtered
    in if T.null lowered then Nothing else Just lowered

syncPostTags :: MonadIO m => PostId -> [Text] -> ReaderT SqlBackend m ()
syncPostTags postId rawTags = do
    deleteWhere [PostTagMapPost ==. postId]
    let tags = dedupe rawTags
    forM_ tags $ \tagName -> do
        mTag <- getBy $ UniquePostTag tagName
        tagId <- case mTag of
            Just (Entity existingId _) -> pure existingId
            Nothing -> insert $ PostTag tagName
        void $ insertBy $ PostTagMap postId tagId
  where
    dedupe = P.foldl' step []
    step acc t = if t `elem` acc then acc else acc P.++ [t]

loadPostTagsMap :: MonadIO m => [PostId] -> ReaderT SqlBackend m (Map.Map PostId [Text])
loadPostTagsMap postIds = do
    if P.null postIds
        then pure Map.empty
        else do
            mappings <- selectList [PostTagMapPost <-. postIds] []
            let tagIds = L.nub $ map (postTagMapTag . entityVal) mappings
            tags <- if P.null tagIds then pure [] else selectList [PostTagId <-. tagIds] []
            let tagNameMap = Map.fromList $ map (\(Entity tid tag) -> (tid, postTagName tag)) tags
                addOne acc (Entity _ m) =
                    let name = Map.findWithDefault ("" :: Text) (postTagMapTag m) tagNameMap
                    in if T.null name
                        then acc
                        else Map.insertWith (P.++) (postTagMapPost m) [name] acc
            pure $ P.foldl' addOne Map.empty mappings
