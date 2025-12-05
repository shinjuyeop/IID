# IID Health App

온보딩부터 프로필/운동/식단/마이페이지/설정까지 포함한 헬스케어 앱 프로토타입입니다. 기존 IID 코드베이스 흐름을 단순화·정리해 실제 백엔드 연동을 사용합니다.

## 핵심 흐름
- 앱 시작 시 스플래시 게이트가 상태에 따라 다음 화면으로 분기합니다.
	1) Onboarding Intro → 2) Terms Consent → 3) Login/Register → 4) Initial Profile → 5) Home
- `lib/main.dart`의 `_SplashGate`가 `SharedPreferences` 값을 보고 라우팅합니다.
	- `onboarding_intro_done`가 없으면 `/intro`
	- `onboarding_terms_agreed`가 없으면 `/terms`
	- `is_logged_in`이 아니면 `/login`
	- 로그인 상태이고 `profile_completed_<user_id>`이 아니면 `/profile`
	- 위가 모두 충족되면 `/home`

## 실행 (Windows PowerShell)

Windows에서 처음 실행 시 Flutter 플러그인(심볼릭 링크) 사용을 위해 개발자 모드가 필요할 수 있습니다.

1) 개발자 설정 열기

```powershell
start ms-settings:developers
```

2) "개발자 모드" 켜기

3) 패키지 설치 및 실행

```powershell
cd iid_health_app
flutter pub get
flutter run
```

특정 플랫폼으로 실행하려면:

```powershell
flutter run -d windows
```

> 참고: Android 실기기에서 PC 로컬 백엔드에 접속하려면 `adb reverse tcp:5000 tcp:5000` 등을 사용하세요. 웹 실행 시에는 백엔드 CORS 설정이 필요할 수 있습니다.

## 백엔드 설정

- 백엔드 기본 URL은 `lib/services/config.dart`의 `AppConfig.baseUrl`로 관리합니다.
	- 현재 기본값: `https://pertinaciously-ketogenetic-jaqueline.ngrok-free.dev`
	- 자체 서버/포트를 사용한다면 해당 값만 교체하면 됩니다.
- 로그인 테이블 표기는 `AppConfig.loginTable`로 노출됩니다(화면 안내용).

### 사용 엔드포인트(코드 기준)
- Auth: `POST /login`, `POST /register`, `POST /withdraw`
- Profile: `POST /profile/update` (초기 입력, 키/몸무게/체지방/목표/직업 개별 업데이트 포함)
- Workout: `GET /workout/history`, `POST /workout/manual/add`, `POST /workout/daily-review`
- Diet: `POST /diet/evaluate`, `GET /diet/log`
- Measurements: `GET /measurements/graph?type=weight|body_fat`
- AI Q&A: `POST /ai/ask`

## 기능 요약

- 온보딩/약관 동의: Intro와 Terms에서 동의 후 로그인으로 이동
- 인증: 이메일/비밀번호 기반 로그인/회원가입(실제 백엔드 연동). 탈퇴(`설정`) 지원
- 프로필 입력: 키/몸무게/체지방/성별/나이/목표/직업 입력 → 서버 업로드, 로컬 보관
- 홈 탭: 운동/식단/마이페이지/설정 네비게이션
	- 운동: 날짜별 기록 조회, 수동 추가(러닝 거리, 덤벨컬 중량/세트/반복 등), 일일 리뷰 + AI 피드백
	- 식단: 날짜별 아침/점심/저녁 기록, 서버 저장, AI 추천 코멘트 조회
	- 마이페이지: 저장된 프로필 확인 및 일부 항목 업데이트, 건강 관련 질문 → AI 답변
	- 설정: 로그아웃·회원 탈퇴, 계정 정보 표시

## 저장/상태 키(SharedPreferences)

- 온보딩/인증/플로우
	- `onboarding_intro_done`, `onboarding_terms_agreed`, `is_logged_in`, `user_id`
	- `profile_completed_<user_id>`: 사용자별 프로필 완료 여부
- 계정/프로필
	- `email`, `user_name`, `account_name`, `account_email`
	- `profile_height`, `profile_weight`, `profile_bodyfat`, `profile_gender`, `profile_age`, `profile_purpose`, `profile_job`
- 운동 리뷰/피드백(날짜별)
	- `workout_review_YYYY-MM-DD`, `workout_feedback_YYYY-MM-DD`
- 식단 로그/평가(날짜별)
	- `meals_YYYY-MM-DD_b|l|d`, `meals_YYYY-MM-DD_evaluation`
- 측정치 로그(로컬 백업)
	- `weight_log_YYYY-MM-DD`, `bodyfat_log_YYYY-MM-DD`

## 폴더 안내(요약)

- `lib/main.dart`: 라우팅 및 스플래시 게이트
- `lib/pages/`: 화면 구성
	- `onboarding_intro.dart`, `terms_consent.dart`, `login_page.dart`, `register_page.dart`
	- `profile_setup_page.dart`, `home_page.dart`, `exercise_page.dart`, `meals_page.dart`, `mypage_page.dart`, `settings_page.dart`
	- `device_connect_page.dart`(가이드 화면, 현재 라우트 주석 처리됨)
- `lib/services/`: API 연동 로직
	- `config.dart`(백엔드 URL), `auth_service.dart`, `profile_service.dart`,
		`exercise_service.dart`, `meals_service.dart`, `measurements_service.dart`, `ai_service.dart`

## 트러블슈팅

- 플러그인(Symlink) 오류: Windows 개발자 모드가 꺼져 있으면 활성화 후 다시 `flutter pub get`
- 환경 점검: `flutter doctor`로 SDK/툴체인 상태 확인
- 백엔드 연결 실패: `AppConfig.baseUrl` 확인, 방화벽/포트/HTTPS, 웹의 경우 CORS 확인
- Android 실기기: 로컬 서버 연결 시 `adb reverse` 또는 동일 네트워크/도메인 사용

## 다음 단계

- 기기 연결 가이드(블루투스 등) 실제 연동 추가 및 `/device` 라우트 활성화032
- 대시보드/홈 위젯 강화(오늘의 요약, 목표 진행도 등)
- 기존 Checklist/Solution 페이지 이식 및 기능 고도화

---

문의·변경 요청이 있다면 `lib/services/config.dart`의 `baseUrl`과 관련 화면을 우선 확인해 주세요.
