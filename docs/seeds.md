# Seed Loading

앱 시작 시 기본 시드 데이터를 자동으로 넣지 않습니다.

새 DB 기준 순서:

1. 앱을 한 번 실행해서 마이그레이션만 적용합니다.
2. 시드 툴로 기본 데이터(`admin/admin`, `general` 보드, 국가/지역, 회사 카테고리, company 10개, job 10개)를 넣습니다.

job 시드에는 구조화된 고용형태, 근무방식, 경력 레벨, 연봉 범위, 스킬, 복지, 지원 URL/email이 포함됩니다.

직접 적재:

```bash
make seed-data
make seed-data SEED_DB=postgres POSTGRES_CONNSTR='postgresql://localhost/hkforum'
make seed-data SEED_DB=mariadb MARIADB_DATABASE=hkforum MARIADB_USER=root
```

DB 관리 툴에서 실행할 SQL 파일 생성:

```bash
make render-seed-sql SEED_DB=postgres SEED_SQL_OUT=/tmp/hkforum-seeds.postgres.sql
make render-seed-sql SEED_DB=sqlite SEED_SQL_OUT=/tmp/hkforum-seeds.sqlite.sql
```

`LOCATION_REGION_SEED_SUFFIXES`를 지정하면 국가/지역 시드 범위를 바꿀 수 있습니다.

```bash
LOCATION_REGION_SEED_SUFFIXES=ko,eu make seed-data
LOCATION_REGION_SEED_SUFFIXES=ko,anz make render-seed-sql SEED_DB=postgres SEED_SQL_OUT=/tmp/hkforum-seeds.sql
```
