# 작업 계획

> 진행 중인 작업의 배경·범위·구현 항목·리스크를 적는다. 완료되면 비운다.

---

## 예정 — Phase 5: 헤더 메뉴 · 정적 화면 · 온보딩 · AdMob · 심사 대비 (에픽)

설계 §4.4~4.7·§3.6·마일스톤 7~9. RN `components/HeaderMenu·AdBanner` + `lib/ads·onboarding` + `app/{about,faq,onboarding,account/delete}.tsx` 이식.
Phase 4까지 = 핵심 기능 완성. Phase 5 = 부가 화면·수익화·앱스토어 심사 준비.

> 착수 방식: CLAUDE.md Work Request Flow. 에픽 + 서브이슈. 서브별 브랜치 → TDD(로직) / 빌드(UI) → 빌드·테스트(`iPhone 17 Pro`) → `/code-review` → PR → CI → 머지. 재사용: `AppColor`·`Radius`·`Config`·`AuthStore`·`LocalClipStore`·모달 스타일.

### 서브 분할(의존순)

**#A APIClient.deleteAccount + DeleteAccountResult — 순수 TDD (D 선행)**
- Phase 1에서 누락된 `DELETE /api/account` 이식. `DeleteAccountResult { ok: Bool; error: String? }`.
- 토큰 없으면 `(ok:false, "no_token")`, 비2xx면 서버 error, 네트워크 실패 `"network"` (RN 동일).
- 검증: URLProtocol 스텁으로 200/401/토큰없음 유닛테스트.
- 영향: `Models.swift`·`APIClient.swift` 확장, 테스트.

**#B AboutView + FaqView — 정적 콘텐츠**
- RN `about.tsx`(ClipNote 소개·동작·로그인 유무 안내)·`faq.tsx`(Q&A 5개) 이식. `BrandLogo` 컴포넌트 신규(아이콘+워드마크).
- 영향: 신규 `ClipNote/Views/AboutView.swift`·`FaqView.swift`·`BrandLogo.swift`.

**#C AccountDeleteView — 회원 탈퇴 (A 선행)**
- 동의 체크박스 → 확인 Alert → `deleteAccount` → 성공 시 `clearLocalClips`+`signOut`+홈. 비로그인 가드.
- 영향: 신규 `ClipNote/Views/AccountDeleteView.swift`.

**#D OnboardingView — 실제 슬라이드(TabView 4)**
- RN `onboarding.tsx` 4슬라이드(welcome/how/more/share) 이식. `TabView(.page)` 도트·건너뛰기·다음·시작하기.
- 완료 시 `onboardingSeen=true`(Phase 3 게이트 키 공유) → 홈. RootView 플레이스홀더 교체.
- 영향: 신규 `ClipNote/Views/OnboardingView.swift`, `RootView` 연결.

**#E HeaderMenu — 공통 사이드 메뉴 + 로그아웃**
- 좌측 햄버거 → 메뉴(새 클립/내 클립/사용법/소개/FAQ + 로그인/로그아웃/회원탈퇴 + 개인정보 웹). 로그인 상태별 항목 분기.
- iOS: 상단 toolbar leading 버튼 → 사이드 시트/오버레이. Home·Clips 등 상위 화면 toolbar에 배선(재사용 modifier).
- 로그아웃: `AuthStore.signOut` → 목록/홈 갱신. 회원탈퇴 → #C 화면.
- 영향: 신규 `ClipNote/Views/HeaderMenu.swift`, Home/Clips toolbar 연결.

**#F AdMob 배너 — GoogleMobileAds**
- SPM `GoogleMobileAds` 추가(project.yml). `AdBannerView`(UIViewRepresentable, ANCHORED_ADAPTIVE). DEBUG=테스트 unit id, RELEASE=실 unit id `ca-app-pub-3019917862455282/4728467083`. 예약 높이 64.
- 앱 시작 시 `MobileAds.shared.start()`. Home 키보드 시 숨김(Phase 3 이월). Home·Clips 하단 배선.
- Secrets: `ADMOB_APP_ID`·`ADMOB_BANNER_UNIT_ID` 채움. Info.plist `GADApplicationIdentifier`·`SKAdNetworkItems`.
- 영향: 신규 `ClipNote/Ads/AdBannerView.swift`·`AdConfig.swift`, project.yml·Info.plist·App·Home/Clips.

**#G 심사 대비 — Privacy Manifest**
- `PrivacyInfo.xcprivacy`(수집 데이터 유형·이유, Required Reason API). AdMob·Supabase SDK 요구사항 반영.
- ATT/추적 도메인·개인정보 URL 점검. 앱 아이콘·런치스크린 확인.
- 영향: 신규 `ClipNote/PrivacyInfo.xcprivacy`, project.yml 포함.

### 리스크
- **AdMob**: `GADApplicationIdentifier`가 빈값/무효면 SDK가 시작 시 크래시 → CI(Secrets 빈값)에서 앱 실행 위험. `start()` 가드 또는 구글 공개 테스트 App ID로 개발. CI는 빌드만이라 실행 없음 → 빌드 통과 우선.
- SPM에 GoogleMobileAds 추가 → CI 패키지 해석 시간·바이너리 크기 증가.
- HeaderMenu를 NavigationStack 구조에 자연스럽게(모든 상위 화면 진입점). expo-router replace 시맨틱 → iOS NavigationStack path.
- 로그아웃/탈퇴 후 상태 정리(세션·로컬·목록 새로고침) 일관성.
- 심사: 개인정보 처리방침 URL·계정 삭제 경로(App Store 필수) 확보 — 탈퇴 화면으로 충족.

---

## 완료 — Phase 4: ClipsView + 편집/공유/다중선택 + 로그인 마이그레이션 (에픽 #28)

설계 §4.2·§4.3·§4.7·§5. RN app/clips.tsx + 모달3종 + clips-refresh + 마이그레이션 이식. 서브 6개 전부 머지.

- #29(#A) `ClipsStore`(로컬/DB 통합 로드·삭제·편집·makeShared·applyTags add∪dedup·최대6/replace)·shareText(§4.3)·`ClipsRefresh`·`LocalClipStore.update`. 11 tests. (PR #35)
- #30(#D1) `EditClipModal`·전체 `ShareResultModal`(복사§4.3·열기·DB저장). 홈 최소시트 교체. (PR #36)
- #31(#B) `ClipsView`(List 스와이프·`FilterChip`·⋯메뉴·공유복사/만들기·바로가기), HomeView 툴바 "내 클립". 새로고침은 현재 auth로 load(캐시 ctx stale 방지). (PR #37)
- #33(#D2) `TagApplyModal`(추가/교체). (PR #38)
- #32(#C) 다중선택(로그인 전용, 롱프레스·체크박스·하단 바 태그일괄/삭제, 로그아웃 시 해제). (PR #39)
- #34(#E) `MigrateLocalClips`(로그인 시 로컬→DB 업로드, **전량 성공 시에만** clear+refresh, 부분 실패 유지) + RootView 훅. 4 tests. (PR #40)
- 전체 73 tests / 13 suites 그린(iPhone 17 Pro).

### 이월(Phase 5)
- 헤더 메뉴(About/FAQ/**로그아웃**/회원탈퇴)·실제 온보딩 슬라이드·AboutView/FaqView/AccountDeleteView·AdMob 배너·심사 대비(개인정보 매니페스트).
- ⚠️ #7/#8 실제 OAuth 로그인 실기기 검증(사람만 가능) — 미해결.

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
