# 작업 계획

> 진행 중인 작업의 배경·범위·구현 항목·리스크를 적는다. 완료되면 비운다.

---

## 진행 중 — 배포(TestFlight) + 실기기 QA + App Store 출시

**마이그레이션 코드는 완료**(Phase 1~5 + AdMob, RN 기능 패리티 달성, 76 tests 그린). 남은 건 배포·QA·출시.

### 배포 파이프라인 (fastlane, 셋업 완료)
- **App Store Connect 앱**: "ClipNote by pikaworks", App ID `6792600343`, bundle `kr.co.clipnote.app`, Team `928S75PVRK`.
- **API 키**: `~/clipnote-deploy/api_key.json`(Key ID `HVWQ5859F5`, Issuer `a3490d4a-...`, .p8는 `~/Downloads/AuthKey_HVWQ5859F5.p8` + `~/.appstoreconnect/private_keys/`). ⚠️ .p8은 비밀.
- **명령**: `cd clipnote-ios && fastlane ios beta` → 인증서·프로파일(있으면 재사용)·Release 아카이브·IPA·TestFlight 업로드까지.
- **서명**: 앱 타깃 **수동 배포 서명**(project.yml: `CODE_SIGN_STYLE: Manual`, `PROVISIONING_PROFILE_SPECIFIER: "kr.co.clipnote.app AppStore"`, `CODE_SIGN_IDENTITY: Apple Distribution`). 기기 미등록 상태에서 아카이브하려면 수동 배포가 필수(자동은 development 프로파일→기기 필요→막힘). CI는 `CODE_SIGNING_ALLOWED=NO`라 무관.
- **빌드번호**: 업로드마다 `CURRENT_PROJECT_VERSION` +1. 현재 **3까지 업로드**. 다음 = 4.
- `fastlane/`·`*.p8/.p12/.cer/.mobileprovision`·`build/` gitignore.
- ⚠️ `gh` 명령은 cwd가 다른 레포일 때 `-R mjkang0987/clipnote-ios` 붙일 것.

