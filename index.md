# ClipNote iOS — index.md

> 프로젝트 구조와 현재 상태의 source of truth. 작업 완료 시 갱신한다.

## 프로젝트 정보
- **이름**: ClipNote (iOS 앱)
- **번들 ID**: `kr.co.clipnote.app` (URL 스킴 `clipnote://`)
- **스택**: Swift 6 · SwiftUI · iOS 17+ · **XcodeGen**(`project.yml` → `ClipNote.xcodeproj`)
- **백엔드**: `API_BASE`(clipnote.co.kr) · Supabase · 네이버 로그인 · AdMob (설정은 `Secrets.xcconfig`)
- **배포**: App Store/TestFlight (수동)

## 빌드
```bash
cp Secrets.example.xcconfig Secrets.xcconfig   # 값 채우기 (gitignored)
xcodegen generate                              # ClipNote.xcodeproj 생성
xcodebuild build -scheme ClipNote -destination 'generic/platform=iOS Simulator'
```

## 구조 (`ClipNote/`)
| 경로 | 역할 |
|------|------|
| `App/ClipNoteApp.swift` | 앱 진입점(@main), `.onOpenURL` 딥링크, AuthStore 주입, `modelContainer(LocalClip)` |
| `Auth/AuthStore.swift` | 인증(@MainActor): 세션·토큰·OAuth·네이버 |
| `Auth/AuthDeepLink.swift` | `clipnote://auth/...` 파싱 |
| `Models/Models.swift` | 도메인 모델 |
| `Networking/APIClient.swift` | API 통신 |
| `Local/LocalClip.swift` | `@Model` 로컬 클립(SwiftData) |
| `Local/LocalClipStore.swift` | 로컬 저장소(@MainActor): upsert·300캡·최신순·knownTags |
| `Local/UClipMapping.swift` | `UClip` 매핑(Local/Db) + `parseTags` |
| `Util/APIClient·Config` | Config: Info.plist 설정 읽기 |
| `Util/ShareText.swift` | 공유 텍스트 유틸 |
| `Util/URLHelpers.swift` | `isFetchableUrl`·`prettyHost` |
| `Clips/ClipsStore.swift` | 목록 상태·로직(@MainActor @Observable): 로드·편집·삭제·makeShared·applyTags·shareText |
| `Clips/ClipsView.swift` | 내 클립 목록(필터칩·카드·스와이프·⋯메뉴·다중선택) |
| `Clips/FilterChip.swift` | 태그 필터 칩 |
| `Clips/ClipsRefresh.swift` | 목록 새로고침 신호(NotificationCenter) |
| `Clips/MigrateLocalClips.swift` | 로그인 시 로컬→DB 마이그레이션(§5) |
| `Views/RootView.swift` | 루트 게이트(온보딩 분기 + 로그인 마이그레이션 훅) |
| `Views/HomeView.swift` | 홈(URL 디바운스 메타·미리보기·저장), `HomeViewModel` |
| `Views/SharePreviewCard·ClipCardView.swift` | 미리보기 카드(OG 재현·클립 카드·TagChip) |
| `Views/EditClipModal·ShareResultModal·TagApplyModal.swift` | 편집·공유결과·태그일괄 모달 |
| `Views/AppRouter.swift` | 내비게이션 상태(@Observable): path·로그인·Safari |
| `Views/HeaderMenu.swift` | 공통 좌측 메뉴(이동·로그인/로그아웃/회원탈퇴·개인정보) |
| `Views/OnboardingView.swift` | 온보딩 슬라이드(TabView 4) |
| `Views/AboutView·FaqView·BrandLogo.swift` | 소개·FAQ·브랜드 로고 |
| `Views/PrivacyView.swift` | 개인정보처리방침(네이티브 정적) |
| `Views/AccountDeleteView.swift` | 회원 탈퇴(deleteAccount) |
| `Ads/AdConfig·AdBannerView.swift` | AdMob 배너(GoogleMobileAds 12, 앵커 적응형) |
| `Views/LoginView.swift` | 로그인(Google/Kakao/네이버) |
| `Views/SafariView.swift` | SFSafariViewController 래퍼(네이버·바로가기·개인정보) |
| `Theme/Theme.swift` | 테마/스타일 |
| `Info.plist` | 앱 설정 |
| `PrivacyInfo.xcprivacy` | 개인정보 매니페스트(심사) |
| `ClipNoteTests/` | 유닛 테스트 |

