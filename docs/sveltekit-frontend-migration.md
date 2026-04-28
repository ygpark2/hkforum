# SvelteKit Frontend Split

## 목표
- 공개 포럼 UI를 Yesod 템플릿에서 분리해 `frontend/` SvelteKit 앱으로 옮긴다.
- 빌드 산출물은 `static/app/`에 배포한다.
- Yesod는 API, 인증, 폼 POST, 권한 검증을 유지한다.

## 구조
- `frontend/`: SvelteKit SPA 소스
- `static/app/`: SvelteKit build 결과물
- `static/css/tailwind.css`: Yesod 템플릿과 Svelte 컴포넌트가 공유하는 Tailwind 결과물
- `src/Application.hs`: WAI fallback으로 공개 GET 라우트에서 `static/app/app.html` 반환
- `/api/v1/bootstrap`: 공통 레이아웃에 필요한 사이트/사용자/CSRF 부트스트랩 데이터 제공

## 라우팅 전략
- SvelteKit로 전환:
  - `GET /home`
  - `GET /boards`
  - `GET /board/:id`
  - `GET /post/:id`
  - `GET /companies`
  - `GET /jobs`
  - `GET /admin/*`
  - `GET /settings*`
  - `GET /notifications`
  - `GET /chats`
- Yesod 유지:
  - `/api/v1/oauth/*`
  - `/api/v1/*`
  - `/files/*`
  - `/static/*`
  - `/favicon.ico`
  - `/robots.txt`

## 데이터 전략
- 조회는 `/api/v1/*` 사용
- 좋아요/북마크/팔로우/리액션은 기존 API 엔드포인트를 호출
- 글/회사/채용 생성과 수정도 API로 통일

## 빌드
- `make frontend-build`
- 출력:
  - `static/app/app.html`
  - `static/app/_app/*`
  - `static/css/tailwind.css`
