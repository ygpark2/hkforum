# Real Estate

부동산 메뉴는 호주/유럽 지역 커뮤니티의 실사용을 우선해 `job`과 비슷한 게시/문의 흐름으로 구성합니다.

## MVP Scope

- `/real-estate` 메뉴에서 매물 목록, 필터, 등록, 수정, 삭제를 제공합니다.
- `/real-estate/:id` 상세 페이지에서 이미지, 지도, 상세 조건, 문의, 신고를 처리합니다.
- `/admin/real-estate` 관리자 페이지에서 승인/반려/재게시, 신고 처리, 중개업자 프로필 확인을 제공합니다.
- 부동산 중개업자 유료 회원과 `admin`만 매물을 등록할 수 있습니다.
- 매물 작성자와 `admin`은 매물 이미지를 업로드하고 삭제할 수 있습니다.
- 매물 작성자와 `admin`은 문의 목록을 보고 상태를 `new`, `replied`, `closed`로 변경할 수 있습니다.
- 비로그인 사용자도 문의를 남길 수 있습니다.
- 같은 이메일은 동일 매물에 1시간 3건까지만 문의할 수 있습니다.
- 비로그인/로그인 사용자는 매물 신고를 남길 수 있고, 관리자가 처리 상태를 변경합니다.
- 좌표가 있는 매물은 지도에 표시되며 `latitude`, `longitude`, `radiusKm` 쿼리로 반경 검색할 수 있습니다.
- 신규 매물은 `pending`으로 생성되고 `admin` 승인 후 `published`로 공개됩니다.
- 공개 매물은 기본 30일 후 `expired`로 자동 전환되며 재게시할 수 있습니다.

## Listing Fields

주요 테이블은 `real_estate_listing`입니다.

- 거래 유형: `rent`, `sale`, `share`, `short_term`
- 매물 유형: `apartment`, `house`, `townhouse`, `studio`, `room`, `land`, `commercial`
- 지역: `country_code`, `state`, `city`, `suburb`, `address_text`, 위경도
- 가격: `currency`, `price`, `price_period`, `bond_amount`, `deposit_amount`
- 상세 조건: 침실, 욕실, 주차, 면적, 입주 가능일, 계약 기간, 반려동물, 가구, 공과금 포함 여부
- 연락처: 이름, 이메일, 전화번호, 중개업자 프로필

부가 테이블은 `real_estate_feature`, `real_estate_image`, `real_estate_inquiry`, `real_estate_report`, `real_estate_agent_profile`입니다.

## Images

이미지는 기존 `/api/v1/uploads` 파일 업로드 API로 스토리지에 저장한 뒤 `real_estate_image`에 연결합니다.

- 업로드 응답은 `key`, `url`을 반환합니다.
- 연결 API는 `POST /api/v1/real-estate/:listingId/images`입니다.
- 캡션/정렬 수정 API는 `PATCH /api/v1/real-estate/:listingId/images/:imageId`입니다.
- 삭제 API는 `DELETE /api/v1/real-estate/:listingId/images/:imageId`입니다.
- 실제 파일 삭제는 아직 수행하지 않고 DB 연결만 제거합니다. S3/로컬 스토리지 정리 정책은 별도 배치나 관리자 도구로 분리하는 것이 안전합니다.

## Agent Profiles

부동산 회원은 별도 중개업자 프로필을 관리합니다.

- 조회: `GET /api/v1/real-estate-agent-profile`
- 저장: `PUT /api/v1/real-estate-agent-profile`
- 입력 필드: `agencyName`, `licenseNumber`, `website`, `phone`, `email`
- `verified`는 관리자 검증용 필드이며 API 저장 시 사용자가 직접 변경하지 않습니다.

## Paid Plans

부동산 매물 등록 권한은 `User.accountType = real_estate` 또는 `User.realEstatePlan`이 있는 사용자에게 부여합니다. `admin`은 한도 없이 등록할 수 있습니다.

