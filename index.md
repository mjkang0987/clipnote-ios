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
| `App/ClipNoteApp.swift` | 앱 진입점(@main) |
| `Models/Models.swift` | 도메인 모델 |
| `Networking/APIClient.swift` | API 통신 |
| `Util/ShareText.swift` | 공유 텍스트 유틸 |
| `Theme/Theme.swift` | 테마/스타일 |
| `Info.plist` | 앱 설정 |
| `ClipNoteTests/` | 유닛 테스트 |

## 현재 상태
- **Phase 1(토대) 완료** — 시뮬레이터 빌드/테스트 그린(18 tests / 4 suites).
  - `Theme`(색·radius·`GRADIENTS`·`pickGradient` JS 해시 동일)
  - `Models`(Codable DTO: `ClipMetadata`/`DbClip`/`CreateClipInput`/`CreateClipResult` + `UClip`)
  - `APIClient`(actor, 메타·클립·OG·목록·수정·삭제, URLProtocol 스텁 테스트)
  - `ShareText`(제목+설명+링크 개행 결합, §4.3)
- **다음: Phase 2 — Auth**(Supabase SPM·AuthStore·Google/Kakao/네이버·딥링크). 세부 기능/화면은 작업하며 갱신.

## 설정 파일
- `project.yml` — XcodeGen 프로젝트 정의(타깃·스킴·설정·버전)
- `Secrets.example.xcconfig` — 시크릿 템플릿 (실제 `Secrets.xcconfig`는 gitignored)
- `.github/workflows/pr-review.yml` — PR CI(macOS 빌드)
