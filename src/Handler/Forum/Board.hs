{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
module Handler.Forum.Board (getBoardR, postBoardR) where

import Import
import Forum.Tag (loadPostTagsMap, parseTagList, syncPostTags)
import qualified Data.List as L
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as T
import Text.Blaze (preEscapedText)
import qualified Prelude as P

getBoardR :: BoardId -> Handler Html
getBoardR boardId = do
    board <- runDB $ get404 boardId
    posts <- runDB $ selectList [PostBoard ==. boardId] [Desc PostCreatedAt]
    let authorIds = L.nub $ map (postAuthor . entityVal) posts
    users <- if P.null authorIds
        then pure []
        else runDB $ selectList [UserId <-. authorIds] []
    comments <- if P.null posts
        then pure []
        else runDB $ selectList [CommentPost <-. map entityKey posts] []
    let postIds = map entityKey posts
    likes <- if P.null postIds
        then pure []
        else runDB $ selectList [PostLikePost <-. postIds] []
    views <- if P.null postIds
        then pure []
        else runDB $ selectList [PostViewPost <-. postIds] []
    tagsByPost <- runDB $ loadPostTagsMap postIds
    let userMap = Map.fromList $ map (\(Entity uid user) -> (uid, userIdent user)) users
        authorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        commentCountMap =
            P.foldl'
                (\acc (Entity _ c) -> Map.insertWith (+) (commentPost c) (1 :: Int) acc)
                Map.empty
                comments
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
        commentCountFor pid = Map.findWithDefault 0 pid commentCountMap
        likeCountFor pid = Map.findWithDefault 0 pid likeCountMap
        viewCountFor pid = Map.findWithDefault 0 pid viewCountMap
        tagsFor pid = Map.findWithDefault [] pid tagsByPost
    mViewerId <- maybeAuthId
    bookmarkedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null postIds
                then pure []
                else runDB $ selectList [PostBookmarkUser ==. viewerId, PostBookmarkPost <-. postIds] []
    likedRows <- case mViewerId of
        Nothing -> pure []
        Just viewerId ->
            if P.null postIds
                then pure []
                else runDB $ selectList [PostLikeUser ==. viewerId, PostLikePost <-. postIds] []
    let likeSet = Set.fromList $ map (postLikePost . entityVal) likedRows
        bookmarkSet = Set.fromList $ map (postBookmarkPost . entityVal) bookmarkedRows
        isLiked pid = Set.member pid likeSet
        isBookmarked pid = Set.member pid bookmarkSet
        likeState pid = if isLiked pid then ("true" :: Text) else "false"
        likeIcon pid = if isLiked pid then ("♥" :: Text) else "♡"
        likeLabel pid = if isLiked pid then ("Liked" :: Text) else "Like"
        bookmarkState pid = if isBookmarked pid then ("true" :: Text) else "false"
    req <- getRequest
    let mCsrfToken = reqToken req
    defaultLayout $ do
        setTitle $ preEscapedText $ boardName board <> " - HKForum"
        $(widgetFile "forum/board")

postBoardR :: BoardId -> Handler Html
postBoardR boardId = do
    userId <- requireAuthId
    _ <- runDB $ get404 boardId
    titleRaw <- runInputPost $ ireq textField "title"
    mTags <- runInputPost $ iopt textField "tags"
    contentRaw <- runInputPost $ ireq textField "content"
    let title = T.strip titleRaw
        content = T.strip contentRaw
    when (T.null title) $ invalidArgs ["title is required"]
    when (T.null content) $ invalidArgs ["content is required"]
    now <- liftIO getCurrentTime
    postId <- runDB $ insert Post
        { postTitle = title
        , postContent = content
        , postAuthor = userId
        , postBoard = boardId
        , postCreatedAt = now
        , postUpdatedAt = now
        }
    runDB $ syncPostTags postId (parseTagList mTags)
    runDB $ update boardId [BoardPostCount +=. 1]
    redirect $ BoardR boardId
