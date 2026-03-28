{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}

module Handler.Admin.Moderation
    ( getAdminModerationR
    , postAdminModerationActionR
    , getAdminModerationLogsR
    ) where

import Import
import qualified Prelude as P
import qualified Data.Text as T
import qualified Data.Map.Strict as Map
import qualified Data.List as L
import qualified Data.Text.Encoding as TextEncoding
import Data.ByteString.Builder (toLazyByteString)
import qualified Data.ByteString.Lazy as LBS
import Database.Persist.Sql (fromSqlKey, toSqlKey)
import Text.Blaze (preEscapedText)
import Text.Read (readMaybe)

getAdminModerationR :: Handler Html
getAdminModerationR = do
    req <- getRequest
    let mCsrfToken = reqToken req
    q <- fromMaybe "" <$> lookupGetParam "q"
    userQuery <- fromMaybe "" <$> lookupGetParam "user"
    typeQuery <- fromMaybe "" <$> lookupGetParam "type"
    pageParam <- lookupGetParam "page"
    perPageParam <- lookupGetParam "per_page"
    postFlags <- runDB $ selectList [] [Desc PostFlagCreatedAt]
    postBlocks <- runDB $ selectList [] [Desc PostBlockCreatedAt]

    let userIds =
            L.nub $
                map (postFlagUser . entityVal) postFlags
                    P.++ map (postBlockUser . entityVal) postBlocks
        postIds =
            L.nub $
                map (postFlagPost . entityVal) postFlags
                    P.++ map (postBlockPost . entityVal) postBlocks

    users <- if P.null userIds then pure [] else runDB $ selectList [UserId <-. userIds] []
    posts <- if P.null postIds then pure [] else runDB $ selectList [PostId <-. postIds] []

    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        postMap = Map.fromList $ map (\(Entity pid p) -> (pid, p)) posts
        userIdentFor uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        postTitleFor pid = maybe ("Unknown" :: Text) postTitle (Map.lookup pid postMap)
        postPreview = buildPreview 160 . postContent
        flagPosts =
            map
                (\(Entity fid f) ->
                    let pid = postFlagPost f
                        preview = maybe ("Unknown" :: Text) postPreview (Map.lookup pid postMap)
                    in ( fid
                       , userIdentFor (postFlagUser f)
                       , postTitleFor pid
                       , preview
                       , formatTime defaultTimeLocale "%F %R" (postFlagCreatedAt f)
                       )
                )
                postFlags
        blockPosts =
            map
                (\(Entity bid f) ->
                    let pid = postBlockPost f
                        preview = maybe ("Unknown" :: Text) postPreview (Map.lookup pid postMap)
                    in ( bid
                       , userIdentFor (postBlockUser f)
                       , postTitleFor pid
                       , preview
                       , formatTime defaultTimeLocale "%F %R" (postBlockCreatedAt f)
                       )
                )
                postBlocks

    let page = max 1 $ fromMaybe 1 (pageParam >>= (\t -> readMaybe (T.unpack t)))
        perPageRaw = fromMaybe 10 (perPageParam >>= (\t -> readMaybe (T.unpack t)))
        perPage = max 5 (min 50 perPageRaw)
        qLower = T.toLower q
        userLower = T.toLower userQuery
        typeLower = T.toLower typeQuery
        matchesText txt = T.null qLower || T.isInfixOf qLower (T.toLower txt)
        matchesUser txt = T.null userLower || T.isInfixOf userLower (T.toLower txt)
        matchesType key = T.null typeLower || typeLower == key
        applyFiltersPost rows =
            P.filter (\(_, u, t, p, _) -> matchesUser u && (matchesText t || matchesText p)) rows
        flagPostsFiltered =
            if matchesType "post-flag" then applyFiltersPost flagPosts else []
        blockPostsFiltered =
            if matchesType "post-block" then applyFiltersPost blockPosts else []
        paginate rows =
            let total = length rows
                totalPages = max 1 $ ceiling (fromIntegral total / (fromIntegral perPage :: Double))
                start = (page - 1) * perPage
                pageRows = take perPage (drop start rows)
            in (pageRows, totalPages)
        (flagPostsPage, flagPostsPages) = paginate flagPostsFiltered
        (blockPostsPage, blockPostsPages) = paginate blockPostsFiltered
        listTypeOptions =
            [ ("", "All")
            , ("post-flag", "Post Flags")
            , ("post-block", "Post Blocks")
            ] :: [(Text, Text)]
        baseParams =
            [ ("q", if T.null q then Nothing else Just q)
            , ("user", if T.null userQuery then Nothing else Just userQuery)
            , ("type", if T.null typeQuery then Nothing else Just typeQuery)
            , ("per_page", Just (T.pack (show perPage)))
            ]
        queryBase =
            TextEncoding.decodeUtf8
                $ LBS.toStrict
                $ toLazyByteString
                $ renderQueryText True baseParams
        pagePrefix =
            if T.null queryBase
                then "?page="
                else queryBase <> "&page="
    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Moderation"
        let adminBody = $(widgetFile "admin/moderation/list")
            activeKey = ("moderation" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

getAdminModerationLogsR :: Handler Html
getAdminModerationLogsR = do
    q <- fromMaybe "" <$> lookupGetParam "q"
    userQuery <- fromMaybe "" <$> lookupGetParam "user"
    typeQuery <- fromMaybe "" <$> lookupGetParam "type"
    pageParam <- lookupGetParam "page"
    perPageParam <- lookupGetParam "per_page"
    let page = max 1 $ fromMaybe 1 (pageParam >>= (\t -> readMaybe (T.unpack t)))
        perPageRaw = fromMaybe 20 (perPageParam >>= (\t -> readMaybe (T.unpack t)))
        perPage = max 5 (min 50 perPageRaw)
        qLower = T.toLower q
        userLower = T.toLower userQuery
        typeLower = T.toLower typeQuery
        matchesText txt = T.null qLower || T.isInfixOf qLower (T.toLower txt)
        matchesUser txt = T.null userLower || T.isInfixOf userLower (T.toLower txt)
        matchesType key = T.null typeLower || typeLower == key

    logs <- runDB $ selectList [] [Desc ModerationLogCreatedAt]
    let actorIds = L.nub $ map (moderationLogActor . entityVal) logs
    users <- if P.null actorIds then pure [] else runDB $ selectList [UserId <-. actorIds] []
    let userMap = Map.fromList $ map (\(Entity uid u) -> (uid, userIdent u)) users
        actorName uid = Map.findWithDefault ("Unknown" :: Text) uid userMap
        filteredLogs =
            P.filter
                (\(Entity _ l) ->
                    matchesUser (actorName (moderationLogActor l))
                        && matchesType (moderationLogTargetType l)
                        && (matchesText (moderationLogTargetId l) || matchesText (moderationLogAction l))
                )
                logs
        postIds =
            L.nub
                [ toSqlKey pid
                | Entity _ l <- filteredLogs
                , moderationLogTargetType l `elem` ["post-flag", "post-block"]
                , Just pid <- [readMaybe (T.unpack (moderationLogTargetId l)) :: Maybe Int64]
                ]
    postsById <- if P.null postIds then pure [] else runDB $ selectList [PostId <-. postIds] []
    let postMap = Map.fromList $ map (\(Entity pid p) -> (pid, p)) postsById
        total = length filteredLogs
        totalPages = max 1 $ ceiling (fromIntegral total / (fromIntegral perPage :: Double))
        start = (page - 1) * perPage
        pageLogs = take perPage (drop start filteredLogs)
        logRows =
            map
                (\(Entity _ l) ->
                    let targetType = moderationLogTargetType l
                        targetId = moderationLogTargetId l
                        route =
                            case readMaybe (T.unpack targetId) :: Maybe Int64 of
                                Just pid
                                    | targetType `elem` ["post-flag", "post-block"]
                                        && Map.member (toSqlKey pid) postMap ->
                                            Just (PostR (toSqlKey pid))
                                _ -> Nothing
                    in ( targetType
                       , targetId
                       , moderationLogAction l
                       , actorName (moderationLogActor l)
                       , formatTime defaultTimeLocale "%F %R" (moderationLogCreatedAt l)
                       , route
                       )
                )
                pageLogs
        listTypeOptions =
            [ ("", "All")
            , ("post-flag", "Post Flags")
            , ("post-block", "Post Blocks")
            ] :: [(Text, Text)]
        baseParams =
            [ ("q", if T.null q then Nothing else Just q)
            , ("user", if T.null userQuery then Nothing else Just userQuery)
            , ("type", if T.null typeQuery then Nothing else Just typeQuery)
            , ("per_page", Just (T.pack (show perPage)))
            ]
        queryBase =
            TextEncoding.decodeUtf8
                $ LBS.toStrict
                $ toLazyByteString
                $ renderQueryText True baseParams
        pagePrefix =
            if T.null queryBase
                then "?page="
                else queryBase <> "&page="

    defaultLayout $ do
        setTitle $ preEscapedText "Admin - Moderation Logs"
        let adminBody = $(widgetFile "admin/moderation/logs")
            activeKey = ("moderation-logs" :: Text)
            menuClass key =
                if key == activeKey
                    then ("bg-slate-900 text-white" :: Text)
                    else ("text-slate-600 hover:bg-slate-50 hover:text-slate-900" :: Text)
        $(widgetFile "layout/admin-layout")

postAdminModerationActionR :: Handler Html
postAdminModerationActionR = do
    action <- runInputPost $ ireq textField "action"
    actor <- requireAuthId
    now <- liftIO getCurrentTime
    case action of
        "post-flag-delete" -> do
            flagId <- runInputPost $ ireq hiddenField "id"
            mFlag <- runDB $ get flagId
            runDB $ delete flagId
            let targetId = maybe "unknown" (T.pack . show . fromSqlKey . postFlagPost) mFlag
            runDB $ insert_ $ ModerationLog actor "post-flag" targetId "delete" now
            setMessage "Post flag removed."
        "post-block-delete" -> do
            blockId <- runInputPost $ ireq hiddenField "id"
            mBlock <- runDB $ get blockId
            runDB $ delete blockId
            let targetId = maybe "unknown" (T.pack . show . fromSqlKey . postBlockPost) mBlock
            runDB $ insert_ $ ModerationLog actor "post-block" targetId "delete" now
            setMessage "Post block removed."
        _ -> setMessage "Unknown action."
    redirect AdminModerationR

buildPreview :: Int -> Text -> Text
buildPreview n raw =
    let plain = stripTags raw
        trimmed = T.take n plain
    in if T.length plain > n then trimmed <> "…" else trimmed

stripTags :: Text -> Text
stripTags = T.pack . go False . T.unpack
  where
    go _ [] = []
    go True ('>':xs) = go False xs
    go True (_:xs) = go True xs
    go False ('<':xs) = go True xs
    go False (x:xs) = x : go False xs
