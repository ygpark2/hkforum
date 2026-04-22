{-# LANGUAGE OverloadedStrings #-}
module TestImport
    ( module TestImport
    , module X
    ) where

import Application           (makeFoundation)
import ClassyPrelude         as X hiding (delete, deleteBy, Handler)
import Database.Persist      as X hiding (get)
import Database.Persist.Sql  (SqlPersistM, SqlBackend, runSqlPersistMPool, rawExecute, rawSql, unSingle)
import Foundation            as X
import Model                 as X
import qualified Prelude as P
import Test.Hspec            as X
import Text.Shakespeare.Text (st)
import Yesod.Default.Config2 (ignoreEnv, loadAppSettings)
import Yesod.Test            as X

-- Wiping the database
import Database.Persist.Sqlite              (sqlDatabase, wrapConnection, createSqlPool)
import qualified Database.Sqlite as Sqlite
import Control.Monad.Logger                 (runLoggingT)
import Settings (AppDatabaseConf (..), appDatabaseConf)
import Yesod.Core (messageLoggerSource)

runDB :: SqlPersistM a -> YesodExample App a
runDB query = do
    pool <- fmap appConnPool getTestYesod
    liftIO $ runSqlPersistMPool query pool

withApp :: SpecWith App -> Spec
withApp = before $ do
    settings <- loadAppSettings
        ["config/test-settings.yml", "config/settings.yml"]
        []
        ignoreEnv
    foundation <- makeFoundation settings
    wipeDB foundation
    return foundation

-- This function will truncate all of the tables in your database.
-- 'withApp' calls it before each test, creating a clean environment for each
-- spec to run in.
wipeDB :: App -> IO ()
wipeDB app = do
    let settings = appSettings app   
    case appDatabaseConf settings of
        AppDatabaseSqlite sqliteConf -> do
            -- In order to wipe the database, we need to temporarily disable
            -- foreign key checks. Doing that inside a normal Persistent
            -- transaction is a noop in SQLite, so we use a raw connection.
            sqliteConn <- rawConnection (sqlDatabase sqliteConf)
            disableForeignKeys sqliteConn

            let logFunc = messageLoggerSource app (appLogger app)
            pool <- runLoggingT (createSqlPool (wrapConnection sqliteConn) 1) logFunc

            flip runSqlPersistMPool pool $ do
                tables <- getSqliteTables
                let quotedName t = "\"" <> t <> "\""
                    queries = P.map (\t -> "DELETE FROM " <> quotedName t) tables
                forM_ queries (\q -> rawExecute q [])
        AppDatabasePostgres _ ->
            flip runSqlPersistMPool (appConnPool app) $ do
                tables <- getPostgresTables
                unless (null tables) $
                    rawExecute
                        ("TRUNCATE TABLE " <> intercalate ", " (map (\t -> "\"" <> t <> "\"") tables) <> " RESTART IDENTITY CASCADE")
                        []

rawConnection :: Text -> IO Sqlite.Connection
rawConnection t = Sqlite.open t

disableForeignKeys :: Sqlite.Connection -> IO ()
disableForeignKeys conn = Sqlite.prepare conn "PRAGMA foreign_keys = OFF;" >>= (\stmt -> void (Sqlite.step stmt))

getSqliteTables :: MonadIO m => ReaderT SqlBackend m [Text]
getSqliteTables = do
    tables <- rawSql "SELECT name FROM sqlite_master WHERE type = 'table';" []
    return (fmap unSingle tables)

getPostgresTables :: MonadIO m => ReaderT SqlBackend m [Text]
getPostgresTables = do
    tables <- rawSql "SELECT tablename FROM pg_tables WHERE schemaname = 'public';" []
    return (fmap unSingle tables)
