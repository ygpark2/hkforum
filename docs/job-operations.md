# Job Operations

## Application Lifecycle

- `submitted`: 지원자가 공고에 지원한 기본 상태입니다.
- `reviewing`: 공고 작성자 또는 admin이 검토 중으로 표시한 상태입니다.
- `accepted`: 채용 또는 다음 단계 진행 대상으로 표시한 상태입니다.
- `rejected`: 거절된 상태입니다.
- `withdrawn`: 운영자가 기록을 보존하면서 철회로 표시할 때 사용하는 상태입니다.

지원자가 직접 철회하면 현재 정책상 `JobApplication` 행을 삭제합니다. 이 정책은 중복 재지원을 단순하게 허용하고, 지원자가 철회한 지원 내역을 본인 목록에서 즉시 제거하기 위한 선택입니다.

## Delete Policy

공고 삭제 시 다음 데이터를 함께 삭제합니다.

- `job_skill`
- `job_benefit`
- `job_application`

공고와 연결된 Notification은 `job` 참조를 갖습니다. 공고 삭제 시 해당 job 알림도 함께 삭제합니다.

## Indexes

앱 시작 마이그레이션 후 주요 조회 경로에 필요한 인덱스를 보장합니다.

- job 목록/필터: `created_at`, `deadline`, `company_ref`, `employment_type`, `workplace_type`, `seniority`
- skill 검색: `job_skill.name`
- 지원자 관리: `job_application(job, status)`, `applicant`, `created_at`
- 회사 선택/검색: `company.name`

## Employer Plans

기업 회원은 회원가입 시 플랜을 선택합니다. 결제 연동 전까지는 선택한 플랜 권한을 즉시 부여합니다.

- `starter`: 월 100,000원, 월 구인 공고 3개
- `growth`: 월 300,000원, 월 구인 공고 10개
- `scale`: 월 500,000원, 월 구인 공고 20개
- `enterprise`: 20개 초과, 협의

일반 회원은 구인 공고를 등록할 수 없습니다. `admin`은 모든 기업 대시보드 기능에 접근하며 공고 등록 한도도 적용받지 않습니다.
