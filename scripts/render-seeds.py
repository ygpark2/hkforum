#!/usr/bin/env python3

import csv
import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SEED_DIR = PROJECT_ROOT / "config" / "seeds"

ADMIN_IDENT = "admin"
ADMIN_ROLE = "admin"
ADMIN_PASSWORD_HASH = "sha256|17|3vQDpPUUjAN7Kit3yuC5zA==|uSAJYwhEYpoosaSrf2VnNOEjFNpaFeX5I0wnoyeMVGw="

COMPANY_SEEDS = [
    {
        "name": "Han River AI",
        "category_code": "62",
        "website": "https://hanriver-ai.example.com",
        "size": "51-200명",
        "country_code": "KOR",
        "state": "11",
        "latitude": 37.5665,
        "longitude": 126.9780,
        "description": "<p>지역 커뮤니티와 운영 자동화를 위한 AI SaaS를 개발합니다.</p><p>검색, 추천, 운영 도구를 한 제품으로 제공합니다.</p>",
    },
    {
        "name": "Busan Bio Labs",
        "category_code": "21",
        "website": "https://busanbio.example.com",
        "size": "201-500명",
        "country_code": "KOR",
        "state": "26",
        "latitude": 35.1796,
        "longitude": 129.0756,
        "description": "<p>해양 바이오 기반 원료와 디지털 진단 솔루션을 연구합니다.</p><p>생산과 임상 협업 조직을 함께 운영합니다.</p>",
    },
    {
        "name": "Daegu Mobility Works",
        "category_code": "30",
        "website": "https://daegumobility.example.com",
        "size": "501-1000명",
        "country_code": "KOR",
        "state": "27",
        "latitude": 35.8714,
        "longitude": 128.6014,
        "description": "<p>전기차 부품과 경량화 모듈을 제조하는 모빌리티 기업입니다.</p><p>스마트 팩토리 전환 프로젝트를 진행 중입니다.</p>",
    },
    {
        "name": "Incheon Port Logistics",
        "category_code": "49",
        "website": "https://incheonportlogistics.example.com",
        "size": "201-500명",
        "country_code": "KOR",
        "state": "28",
        "latitude": 37.4563,
        "longitude": 126.7052,
        "description": "<p>항만 물류와 크로스보더 풀필먼트를 운영합니다.</p><p>운송 데이터 표준화와 현장 자동화에 투자하고 있습니다.</p>",
    },
    {
        "name": "Gwangju Edu Cloud",
        "category_code": "80",
        "website": "https://gwangjueducloud.example.com",
        "size": "51-200명",
        "country_code": "KOR",
        "state": "29",
        "latitude": 35.1595,
        "longitude": 126.8526,
        "description": "<p>학교와 공공 교육기관을 위한 학습 관리 플랫폼을 만듭니다.</p><p>콘텐츠 배포와 평가 분석 기능이 핵심입니다.</p>",
    },
    {
        "name": "Daejeon Quantum Net",
        "category_code": "61",
        "website": "https://daejeonquantum.example.com",
        "size": "11-50명",
        "country_code": "KOR",
        "state": "30",
        "latitude": 36.3504,
        "longitude": 127.3845,
        "description": "<p>차세대 통신 장비와 연구망 소프트웨어를 개발합니다.</p><p>대전 연구 단지와 협업하는 R&D 중심 조직입니다.</p>",
    },
    {
        "name": "Ulsan Green Grid",
        "category_code": "35",
        "website": "https://ulsangreengrid.example.com",
        "size": "201-500명",
        "country_code": "KOR",
        "state": "31",
        "latitude": 35.5384,
        "longitude": 129.3114,
        "description": "<p>산업 단지 대상 에너지 관리 시스템과 분산 전원 관제를 제공합니다.</p><p>탄소 절감 리포팅 자동화가 주력 서비스입니다.</p>",
    },
    {
        "name": "Sejong Civic Data",
        "category_code": "70",
        "website": "https://sejongcivicdata.example.com",
        "size": "11-50명",
        "country_code": "KOR",
        "state": "36",
        "latitude": 36.4800,
        "longitude": 127.2890,
        "description": "<p>공공 데이터 분석과 서비스 기획을 수행하는 전문 조직입니다.</p><p>정책 실험과 데이터 시각화 프로젝트를 지원합니다.</p>",
    },
    {
        "name": "Pangyo Commerce Flow",
        "category_code": "46",
        "website": "https://pangyocommerceflow.example.com",
        "size": "51-200명",
        "country_code": "KOR",
        "state": "41",
        "latitude": 37.3947,
        "longitude": 127.1112,
        "description": "<p>B2B 유통 운영을 위한 주문, 정산, 재고 플랫폼을 제공합니다.</p><p>빠른 도입과 운영 효율 개선이 강점입니다.</p>",
    },
    {
        "name": "Jeju Health Connect",
        "category_code": "85",
        "website": "https://jejuhealthconnect.example.com",
        "size": "51-200명",
        "country_code": "KOR",
        "state": "50",
        "latitude": 33.4996,
        "longitude": 126.5312,
        "description": "<p>지역 병원과 케어 기관을 연결하는 디지털 헬스 서비스 기업입니다.</p><p>예약, 상담, 사후 관리 기능을 통합 제공합니다.</p>",
    },
]