## 현재 상태
- **Phase 1~5 + AdMob 완료** — 빌드/테스트 그린(76 tests / 13 suites, iPhone 17 Pro). **RN 기능 패리티 완성**.
  - Phase 1: `Theme`(pickGradient JS해시 동일)·`Models`(Codable)·`APIClient`(actor 7엔드포인트: 메타·클립·OG·목록·수정·삭제·계정삭제)·`ShareText`(§4.3)
  - Phase 2: `AuthStore`(Supabase 2.51.0)·`AuthDeepLink`·Google/Kakao OAuth(ASWebAuth PKCE)·네이버 커스텀 OAuth(SFSafari+magiclink)·`Config`
  - Phase 3: `LocalClipStore`(SwiftData upsert·300캡·knownTags)·`UClip`매핑·`parseTags`·`HomeView`/`HomeViewModel`(600ms 디바운스 메타·게스트 로컬/로그인 DB 저장)·미리보기 카드.
  - Phase 4: `ClipsStore`·`ClipsView`(목록·필터·스와이프·⋯메뉴·다중선택)·`Edit/ShareResult/TagApply` 모달·공유복사(§4.3)·`MigrateLocalClips`.
  - Phase 5: `HeaderMenu`+`AppRouter`(공통 메뉴·로그아웃·전 화면 라우팅)·`AboutView`/`FaqView`/`AccountDeleteView`·`OnboardingView`(실제 슬라이드)·`deleteAccount` API·`PrivacyInfo.xcprivacy`(심사).
  - ⚠️ **#7/#8 실제 OAuth 로그인은 미검증 머지** — provider·서버 콜백 설정에 따라 실동작 별도 확인 필요.
  - AdMob(#48 재개·완료): `AdConfig`(DEBUG 테스트/RELEASE Secrets)·`AdBannerView`(앵커 적응형)·App ID 가드 start. Home(키보드 숨김)·Clips 하단. 실 App ID `~9380940221`, 배너 unit `/6008671423`(Secrets, gitignored).
- **배포 단계(TestFlight)** — App Store Connect "ClipNote by pikaworks"(App `6792600343`). `fastlane ios beta`로 빌드 **3까지 업로드**. 배포 파이프라인·서명·API키 위치는 **plan.md "진행 중 — 배포" 섹션 참고**.
  - 실기기 QA 수정: 로그인 시트 닫힘·개인정보 방침 네이티브(PR #59, 빌드3).
- **미완/이월(사람만 가능)**:
  - **실기기 검증** — OAuth 3종 실제 로그인·실광고 노출, 전체 QA.
  - App Store Connect: 개인정보 URL(`https://clipnote.co.kr/privacy`) 입력(제출 필수)·스크린샷·설명·심사 제출(수동). 앱 아이콘은 사용자 제공 512→1024 업스케일본(원본 있으면 교체).
  - Privacy Manifest는 AdMob 포함 상태 재검토 여지(`NSPrivacyTracking`/추적 도메인 — 현재 false).

## 설정 파일
- `project.yml` — XcodeGen 프로젝트 정의(타깃·스킴·설정·버전)
- `Secrets.example.xcconfig` — 시크릿 템플릿 (실제 `Secrets.xcconfig`는 gitignored)
- `.github/workflows/pr-review.yml` — PR CI(macOS 빌드)
