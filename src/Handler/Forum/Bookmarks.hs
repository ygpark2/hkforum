{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Bookmarks (getBookmarksR) where

import Import
import Forum.Tag (loadPostTagsMap)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Text.Blaze (preEscapedText)
import qualified Prelude as P

getBookmarksR :: Handler Html
getBookmarksR = do
    userId <- requireAuthId
    bookmarkRows <- runDB $ selectList [PostBookmarkUser ==. userId] [Desc PostBookmarkCreatedAt, LimitTo 200]
    let bookmarkedPostIds = map (postBookmarkPost . entityVal) bookmarkRows
    posts <-
        if P.null bookmarkedPostIds
            then pure []
            else runDB $ selectList [PostId <-. bookmarkedPostIds] []
    comments <-
        if P.null bookmarkedPostIds
            then pure []
            else runDB $ selectList [CommentPost <-. bookmarkedPostIds] []
    likes <-
        if P.null bookmarkedPostIds
            then pure []
            else runDB $ selectList [PostLikePost <-. bookmarkedPostIds] []
    views <-
        if P.null bookmarkedPostIds
            then pure []
            else runDB $ selectList [PostViewPost <-. bookmarkedPostIds] []
    tagsByPost <- runDB $ loadPostTagsMap bookmarkedPostIds
    let postMap = Map.fromList $ map (\ent@(Entity pid _) -> (pid, ent)) posts
        orderedPosts = mapMaybe (\(Entity _ pb) -> Map.lookup (postBookmarkPost pb) postMap) bookmarkRows
        boardIds = L.nub $ map (postBoard . entityVal) orderedPosts
        authorIds = L.nub $ map (postAuthor . entityVal) orderedPosts
    boards <- if P.null boardIds then pure [] else runDB $ selectList [BoardId <-. boardIds] []
    users <- if P.null authorIds then pure [] else runDB $ selectList [UserId <-. authorIds] []
    likedRows <-
        if P.null bookmarkedPostIds
            then pure []
            else runDB $ selectList [PostLikeUser ==. userId, PostLikePost <-. bookmarkedPostIds] []
    let boardMap = Map.fromList $ map (\(Entity bid b) -> (bid, boardName b)) boards
        userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        boardLabel bid = Map.findWithDefault ("Unknown board" :: Text) bid boardMap
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        likeCountMap =
            P.foldl'
                (\acc (Entity _ l) -> Map.insertWith (+) (postLikePost l) (1 :: Int) acc)
                Map.empty
                likes
        viewCountMap =
            P.foldl'
                (\acc (Entity _ v) -> Map.insertWith (+) (postViewPost v) (1 :: Int) acc)
                Map.empty
                views
        bookmarkSet = Set.fromList bookmarkedPostIds
        likeSet = Set.fromList $ map (postLikePost . entityVal) likedRows
        isLiked pid = Set.member pid likeSet
        isBookmarked pid = Set.member pid bookmarkSet
        likeCountFor pid = Map.findWithDefault 0 pid likeCountMap
        viewCountFor pid = Map.findWithDefault 0 pid viewCountMap
        tagsFor pid = Map.findWithDefault [] pid tagsByPost
        likeState pid = if isLiked pid then ("true" :: Text) else "false"
        likeIcon pid = if isLiked pid then ("♥" :: Text) else "♡"
        likeLabel pid = if isLiked pid then ("Liked" :: Text) else "Like"
        bookmarkState pid = if isBookmarked pid then ("true" :: Text) else "false"
        commentCountMap =
            P.foldl'
                (\acc (Entity _ c) -> Map.insertWith (+) (commentPost c) (1 :: Int) acc)
                Map.empty
                comments
        commentCountFor pid = Map.findWithDefault 0 pid commentCountMap
    defaultLayout $ do
        setTitle $ preEscapedText "HKForum | Bookmarks"
        $(widgetFile "forum/bookmarks")
