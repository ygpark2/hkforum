{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE TemplateHaskell, ViewPatterns, RecordWildCards #-}
module Application
    ( getApplicationDev
    , appMain
    , develMain
    , makeFoundation
    -- * for DevelMain
    , getApplicationRepl
    , shutdownApp
    -- * for GHCI
    , handler
    , db
    ) where

import Control.Monad.Logger                 (LoggingT, liftLoc, runLoggingT)
import Database.Persist.Sqlite              (createSqlitePool, runSqlPool,
                                             sqlDatabase, sqlPoolSize)
import Import hiding ((.), (++))
import qualified Prelude as P
import Yesod.Auth.HashDB                    (setPassword)
import Language.Haskell.TH.Syntax           (qLocation)
import Network.Wai.Handler.Warp             (Settings, defaultSettings,
                                             defaultShouldDisplayException,
                                             runSettings, setHost,
                                             setOnException, setPort, getPort)
import Network.Wai.Middleware.RequestLogger (Destination (Logger),
                                             IPAddrSource (..),
                                             OutputFormat (..), destination,
                                             mkRequestLogger, outputFormat)
import qualified Data.Text as T
import System.Directory                    (createDirectoryIfMissing, doesFileExist,
                                             makeAbsolute)
import System.Environment                  (setEnv)
import System.FilePath                     (takeDirectory)
import System.Log.FastLogger                (defaultBufSize, newStdoutLoggerSet,
                                             toLogStr)

-- Import all relevant handler modules here.
-- Don't forget to add new modules to your cabal file!
import Handler.Common
import Handler.Forum.Boards
import Handler.Forum.Companies
import Handler.Forum.Home
import Handler.Forum.Jobs
import Handler.Forum.Chats
import Handler.Forum.Notifications
import Handler.Forum.Bookmarks
import Handler.Forum.Settings
import Handler.Forum.User
import Handler.Forum.Board
import Handler.Forum.Comment
import Handler.Forum.Post
import Handler.Upload
import Handler.Register
import Handler.Admin
import Handler.Profile
import Storage (mkStorage, storageBackendType)

-- This line actually creates our YesodDispatch instance. It is the second half
-- of the call to mkYesodData which occurs in Foundation.hs. Please see the
-- comments there for more details.
mkYesodDispatch "App" resourcesApp

-- | This function allocates resources (such as a database connection pool),
-- performs initialization and returns a foundation datatype value. This is also
-- the place to put your migrate statements to have automatic database
-- migrations handled by Yesod.
makeFoundation :: AppSettings -> IO App
makeFoundation appSettings = do
    -- Some basic initializations: HTTP connection manager, logger, and static
    -- subsite.
    appHttpManager <- newManager
    appLogger <- newStdoutLoggerSet defaultBufSize >>= makeYesodLogger
    appStatic <-
        (if appMutableStatic appSettings then staticDevel else static)
        (appStaticDir appSettings)
    appStorage <- mkStorage appSettings
    let appStorageBackendType = storageBackendType appStorage

    -- We need a log function to create a connection pool. We need a connection
    -- pool to create our foundation. And we need our foundation to get a
    -- logging function. To get out of this loop, we initially create a
    -- temporary foundation without a real connection pool, get a log function
    -- from there, and then create the real foundation.
    let mkFoundation appConnPool = App {..}
        -- The App {..} syntax is an example of record wild cards. For more
        -- information, see:
        -- https://ocharles.org.uk/blog/posts/2014-12-04-record-wildcards.html
        tempFoundation = mkFoundation $ error "connPool forced in tempFoundation"
        logFunc = messageLoggerSource tempFoundation appLogger

    let rawDbPath = unpack $ sqlDatabase $ appDatabaseConf appSettings
    absDbPath <- makeAbsolute rawDbPath
    let dbDir = takeDirectory absDbPath
        dbConf = (appDatabaseConf appSettings) { sqlDatabase = pack absDbPath }
    when (dbDir /= "." && dbDir /= "") $
        createDirectoryIfMissing True dbDir
    flip runLoggingT logFunc $
        $(logInfo) $ "Using SQLite database at: " <> pack absDbPath

    -- Create the database connection pool
    pool <- flip runLoggingT logFunc $ createSqlitePool
        (sqlDatabase dbConf)
        (sqlPoolSize dbConf)

    -- Perform database migration using our application's logging settings.
    runLoggingT (runSqlPool (runMigration migrateAll >> seedDefaults) pool) logFunc

    -- Return the foundation
    return $ mkFoundation pool

seedDefaults :: SqlPersistT (LoggingT IO) ()
seedDefaults = do
    void $ insertBy $ Board "general" (Just "General discussion") 0 0
    adminId <- seedAdmin
    seedCompanyGroups adminId

seedAdmin :: SqlPersistT (LoggingT IO) UserId
seedAdmin = do
    mUser <- getBy $ UniqueUser "ygpark2"
    case mUser of
        Just (Entity userId _) -> do
            update userId [UserRole =. "admin"]
            pure userId
        Nothing -> do
            user <- liftIO $ setPassword "1234" (User "ygpark2" Nothing "admin" Nothing Nothing)
            insert user

seedCompanyGroups :: UserId -> SqlPersistT (LoggingT IO) ()
seedCompanyGroups adminId = do
    now <- liftIO getCurrentTime
    forM_ companyGroupSeeds $ \(name, description) ->
        void $ insertBy $ CompanyGroup name (Just description) adminId now

companyGroupSeeds :: [(Text, Text)]
companyGroupSeeds =
    [ ("AI / Machine Learning", "생성형 AI, ML 플랫폼, 모델 서비스, AI 응용 제품 전반")
    , ("Software / SaaS", "일반 소프트웨어 제품, B2B SaaS, 업무용 웹서비스")
    , ("Enterprise Software", "ERP, 그룹웨어, 내부 운영 시스템, 기업용 플랫폼")
    , ("Developer Tools", "개발 생산성, CI/CD, API, 테스트, 플랫폼 엔지니어링")
    , ("Data / Analytics", "데이터 플랫폼, BI, ETL, 분석, MLOps, 관측성")
    , ("Cloud / Infrastructure", "클라우드, 호스팅, 서버, 스토리지, 플랫폼 인프라")
    , ("Cybersecurity", "보안 솔루션, 인증, 위협 탐지, 정보보호 서비스")
    , ("Semiconductor", "반도체 설계, 제조, 패키징, 장비, 소재")
    , ("Hardware / Devices", "전자기기, 디바이스, 컴퓨팅 하드웨어, 소비자 기기")
    , ("IoT / Edge Computing", "사물인터넷, 센서, 임베디드, 엣지 디바이스")
    , ("Robotics / Automation", "로봇, 공장 자동화, RPA, 물류 자동화")
    , ("Telecom / Networking", "통신사, 네트워크 장비, 연결 서비스, 5G/6G")
    , ("Mobility / Transportation", "모빌리티 플랫폼, 운송 서비스, 이동 관련 제품")
    , ("Automotive", "완성차, 차량 부품, 자동차 소프트웨어, 차량 서비스")
    , ("EV / Battery", "전기차, 배터리 셀/팩, 충전, 에너지 저장")
    , ("Autonomous Driving / Mapping", "자율주행, ADAS, 지도, 위치 인텔리전스")
    , ("Aerospace / Defense", "우주항공, 위성, 드론, 방산 기술과 제조")
    , ("Manufacturing / Industrial", "제조업, 산업 장비, 공정 시스템, 산업 기술")
    , ("Materials / Chemicals", "화학, 신소재, 산업 소재, 정밀소재")
    , ("Energy / Utilities", "전력, 가스, 유틸리티, 에너지 운영 서비스")
    , ("ClimateTech / CleanTech", "기후 기술, 탄소 관리, 친환경 기술, 재생에너지")
    , ("Construction / Smart City", "건설, 인프라, 도시 기술, 시설 관리")
    , ("Real Estate / PropTech", "부동산 개발, 임대, 부동산 플랫폼, 프롭테크")
    , ("Commerce / Retail", "유통, 리테일, 오프라인/온라인 판매 기업")
    , ("Marketplace / Platform", "중개형 플랫폼, 양면 시장, 거래 플랫폼")
    , ("Logistics / Supply Chain", "물류, 배송, 창고, 공급망 관리")
    , ("Food / Beverage", "식품 제조, 음료, 외식 브랜드, 푸드 관련 기업")
    , ("FoodTech / Delivery", "배달, 주방 운영, 식음료 기술, 주문 플랫폼")
    , ("Agriculture / AgriTech", "농업, 스마트팜, 농업 기술, 축산/수산 기술")
    , ("Healthcare / Medical", "의료기관, 병원, 헬스케어 서비스, 의료 운영")
    , ("Digital Health / HealthTech", "디지털 헬스, 원격진료, 건강관리 앱, 의료 IT")
    , ("Biotech / Pharma", "바이오, 제약, 신약 개발, 생명과학")
    , ("MedTech / Medical Devices", "의료기기, 진단 장비, 의료 하드웨어")
    , ("Beauty / Cosmetics", "뷰티 브랜드, 화장품, 미용 서비스")
    , ("Fashion / Apparel", "패션 브랜드, 의류, 액세서리, 럭셔리")
    , ("Media / Publishing", "미디어, 뉴스, 출판, 콘텐츠 제작/유통")
    , ("Entertainment / Creator Economy", "엔터테인먼트, 팬 플랫폼, 크리에이터 비즈니스")
    , ("Gaming", "게임 개발, 퍼블리싱, 게임 플랫폼, e스포츠")
    , ("Social / Community", "소셜 네트워크, 커뮤니티, 커뮤니케이션 서비스")
    , ("Productivity / Collaboration", "협업툴, 문서, 일정, 업무 생산성 도구")
    , ("Design / Creative Tools", "디자인, 영상, 음악, 3D, 창작 도구")
    , ("Marketing / AdTech", "광고, 마케팅 자동화, 브랜딩, 퍼포먼스 툴")
    , ("Sales / CRM / Customer Success", "영업, CRM, 고객관리, 상담 운영")
    , ("HR / Recruiting", "채용, 인사, 조직관리, 급여, 평가")
    , ("EdTech / Education", "교육 서비스, 학습 플랫폼, 학교/기업 교육")
    , ("FinTech", "핀테크, 결제, 송금, 자산관리, 금융 소프트웨어")
    , ("Banking / Securities / Asset Management", "은행, 증권, 카드, 보험 제외 금융기관과 투자사")
    , ("InsurTech / Insurance", "보험사, 인슈어테크, 보험 중개와 보험 플랫폼")
    , ("Legal / RegTech / Compliance", "법률 서비스, 규제 대응, 감사, 컴플라이언스")
    , ("Travel / Hospitality", "여행, 항공, 숙박, 관광, 예약 서비스")
    , ("Sports / Fitness / Wellness", "스포츠, 운동, 웰니스, 헬스장, 피트니스")
    , ("Pet / Animal Care", "반려동물 서비스, 펫푸드, 동물 헬스케어")
    , ("Family / Kids", "육아, 키즈 서비스, 가족 대상 제품과 플랫폼")
    , ("Senior / Silver Care", "시니어 케어, 고령층 서비스, 돌봄")
    , ("Nonprofit / Social Impact", "비영리, 사회적기업, 임팩트 조직")
    , ("Government / Public Sector", "공공기관, 공기업, GovTech, 행정 서비스")
    , ("Legal Services", "로펌, 법률 자문, 법률 운영 조직")
    , ("Consulting / Professional Services", "컨설팅, 회계, 전문 서비스, 아웃소싱")
    , ("Staffing / Outsourcing", "도급, BPO, 인력 파견, 운영 대행")
    , ("Holding Company / Conglomerate", "지주사, 복합 대기업, 다각화 그룹")
    , ("Consumer Goods", "생활용품, 일반 소비재, 브랜드 제조/유통")
    , ("Home / Living", "가구, 인테리어, 생활공간 제품과 서비스")
    , ("Security / Safety / Identity", "물리보안, 안전관리, 출입통제, 신원확인")
    , ("Blockchain / Web3", "블록체인, 가상자산, 지갑, 웹3 인프라와 서비스")
    , ("Research / Labs", "연구소, R&D 중심 조직, 기술 실험 조직")
    , ("Other / General", "위 분류에 정확히 들어가지 않거나 복합 성격이 강한 기업")
    ]


-- | Convert our foundation to a WAI Application by calling @toWaiAppPlain@ and
-- applying some additional middlewares.
makeApplication :: App -> IO Application
makeApplication foundation = do
    logWare <- mkRequestLogger def
        { outputFormat =
            if appDetailedRequestLogging $ appSettings foundation
                then Detailed True
                else Apache
                        (if appIpFromHeader $ appSettings foundation
                            then FromFallback
                            else FromSocket)
        , destination = Logger $ loggerSet $ appLogger foundation
        }

    -- Create the WAI application and apply middlewares
    appPlain <- toWaiAppPlain foundation
    return $ logWare $ defaultMiddlewaresNoLogging appPlain

-- | Warp settings for the given foundation value.
warpSettings :: App -> Settings
warpSettings foundation =
      setPort (appPort $ appSettings foundation)
    $ setHost (appHost $ appSettings foundation)
    $ setOnException (\_req e ->
        when (defaultShouldDisplayException e) $ messageLoggerSource
            foundation
            (appLogger foundation)
            $(qLocation >>= liftLoc)
            "yesod"
            LevelError
            (toLogStr $ "Exception from Warp: " P.++ show e))
      defaultSettings

-- | For yesod devel, return the Warp settings and WAI Application.
getApplicationDev :: IO (Settings, Application)
getApplicationDev = do
    settings <- getAppSettings
    foundation <- makeFoundation settings
    wsettings <- getDevSettings $ warpSettings foundation
    app <- makeApplication foundation
    return (wsettings, app)

getAppSettings :: IO AppSettings
getAppSettings = do
    loadDotenv
    loadYamlSettings [configSettingsYml] [] useEnv

-- | main function for use by yesod devel
develMain :: IO ()
develMain = develMainHelper getApplicationDev

-- | The @main@ function for an executable running this site.
appMain :: IO ()
appMain = do
    loadDotenv
    -- Get the settings from all relevant sources
    settings <- loadYamlSettingsArgs
        -- fall back to compile-time values, set to [] to require values at runtime
        [configSettingsYmlValue]

        -- allow environment variables to override
        useEnv

    -- Generate the foundation from the settings
    foundation <- makeFoundation settings

    -- Generate a WAI Application from the foundation
    app <- makeApplication foundation

    -- Run the application with Warp
    runSettings (warpSettings foundation) app

loadDotenv :: IO ()
loadDotenv = do
    exists <- doesFileExist ".env"
    when exists $ do
        contents <- readFile ".env"
        forM_ (T.lines $ decodeUtf8 contents) $ \rawLine -> do
            let line = T.strip rawLine
            when (not (T.null line) && T.head line /= '#') $ do
                let line' =
                        if "export " `T.isPrefixOf` line
                            then T.drop 7 line
                            else line
                    (key, rest) = T.breakOn "=" line'
                    value = T.drop 1 rest
                when (not (T.null key) && not (T.null rest)) $
                    setEnv (T.unpack key) (T.unpack $ stripQuotes $ T.strip value)
  where
    stripQuotes s =
        case T.uncons s of
            Just ('"', xs) | not (T.null xs) && T.last xs == '"' -> T.init xs
            Just ('\'', xs) | not (T.null xs) && T.last xs == '\'' -> T.init xs
            _ -> s


--------------------------------------------------------------
-- Functions for DevelMain.hs (a way to run the app from GHCi)
--------------------------------------------------------------
getApplicationRepl :: IO (Int, App, Application)
getApplicationRepl = do
    settings <- getAppSettings
    foundation <- makeFoundation settings
    wsettings <- getDevSettings $ warpSettings foundation
    app1 <- makeApplication foundation
    return (getPort wsettings, foundation, app1)

shutdownApp :: App -> IO ()
shutdownApp _ = return ()


---------------------------------------------
-- Functions for use in development with GHCi
---------------------------------------------

-- | Run a handler
handler :: Handler a -> IO a
handler h = getAppSettings >>= makeFoundation >>= flip unsafeHandler h

-- | Run DB queries
db :: ReaderT SqlBackend (HandlerFor App) a -> IO a
db = handler P.. runDB