- `starter`: 월 100,000원, 월 매물 10개
- `growth`: 월 300,000원, 월 매물 30개
- `scale`: 월 500,000원, 월 매물 70개
- `enterprise`: 70개 초과, 협의

대시보드 API는 `GET /api/v1/real-estate-dashboard`입니다. 현재 플랜, 이번 달 사용량, 등록 매물 목록, 플랜 목록을 반환합니다. 관리자는 여기에 신고 목록과 중개업자 프로필 목록도 함께 받습니다.

## Approval Workflow

공개 목록 API는 `published` 매물만 반환합니다. `pending`, `rejected` 매물은 작성자와 관리자 대시보드에서만 관리합니다.

- 생성: 일반 부동산 회원은 `pending`, `admin`은 `published`
- 승인: `POST /api/v1/real-estate/:listingId/approve`
- 반려: `POST /api/v1/real-estate/:listingId/reject`
- 승인/반려는 `admin`만 수행할 수 있습니다.
- 매물 수정은 기존 상태를 유지합니다. 작성자가 `pending` 매물을 수정해도 자동 공개되지 않습니다.

## Reports And Inquiry Protection

신고는 상세 페이지에서 생성하고 관리자 페이지에서 처리합니다.

- 생성: `POST /api/v1/real-estate/:listingId/reports`
- 처리: `PATCH /api/v1/real-estate-report/:reportId`
- 신고 사유: `fraud`, `duplicate`, `unavailable`, `wrong_info`, `spam`, `other`
- 처리 상태: `new`, `reviewing`, `resolved`, `dismissed`
- 문의 제한: 동일 매물/이메일 기준 최근 1시간 3건 초과 시 `429 inquiry_rate_limited`를 반환합니다.

## Expiry And Republishing

공개 매물은 `expires_at`을 기준으로 만료됩니다. 공개 목록, 상세, 대시보드 API 진입 시 만료 시간이 지난 `published` 매물을 `expired`로 전환합니다.

- 기본 만료 기간: 30일
- 설정 키: `real_estate_listing_expiry_days`
- 재게시 API: `POST /api/v1/real-estate/:listingId/republish`
- 작성자 재게시: `pending`으로 전환되어 다시 승인 대기
- 관리자 재게시: 즉시 `published`로 전환되고 새 만료일 부여

## Indexes

앱 시작 시 운영 조회용 인덱스를 보장합니다.

- 생성일, 거래 유형, 매물 유형, 상태
- 국가/주 조합, 가격, 침실 수
- feature 이름
- 문의의 매물/상태 조합
- 신고의 매물/상태, 생성일
- 중개업자 프로필 사용자

## Map Search

반경 검색은 DB 호환성을 우선합니다.

- API: `GET /api/v1/real-estate?latitude=-33.8688&longitude=151.2093&radiusKm=10`
- `radiusKm` 없이 좌표만 보내면 기본 10km로 검색합니다.
- `radiusKm` 최대값은 1000km입니다.
- SQL에서는 bounding box로 후보를 줄이고, 서버에서 haversine 거리 계산으로 최종 필터링합니다.
- 응답의 각 매물에는 검색 중심점 기준 `distanceKm`가 포함됩니다.
- `/api/v1/map/markers`에는 좌표가 있는 published 부동산 매물도 `real-estate` marker로 포함됩니다.

## Search And Sort

목록 API는 기본 필터 외에 검색/정렬 파라미터를 제공합니다.

- 키워드: `q`는 제목, 도시, suburb, 본문을 검색합니다.
- Suburb: `suburb`는 정확히 일치하는 지역으로 필터링합니다.
- 정렬: `sort=latest`, `price_asc`, `price_desc`, `distance`
- `distance` 정렬은 `latitude`, `longitude`가 있을 때 중심점 기준 거리순으로 적용됩니다.