JOB_SEEDS = [
    {
        "title": "Backend Engineer",
        "company": "Han River AI",
        "salary": "연봉 6,500만-8,500만원",
        "salary_min": 65000000,
        "salary_max": 85000000,
        "salary_currency": "KRW",
        "salary_period": "annual",
        "working_hours": "주 5일 · 선택 출근제",
        "deadline": "2026-06-15",
        "experience": "3년 이상",
        "seniority": "mid",
        "employment_type": "full_time",
        "workplace_type": "hybrid",
        "apply_url": "https://hanriver-ai.example.com/careers/backend-engineer",
        "apply_email": "jobs@hanriver-ai.example.com",
        "skills": ["haskell", "postgresql", "api", "aws"],
        "benefits": ["선택 출근제", "교육비 지원", "스톡옵션"],
        "country_code": "KOR",
        "state": "11",
        "latitude": 37.5665,
        "longitude": 126.9780,
        "content": "Haskell 또는 typed backend 경험이 있는 엔지니어를 찾습니다. 추천/검색 API, 운영 도구, 데이터 파이프라인 협업이 주요 업무입니다.",
    },
    {
        "title": "ML Platform Engineer",
        "company": "Han River AI",
        "salary": "연봉 7,000만-9,000만원",
        "salary_min": 70000000,
        "salary_max": 90000000,
        "salary_currency": "KRW",
        "salary_period": "annual",
        "working_hours": "주 5일 · 원격 일부 가능",
        "deadline": "2026-06-30",
        "experience": "4년 이상",
        "seniority": "senior",
        "employment_type": "full_time",
        "workplace_type": "remote",
        "apply_url": "https://hanriver-ai.example.com/careers/ml-platform-engineer",
        "apply_email": "ml-jobs@hanriver-ai.example.com",
        "skills": ["python", "kubernetes", "mlops", "terraform"],
        "benefits": ["원격 근무", "컨퍼런스 지원", "장비 지원"],
        "country_code": "KOR",
        "state": "11",
        "latitude": 37.5665,
        "longitude": 126.9780,
        "content": "모델 서빙, 피처 파이프라인, 평가 자동화를 담당합니다. 데이터 엔지니어와 협업해 운영 가능한 ML 플랫폼을 구축합니다.",
    },
    {
        "title": "Quality Specialist",
        "company": "Busan Bio Labs",
        "salary": "연봉 4,200만-5,500만원",
        "salary_min": 42000000,
        "salary_max": 55000000,
        "salary_currency": "KRW",
        "salary_period": "annual",
        "working_hours": "주 5일",
        "deadline": "2026-06-10",
        "experience": "2년 이상",
        "seniority": "mid",
        "employment_type": "full_time",
        "workplace_type": "on_site",
        "apply_url": "https://busanbio.example.com/careers/quality-specialist",
        "apply_email": "qa@busanbio.example.com",
        "skills": ["gmp", "qa", "documentation", "audit"],
        "benefits": ["식대 지원", "건강검진", "자격증 지원"],
        "country_code": "KOR",
        "state": "26",
        "latitude": 35.1796,
        "longitude": 129.0756,
        "content": "원료 생산 공정의 품질 문서 관리와 감사 대응을 담당합니다. 바이오/제약 품질 체계 경험자를 우대합니다.",
    },
    {
        "title": "Production Planner",
        "company": "Daegu Mobility Works",
        "salary": "연봉 4,800만-6,000만원",
        "salary_min": 48000000,
        "salary_max": 60000000,
        "salary_currency": "KRW",
        "salary_period": "annual",
        "working_hours": "주 5일 · 탄력 근무",
        "deadline": "2026-06-20",
        "experience": "3년 이상",
        "seniority": "mid",
        "employment_type": "full_time",
        "workplace_type": "on_site",
        "apply_url": "https://daegumobility.example.com/careers/production-planner",
        "apply_email": "people@daegumobility.example.com",
        "skills": ["mes", "excel", "supply-chain", "planning"],
        "benefits": ["탄력 근무", "통근 지원", "성과급"],
        "country_code": "KOR",
        "state": "27",
        "latitude": 35.8714,
        "longitude": 128.6014,
        "content": "전기차 부품 생산 계획 수립과 협력사 일정 조율 업무입니다. MES 데이터 기반으로 납기와 재고를 관리합니다.",
    },
    {
        "title": "Operations Analyst",
        "company": "Incheon Port Logistics",
        "salary": "연봉 4,500만-6,500만원",
        "salary_min": 45000000,
        "salary_max": 65000000,
        "salary_currency": "KRW",
        "salary_period": "annual",
        "working_hours": "주 5일",
        "deadline": "2026-06-25",
        "experience": "2년 이상",
        "seniority": "mid",
        "employment_type": "full_time",
        "workplace_type": "on_site",
        "apply_url": "https://incheonportlogistics.example.com/jobs/operations-analyst",
        "apply_email": "ops-hiring@incheonportlogistics.example.com",
        "skills": ["sql", "dashboard", "logistics", "analytics"],
        "benefits": ["교통비 지원", "직무 교육", "성과급"],
        "country_code": "KOR",
        "state": "28",
        "latitude": 37.4563,
        "longitude": 126.7052,
        "content": "항만 물동량과 배송 리드타임 데이터를 분석해 운영 지표를 개선합니다. SQL과 대시보드 도구 사용 경험이 필요합니다.",
    },
    {
        "title": "Education Content Manager",
        "company": "Gwangju Edu Cloud",
        "salary": "연봉 3,800만-5,200만원",
        "salary_min": 38000000,
        "salary_max": 52000000,
        "salary_currency": "KRW",
        "salary_period": "annual",
        "working_hours": "주 5일",
        "deadline": "2026-05-31",
        "experience": "1년 이상",
        "seniority": "junior",
        "employment_type": "contract",
        "workplace_type": "hybrid",
        "apply_url": "https://gwangjueducloud.example.com/careers/content-manager",
        "apply_email": "content@gwangjueducloud.example.com",
        "skills": ["content", "education", "project-management"],
        "benefits": ["하이브리드 근무", "도서비 지원", "계약 연장 검토"],
        "country_code": "KOR",
        "state": "29",
        "latitude": 35.1595,
        "longitude": 126.8526,
        "content": "학교 대상 디지털 콘텐츠 편성과 운영 일정을 관리합니다. 교사와 기관 커뮤니케이션 경험이 있으면 좋습니다.",
    },
    {
        "title": "Network Software Engineer",
        "company": "Daejeon Quantum Net",
        "salary": "연봉 6,000만-8,000만원",
        "salary_min": 60000000,
        "salary_max": 80000000,
        "salary_currency": "KRW",
        "salary_period": "annual",
        "working_hours": "주 5일 · 연구 일정 연동",
        "deadline": "2026-07-10",
        "experience": "3년 이상",
        "seniority": "senior",
        "employment_type": "full_time",
        "workplace_type": "on_site",
        "apply_url": "https://daejeonquantum.example.com/careers/network-software-engineer",
        "apply_email": "research-jobs@daejeonquantum.example.com",
        "skills": ["networking", "linux", "c", "distributed-systems"],
        "benefits": ["연구 장비 지원", "논문/특허 보상", "유연 근무"],
        "country_code": "KOR",
        "state": "30",
        "latitude": 36.3504,
        "longitude": 127.3845,
        "content": "망 제어 소프트웨어와 장비 인터페이스 개발 업무입니다. 네트워크 프로토콜과 시스템 프로그래밍 경험자를 찾습니다.",
    },
    {
        "title": "Energy Data Analyst",
        "company": "Ulsan Green Grid",
        "salary": "연봉 5,000만-6,800만원",
        "salary_min": 50000000,
        "salary_max": 68000000,
        "salary_currency": "KRW",
        "salary_period": "annual",
        "working_hours": "주 5일",
        "deadline": "2026-06-18",
        "experience": "2년 이상",
        "seniority": "mid",
        "employment_type": "full_time",
        "workplace_type": "hybrid",
        "apply_url": "https://ulsangreengrid.example.com/careers/energy-data-analyst",
        "apply_email": "data@ulsangreengrid.example.com",
        "skills": ["python", "timeseries", "sql", "reporting"],
        "benefits": ["하이브리드 근무", "직무 교육", "건강검진"],
        "country_code": "KOR",
        "state": "31",
        "latitude": 35.5384,
        "longitude": 129.3114,
        "content": "산업 현장 에너지 사용량을 분석하고 고객 리포트를 자동화합니다. 시계열 데이터 처리와 보고서 작성 능력이 중요합니다.",
    },
    {
        "title": "Public Service Consultant",
        "company": "Sejong Civic Data",
        "salary": "연봉 4,600만-6,200만원",
        "salary_min": 46000000,
        "salary_max": 62000000,
        "salary_currency": "KRW",
        "salary_period": "annual",
        "working_hours": "주 5일",
        "deadline": "2026-07-05",
        "experience": "3년 이상",
        "seniority": "mid",
        "employment_type": "full_time",
        "workplace_type": "hybrid",
        "apply_url": "https://sejongcivicdata.example.com/jobs/public-service-consultant",
        "apply_email": "consulting@sejongcivicdata.example.com",
        "skills": ["consulting", "data-analysis", "policy", "presentation"],
        "benefits": ["하이브리드 근무", "프로젝트 인센티브", "교육비 지원"],
        "country_code": "KOR",
        "state": "36",
        "latitude": 36.4800,
        "longitude": 127.2890,
        "content": "공공기관 데이터 활용 과제 기획과 실무 운영을 맡습니다. 정책 문서 작성과 데이터 기반 제안 경험이 필요합니다.",
    },
    {
        "title": "Sales Operations Manager",
        "company": "Pangyo Commerce Flow",
        "salary": "연봉 5,500만-7,200만원",
        "salary_min": 55000000,
        "salary_max": 72000000,
        "salary_currency": "KRW",
        "salary_period": "annual",
        "working_hours": "주 5일 · 유연 근무",
        "deadline": "2026-06-22",
        "experience": "4년 이상",
        "seniority": "senior",
        "employment_type": "full_time",
        "workplace_type": "hybrid",
        "apply_url": "https://pangyocommerceflow.example.com/careers/sales-operations-manager",
        "apply_email": "sales-ops@pangyocommerceflow.example.com",
        "skills": ["sales-ops", "crm", "revenue-operations", "sql"],
        "benefits": ["유연 근무", "스톡옵션", "성과급"],
        "country_code": "KOR",
        "state": "41",
        "latitude": 37.3947,
        "longitude": 127.1112,
        "content": "B2B 고객 온보딩과 매출 운영 프로세스를 설계합니다. 영업, 정산, CS 조직을 연결해 운영 지표를 안정화합니다.",
    },
]


