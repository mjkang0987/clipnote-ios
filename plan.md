# 작업 계획

> 진행 중인 작업의 배경·범위·구현 항목·리스크를 적는다. 완료되면 비운다.

---

## 완료 — Phase 5: 헤더·정적화면·온보딩·심사 (에픽 #42)

설계 §4.4~4.7·§3.6·마일스톤 7~9. RN HeaderMenu·about/faq/onboarding/account-delete 이식. 서브 6/7 머지(AdMob 보류).

- #43(#A) `APIClient.deleteAccount` + `DeleteAccountResult`(Phase1 누락분). 3 tests. (PR #50)
- #44(#B) `AboutView`·`FaqView`·`BrandLogo`(정적). (PR #51)
- #45(#C) `AccountDeleteView`(동의→확인→deleteAccount→clearLocalClips+signOut). (PR #52)
- #46(#D) `OnboardingView`(TabView 4 슬라이드), RootView 플레이스홀더 교체. (PR #53)
- #47(#E) `HeaderMenu`+`AppRouter`(전 화면 라우팅·로그인/로그아웃/회원탈퇴·개인정보), Home/Clips toolbar 배선. 시뮬 실행 스모크 확인. (PR #54)
- #49(#G) `PrivacyInfo.xcprivacy`(수집유형·Required Reason CA92.1·추적 false), 앱 번들 포함 확인. (PR #55)
- **#48(#F) AdMob 배너 = 보류(close)** — iOS AdMob App ID 미확보(RN도 androidAppId만). 사용자 결정으로 나중 별도 진행.
- 전체 76 tests / 13 suites 그린(iPhone 17 Pro).

### 남은 일 (Phase 5 이후)
- AdMob 배너: 실 iOS App ID 확보 후 재개(GoogleMobileAds SPM·AdBannerView·start 가드·Info.plist GADApplicationIdentifier/SKAdNetwork).
- 실기기 검증: OAuth 3종 실제 로그인, 제출 전 전체 QA.
- 앱 아이콘·런치스크린 에셋, 개인정보 처리방침 URL 최종 확인, TestFlight/심사 제출(수동).

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