### 실기기 QA — 발견·수정 이력
- ✅ 로그인 성공 후 LoginView 시트 안 닫히던 버그 → `dismiss()` (PR #59, 빌드3).
- ✅ 개인정보 방침을 SFSafari 웹으로 열 때 사이트 헤더·로그인 노출 → **PrivacyView 네이티브** 이식(내용 하드코딩, 웹·앱 둘 다 하드코딩 유지 결정). (PR #59)
- **남은 QA(사람만)**: Google/Kakao/네이버 **실제 로그인 3종**, 광고 노출(DEBUG=테스트광고), 전 화면 동작.

### 남은 출시 작업
- App Store Connect: **개인정보 처리방침 URL**(`https://clipnote.co.kr/privacy`) 입력(제출 필수), 스크린샷, 앱 설명, 카테고리, 연령등급.
- 앱 아이콘: 현재 사용자 제공 512→1024 업스케일본. 필요 시 1024 원본으로 교체.
- 내부 TestFlight 그룹에 빌드 연결·테스터 추가(사용자 진행 중).
- 심사 제출(수동).

### 안 한 것(의도적)
- **하위 화면 햄버거 메뉴**: RN은 모든 화면에 햄버거(_layout). iOS는 홈·클립만, 소개/FAQ/방침/탈퇴는 뒤로가기(네이티브 관례). 기능 손실 없음. 엄격 파리티 원하면 하위 화면 toolbar에 `HeaderMenu` 추가하면 됨.
- **방침 DB화(Supabase)**: 지금은 웹·앱 각각 하드코딩. 나중에 Supabase 테이블+`/api/privacy`로 단일소스화 가능(clipnote 백엔드 레포 `~/Desktop/git/clipnote`, Next16+Supabase). 화면은 재사용, 데이터소스만 교체.

### 파리티 감사 결과
RN `app/`·`components/`·`lib/` 전부 네이티브에 매핑됨. 빠진 기능 없음. `getKnownTags`(태그 자동완성)는 RN에서도 미사용(기록만) — iOS도 동일.

---

## 완료 — Phase 5: 헤더·정적화면·온보딩·심사 (에픽 #42)

설계 §4.4~4.7·§3.6·마일스톤 7~9. RN HeaderMenu·about/faq/onboarding/account-delete 이식. 서브 6/7 머지(AdMob 보류).

- #43(#A) `APIClient.deleteAccount` + `DeleteAccountResult`(Phase1 누락분). 3 tests. (PR #50)
- #44(#B) `AboutView`·`FaqView`·`BrandLogo`(정적). (PR #51)
- #45(#C) `AccountDeleteView`(동의→확인→deleteAccount→clearLocalClips+signOut). (PR #52)
- #46(#D) `OnboardingView`(TabView 4 슬라이드), RootView 플레이스홀더 교체. (PR #53)
- #47(#E) `HeaderMenu`+`AppRouter`(전 화면 라우팅·로그인/로그아웃/회원탈퇴·개인정보), Home/Clips toolbar 배선. 시뮬 실행 스모크 확인. (PR #54)
- #49(#G) `PrivacyInfo.xcprivacy`(수집유형·Required Reason CA92.1·추적 false), 앱 번들 포함 확인. (PR #55)
- #48(#F) AdMob 배너 — 보류였다가 **iOS App ID 확보 후 재개·완료**(PR #56). GoogleMobileAds 12 SPM·AdConfig·AdBannerView·App ID 가드 start·SKAdNetwork 37종. 시뮬 스모크 확인.
- 전체 76 tests / 13 suites 그린(iPhone 17 Pro).

### 남은 일 (Phase 5 이후)
- 실기기 검증: OAuth 3종 실제 로그인·실광고 노출, 제출 전 전체 QA(사람만 가능).
- 앱 아이콘·런치스크린 에셋, 개인정보 처리방침 URL 최종 확인, TestFlight/심사 제출(수동).
- Privacy Manifest — 광고 개인화 정책에 따라 NSPrivacyTracking/추적 도메인 재검토 여지.

---

## 완료 — 업무 처리 시스템 도입

- `CLAUDE.md`(업무 절차·iOS/Swift 표준), `.github/workflows/pr-review.yml`(macOS 빌드 CI), `REVIEW.md`(리뷰 기준), `index.md`/`plan.md` 스타터 추가.
- 이후 작업은 Work Request Flow(이슈→브랜치→검증→리뷰→PR→자동머지)를 따른다.

---

## 완료 — Phase 2 인증 (에픽 #4)

- #5 Supabase SPM(2.51.0) + `AuthStore` 코어, #6 딥링크 라우팅(`.onOpenURL`), #7 Google/Kakao OAuth, #8 네이버 커스텀 OAuth. 35 tests / 6 suites 그린.
- ⚠️ **#7/#8 실제 OAuth 로그인은 미검증 상태로 머지**(사용자 승인). 로그인 안 되면 provider(Supabase 콘솔)·서버 콜백 설정 확인 후 별도 fix 필요할 수 있음.
- HTTP 프로브 확인됨: Supabase Google·Kakao provider 켜짐(302 정상), 네이버 client_id·서버 `/api/auth/naver/callback` 살아있음. 남은 미검증 = redirect URL 허용목록 + 실제 자격증명 로그인(사람만 가능).

---

## 완료 — Phase 3: 로컬저장(SwiftData) + HomeView (에픽 #16)

설계 §3.4·§4.1. RN `lib/local-clips.ts` + `app/index.tsx` 이식. 서브 5개 전부 머지.

- #17(#A) `LocalClipStore`(SwiftData): upsert·300캡·최신순·`knownTags`(UserDefaults 빈도). 8 tests.
- #18(#B) `UClip` 매핑(Local/Db, id 로컬=url·DB=slug) + `parseTags`(쉼표·트림·빈값·최대6). 5 tests.
- #19(#D) 미리보기 카드 `SharePreviewCard`(OG 재현)·`ClipCardView`·`TagChip`.
- #20(#C) `HomeView`/`HomeViewModel`: 600ms 디바운스 메타 추출(이전 Task 취소)·제목 자동채움·게스트 로컬/로그인 공유·DB 저장. `URLHelpers`. 루트를 HomeView로. 10 tests.
- #21(#E) 온보딩 게이트 `RootView`(`@AppStorage` 분기).
- 전체 58 tests / 11 suites 그린(iPhone 17 Pro).

### 이월(후속 페이즈)
- **Phase 4**: ClipsView(목록·필터·스와이프·다중선택·편집)·공유복사(§4.2/4.3)·전체 ShareResultModal(열기·DB저장)·로그인 마이그레이션(`MigrateLocalClips`, §5).
- **Phase 5**: 헤더 메뉴(About/FAQ/로그아웃/회원탈퇴)·실제 온보딩 슬라이드·AdBanner·심사 대비.
- 현재 홈 공유 결과 = 최소 시트(링크+복사)만. 로그인 사용자 로그아웃 UI 없음(Phase 5 헤더 메뉴 대기).