def normalize_suffixes(raw_value: str) -> list[str]:
    raw_suffixes = [part.strip().lower() for part in raw_value.split(",")]
    normalized = []
    for suffix in raw_suffixes:
        if suffix and suffix not in normalized:
            normalized.append(suffix)
    return normalized or ["ko"]


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def load_country_rows(suffixes: list[str]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for suffix in suffixes:
        rows.extend(read_csv_rows(SEED_DIR / f"countries_{suffix}.csv"))
    return rows


def load_country_state_rows(suffixes: list[str]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for suffix in suffixes:
        rows.extend(read_csv_rows(SEED_DIR / f"country_states_{suffix}.csv"))
    return rows


def load_company_group_rows() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for row in read_csv_rows(SEED_DIR / "company_categories.csv"):
        major_sort = int(row["major_sort"])
        minor_sort = int(row["minor_sort"])
        rows.append(
            {
                "code": row["minor_code"],
                "name": row["minor_name"],
                "major_code": row["major_code"],
                "major_name": row["major_name"],
                "sort_order": major_sort * 100 + minor_sort,
            }
        )
    return rows


class SqlDialect:
    def __init__(self, backend: str):
        self.backend = backend
        self.user_table = '"user"' if backend in {"sqlite", "postgres"} else "`user`"
        self.true_literal = "TRUE"
        self.false_literal = "FALSE"
        self.begin = "BEGIN;" if backend in {"sqlite", "postgres"} else "START TRANSACTION;"
        self.commit = "COMMIT;"

    @staticmethod
    def quote(value: str) -> str:
        return "'" + value.replace("'", "''") + "'"

    def nullable(self, value):
        if value is None:
            return "NULL"
        if isinstance(value, bool):
            return self.true_literal if value else self.false_literal
        if isinstance(value, (int, float)):
            return str(value)
        return self.quote(str(value))


def admin_insert_sql(dialect: SqlDialect) -> str:
    return f"""
INSERT INTO {dialect.user_table} (ident, password, role, name, description, country_code, state, local_region_only, latitude, longitude, theme)
SELECT {dialect.quote(ADMIN_IDENT)}, {dialect.quote(ADMIN_PASSWORD_HASH)}, {dialect.quote(ADMIN_ROLE)}, NULL, NULL, NULL, NULL, {dialect.false_literal}, NULL, NULL, NULL
WHERE NOT EXISTS (
    SELECT 1 FROM {dialect.user_table} u WHERE u.ident = {dialect.quote(ADMIN_IDENT)}
);
""".strip()


def board_insert_sql(dialect: SqlDialect) -> str:
    return f"""
INSERT INTO board (name, description, post_count, comment_count)
SELECT {dialect.quote('general')}, {dialect.quote('General discussion')}, 0, 0
WHERE NOT EXISTS (
    SELECT 1 FROM board b WHERE b.name = {dialect.quote('general')}
);
""".strip()


def country_insert_sql(dialect: SqlDialect, row: dict[str, str]) -> str:
    return f"""
INSERT INTO country (code, name, local_name, sort_order)
SELECT {dialect.quote(row['country_code'])}, {dialect.quote(row['country_name'])}, {dialect.nullable(row['country_name_local'] or None)}, {int(row['sort_order'])}
WHERE NOT EXISTS (
    SELECT 1 FROM country c WHERE c.code = {dialect.quote(row['country_code'])}
);
""".strip()


def country_state_insert_sql(dialect: SqlDialect, row: dict[str, str]) -> str:
    return f"""
INSERT INTO country_state (country_code, code, name, local_name, state_type, sort_order)
SELECT {dialect.quote(row['country_code'])}, {dialect.quote(row['state_code'])}, {dialect.quote(row['state_name'])}, {dialect.nullable(row['state_name_local'] or None)}, {dialect.nullable(row['state_type'] or None)}, {int(row['sort_order'])}
WHERE NOT EXISTS (
    SELECT 1 FROM country_state s
    WHERE s.country_code = {dialect.quote(row['country_code'])}
      AND s.code = {dialect.quote(row['state_code'])}
);
""".strip()


def company_group_insert_sql(dialect: SqlDialect, row: dict[str, object]) -> str:
    return f"""
INSERT INTO company_group (name, description, author, created_at, code, major_code, sort_order, is_system)
SELECT {dialect.quote(str(row['name']))}, {dialect.quote(f"대분류: {row['major_name']}")}, u.id, CURRENT_TIMESTAMP, {dialect.quote(str(row['code']))}, {dialect.quote(str(row['major_code']))}, {int(row['sort_order'])}, {dialect.true_literal}
FROM {dialect.user_table} u
WHERE u.ident = {dialect.quote(ADMIN_IDENT)}
  AND NOT EXISTS (
      SELECT 1 FROM company_group cg WHERE cg.code = {dialect.quote(str(row['code']))}
  );
""".strip()


def company_insert_sql(dialect: SqlDialect, row: dict[str, object]) -> str:
    return f"""
INSERT INTO company (name, category, website, size, country_code, state, latitude, longitude, description, author, created_at, updated_at)
SELECT {dialect.quote(str(row['name']))}, cg.id, {dialect.nullable(row['website'])}, {dialect.nullable(row['size'])}, {dialect.nullable(row['country_code'])}, {dialect.nullable(row['state'])}, {dialect.nullable(row['latitude'])}, {dialect.nullable(row['longitude'])}, {dialect.quote(str(row['description']))}, u.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM company_group cg
JOIN {dialect.user_table} u ON u.ident = {dialect.quote(ADMIN_IDENT)}
WHERE cg.code = {dialect.quote(str(row['category_code']))}
  AND NOT EXISTS (
      SELECT 1 FROM company c
      WHERE c.name = {dialect.quote(str(row['name']))}
        AND c.author = u.id
  );
""".strip()


def job_insert_sql(dialect: SqlDialect, row: dict[str, object]) -> str:
    return f"""
INSERT INTO job (title, company, company_ref, salary, salary_min, salary_max, salary_currency, salary_period, working_hours, deadline, is_closed, closed_at, experience, seniority, employment_type, workplace_type, apply_url, apply_email, published_at, country_code, state, latitude, longitude, content, author, created_at, updated_at)
SELECT {dialect.quote(str(row['title']))}, {dialect.quote(str(row['company']))}, c.id, {dialect.nullable(row['salary'])}, {dialect.nullable(row['salary_min'])}, {dialect.nullable(row['salary_max'])}, {dialect.nullable(row['salary_currency'])}, {dialect.nullable(row['salary_period'])}, {dialect.nullable(row['working_hours'])}, {dialect.nullable(row['deadline'])}, {dialect.false_literal}, NULL, {dialect.nullable(row['experience'])}, {dialect.nullable(row['seniority'])}, {dialect.nullable(row['employment_type'])}, {dialect.nullable(row['workplace_type'])}, {dialect.nullable(row['apply_url'])}, {dialect.nullable(row['apply_email'])}, CURRENT_TIMESTAMP, {dialect.nullable(row['country_code'])}, {dialect.nullable(row['state'])}, {dialect.nullable(row['latitude'])}, {dialect.nullable(row['longitude'])}, {dialect.quote(str(row['content']))}, u.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM {dialect.user_table} u
JOIN company c ON c.name = {dialect.quote(str(row['company']))} AND c.author = u.id
WHERE u.ident = {dialect.quote(ADMIN_IDENT)}
  AND NOT EXISTS (
      SELECT 1 FROM job j
      WHERE j.title = {dialect.quote(str(row['title']))}
        AND j.company = {dialect.quote(str(row['company']))}
        AND j.author = u.id
  );
""".strip()


def job_skill_insert_sql(dialect: SqlDialect, row: dict[str, object], name: str, sort_order: int) -> str:
    return f"""
INSERT INTO job_skill (job, name, sort_order)
SELECT j.id, {dialect.quote(name)}, {sort_order}
FROM job j
JOIN {dialect.user_table} u ON u.id = j.author
WHERE u.ident = {dialect.quote(ADMIN_IDENT)}
  AND j.title = {dialect.quote(str(row['title']))}
  AND j.company = {dialect.quote(str(row['company']))}
  AND NOT EXISTS (
      SELECT 1 FROM job_skill js
      WHERE js.job = j.id
        AND js.name = {dialect.quote(name)}
  );
""".strip()


def job_benefit_insert_sql(dialect: SqlDialect, row: dict[str, object], name: str, sort_order: int) -> str:
    return f"""
INSERT INTO job_benefit (job, name, sort_order)
SELECT j.id, {dialect.quote(name)}, {sort_order}
FROM job j
JOIN {dialect.user_table} u ON u.id = j.author
WHERE u.ident = {dialect.quote(ADMIN_IDENT)}
  AND j.title = {dialect.quote(str(row['title']))}
  AND j.company = {dialect.quote(str(row['company']))}
  AND NOT EXISTS (
      SELECT 1 FROM job_benefit jb
      WHERE jb.job = j.id
        AND jb.name = {dialect.quote(name)}
  );
""".strip()


def render_sql(backend: str, suffixes: list[str]) -> str:
    dialect = SqlDialect(backend)
    statements = [
        dialect.begin,
        "-- Generated by scripts/render-seeds.py",
        f"-- LOCATION_REGION_SEED_SUFFIXES={','.join(suffixes)}",
        "-- Run this after schema migrations complete.",
        admin_insert_sql(dialect),
        board_insert_sql(dialect),
    ]
    for row in load_country_rows(suffixes):
        statements.append(country_insert_sql(dialect, row))
    for row in load_country_state_rows(suffixes):
        statements.append(country_state_insert_sql(dialect, row))
    for row in load_company_group_rows():
        statements.append(company_group_insert_sql(dialect, row))
    for row in COMPANY_SEEDS:
        statements.append(company_insert_sql(dialect, row))
    for row in JOB_SEEDS:
        statements.append(job_insert_sql(dialect, row))
        for index, skill in enumerate(row["skills"]):
            statements.append(job_skill_insert_sql(dialect, row, str(skill), index))
        for index, benefit in enumerate(row["benefits"]):
            statements.append(job_benefit_insert_sql(dialect, row, str(benefit), index))
    statements.append(dialect.commit)
    return "\n\n".join(statements) + "\n"


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"sqlite", "postgres", "mariadb"}:
        print("Usage: scripts/render-seeds.py [sqlite|postgres|mariadb]", file=sys.stderr)
        return 1
    backend = sys.argv[1]
    suffixes = normalize_suffixes(os.environ.get("LOCATION_REGION_SEED_SUFFIXES", "ko"))
    sys.stdout.write(render_sql(backend, suffixes))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
