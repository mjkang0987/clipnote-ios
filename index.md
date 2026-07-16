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
| `App/ClipNoteApp.swift` | 앱 진입점(@main), `.onOpenURL` 딥링크, AuthStore 주입 |
| `Auth/AuthStore.swift` | 인증(@MainActor): 세션·토큰·OAuth·네이버 |
| `Auth/AuthDeepLink.swift` | `clipnote://auth/...` 파싱 |
| `Models/Models.swift` | 도메인 모델 |
| `Networking/APIClient.swift` | API 통신 |
| `Util/APIClient·Config` | Config: Info.plist 설정 읽기 |
| `Util/ShareText.swift` | 공유 텍스트 유틸 |
| `Views/LoginView.swift` | 로그인(Google/Kakao/네이버) |
| `Views/SafariView.swift` | SFSafariViewController 래퍼(네이버) |
| `Theme/Theme.swift` | 테마/스타일 |
| `Info.plist` | 앱 설정 |
| `ClipNoteTests/` | 유닛 테스트 |

## 현재 상태
- **Phase 1(토대)·Phase 2(인증) 완료** — 빌드/테스트 그린(35 tests / 6 suites).
  - Phase 1: `Theme`(pickGradient JS해시 동일)·`Models`(Codable)·`APIClient`(actor 6엔드포인트)·`ShareText`(§4.3)
  - Phase 2: `AuthStore`(Supabase 2.51.0, 세션·토큰·`authStateChanges`)·`AuthDeepLink`·Google/Kakao OAuth(ASWebAuth PKCE)·네이버 커스텀 OAuth(SFSafari+magiclink)·`Config`
  - ⚠️ **#7/#8 실제 OAuth 로그인은 미검증 머지** — provider(Supabase)·서버 콜백 설정에 따라 실동작은 별도 확인 필요.
- **다음: Phase 3 — 로컬저장(SwiftData `LocalClipStore`) + HomeView**(설계 §3.4/§4.1).

## 설정 파일
- `project.yml` — XcodeGen 프로젝트 정의(타깃·스킴·설정·버전)
- `Secrets.example.xcconfig` — 시크릿 템플릿 (실제 `Secrets.xcconfig`는 gitignored)
- `.github/workflows/pr-review.yml` — PR CI(macOS 빌드)
