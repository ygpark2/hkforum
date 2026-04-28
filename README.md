# HKForum

Yesod 기반 포럼 애플리케이션입니다.

## Quick Start

```bash
stack build
make start
```

새 DB를 초기화할 때는 앱을 한 번 실행해서 마이그레이션을 적용한 뒤 시드를 넣습니다.

```bash
make seed-data
```

기본 시드에는 다음이 포함됩니다.

- 관리자 계정 `admin / admin`
- `general` 보드
- 국가/지역 데이터
- 시스템 회사 카테고리
- company 10개
- job 10개: 고용형태, 근무방식, 연봉 범위, 스킬, 복지, 지원 링크 포함

## Feature Areas

- Jobs: 기업 회원/관리자가 구인 공고를 등록하고 지원자를 관리합니다.
- Real Estate: 호주/유럽 기준 임대, 매매, 쉐어, 단기 숙소 매물을 등록하고 문의를 관리합니다.

## Seed Commands

직접 DB에 적재:

```bash
make seed-data
make seed-data SEED_DB=postgres POSTGRES_CONNSTR='postgresql://localhost/hkforum'
make seed-data SEED_DB=mariadb MARIADB_DATABASE=hkforum MARIADB_USER=root
```

DB 관리 툴에서 실행할 SQL 생성:

```bash
make render-seed-sql SEED_DB=sqlite SEED_SQL_OUT=/tmp/hkforum-seeds.sqlite.sql
make render-seed-sql SEED_DB=postgres SEED_SQL_OUT=/tmp/hkforum-seeds.postgres.sql
make render-seed-sql SEED_DB=mariadb SEED_SQL_OUT=/tmp/hkforum-seeds.mariadb.sql
```

지역 시드 범위 변경:

```bash
LOCATION_REGION_SEED_SUFFIXES=ko,eu make seed-data
LOCATION_REGION_SEED_SUFFIXES=ko,anz make render-seed-sql SEED_DB=postgres SEED_SQL_OUT=/tmp/hkforum-seeds.sql
```

자세한 내용은 [docs/seeds.md](/Users/ygpark2/pjt/projects/hkforum/docs/seeds.md:1)를 보면 됩니다.

Job 운영 정책과 인덱스는 [docs/job-operations.md](/Users/ygpark2/pjt/projects/hkforum/docs/job-operations.md:1)를 보면 됩니다.

부동산 메뉴와 DB 설계는 [docs/real-estate.md](/Users/ygpark2/pjt/projects/hkforum/docs/real-estate.md:1)를 보면 됩니다.
