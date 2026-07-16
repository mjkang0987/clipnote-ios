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
| `Views/RootView.swift` | 루트 게이트(온보딩 `@AppStorage` 분기) |
| `Views/HomeView.swift` | 홈(URL 디바운스 메타·미리보기·저장), `HomeViewModel` |
| `Views/SharePreviewCard·ClipCardView.swift` | 미리보기 카드(OG 재현·클립 카드·TagChip) |
| `Views/LoginView.swift` | 로그인(Google/Kakao/네이버) |
| `Views/SafariView.swift` | SFSafariViewController 래퍼(네이버) |
| `Theme/Theme.swift` | 테마/스타일 |
| `Info.plist` | 앱 설정 |
| `ClipNoteTests/` | 유닛 테스트 |

## 현재 상태
- **Phase 1·2·3 완료** — 빌드/테스트 그린(58 tests / 11 suites, iPhone 17 Pro).
  - Phase 1: `Theme`(pickGradient JS해시 동일)·`Models`(Codable)·`APIClient`(actor 6엔드포인트)·`ShareText`(§4.3)
  - Phase 2: `AuthStore`(Supabase 2.51.0, 세션·토큰·`authStateChanges`)·`AuthDeepLink`·Google/Kakao OAuth(ASWebAuth PKCE)·네이버 커스텀 OAuth(SFSafari+magiclink)·`Config`
  - Phase 3: `LocalClipStore`(SwiftData upsert·300캡·knownTags)·`UClip`매핑·`parseTags`·`HomeView`/`HomeViewModel`(600ms 디바운스 메타·게스트 로컬/로그인 DB 저장)·미리보기 카드·온보딩 게이트. 루트를 HomeView로.
  - ⚠️ **#7/#8 실제 OAuth 로그인은 미검증 머지** — provider(Supabase)·서버 콜백 설정에 따라 실동작은 별도 확인 필요.
- **다음: Phase 4 — ClipsView**(목록·필터·스와이프·다중선택·편집/공유복사 §4.2/4.3), 전체 ShareResultModal, 로그인 마이그레이션(§5).
  - Phase 3 이월: 헤더 메뉴(About/FAQ/로그아웃)·AdBanner·실제 온보딩 슬라이드 = Phase 5. 홈 공유 결과는 현재 최소 시트(링크+복사)만.

## 설정 파일
- `project.yml` — XcodeGen 프로젝트 정의(타깃·스킴·설정·버전)
- `Secrets.example.xcconfig` — 시크릿 템플릿 (실제 `Secrets.xcconfig`는 gitignored)
- `.github/workflows/pr-review.yml` — PR CI(macOS 빌드)
