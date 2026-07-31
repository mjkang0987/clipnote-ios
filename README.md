# clipnote-ios

링크를 공유 카드로 바꿔 주는 서비스 [ClipNote](https://clipnote.co.kr)의 iOS 앱.
웹과 백엔드는 [`mjkang0987/clipnote`](https://github.com/mjkang0987/clipnote)이며,
공유 텍스트 규칙·다국어 문구를 그 저장소와 맞춘다. **한쪽만 바꾸지 않는다.**

- App Store: "ClipNote by pikaworks" (bundle `kr.co.clipnote.app`)

## 문서

이 README 는 진입점일 뿐이고, 실제 내용은 아래가 source of truth 다.

| 문서 | 내용 |
|---|---|
| [`index.md`](./index.md) | 프로젝트 구조·현재 상태 |
| [`plan.md`](./plan.md) | 작업 계획·결정 사항·변경 이력 |
| [`REVIEW.md`](./REVIEW.md) | 코드리뷰 기준 |
| [`CLAUDE.md`](./CLAUDE.md) | 작업 규약(브랜치·커밋·검증·위험 명령 금지) |

## 개발

```bash
cp Secrets.example.xcconfig Secrets.xcconfig   # 값 채우기 (gitignored)
xcodegen generate                              # ClipNote.xcodeproj 생성
xcodebuild build -scheme ClipNote -destination 'generic/platform=iOS Simulator'
xcodebuild test  -scheme ClipNote -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

`ClipNote.xcodeproj` 는 `project.yml`(XcodeGen)에서 생성한다 — **프로젝트 파일을 직접 고치지 않는다.**
`Secrets.xcconfig` 는 gitignored 이고, CI/배포에는 GitHub Secret `SECRETS_XCCONFIG` 로 주입된다.

## 스택

Swift 6 · SwiftUI · iOS 17+ · SwiftData · Supabase · GoogleMobileAds · XcodeGen · fastlane.

## 다국어

한국어(원본)·영어·일본어·중국어 간체. **설정 > 표시 언어**에서 바꾸며 재시작이 필요 없다.

iOS 기본 동작은 시스템 설정에서만 앱 언어가 바뀌는 구조(`Bundle.main` 이 실행 시점 언어로 고정)라,
`LocalizationStore` 가 선택 언어의 `.lproj` 번들을 직접 열어 문자열을 읽는다. 문구는
`ClipNote/Localization/Localizable.xcstrings` 에 있고, 번역이 없는 키는 한국어로 폴백한다.
키 이름은 웹 저장소의 `lib/i18n/messages/ko.ts` 와 맞춘다.

자세한 내용은 `plan.md` "앱 다국어" 절.

## 브랜치

`main`(배포) ← `develop`(통합) ← `feature/*`.
**`main` push 는 곧 TestFlight 자동 배포**(`deploy.yml`)라, `develop → main` 승격은
지시자 승인이 있을 때만 한다.
