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
`Shared/Localization/Localizable.xcstrings` 에 있고, 번역이 없는 키는 한국어로 폴백한다.
키 이름은 웹 저장소의 `lib/i18n/messages/ko.ts` 와 맞춘다.

자세한 내용은 `plan.md` "앱 다국어" 절.

### 카탈로그를 만질 때 (중요)

`Localizable.xcstrings` 는 사람과 Xcode 가 번갈아 쓰는 파일이다. 형식이 어긋나면 **내용이 그대로여도
파일 전체가 diff 로 잡혀 `git pull` 이 막힌다.** 두 가지로 막아 놨다.

1. **`Text("리터럴")` 을 쓰지 않는다.** SwiftUI `Text` 는 리터럴을 받으면 — 보간이 있어도
   (`Text("· \(item)")`) — `LocalizedStringKey` 로 해석돼 Xcode 가 카탈로그에 밀어 넣는다.
   - 번역 문구 → `Text(i18n.t("키"))`
   - 브랜드명·기호·번호 → `Text(verbatim: "…")`
   - CI 가 막는다(`check_text_literals`). **이게 가장 확실한 차단이다** — 빌드 설정과 달리
     프로젝트 재생성 여부에 좌우되지 않는다.
2. `project.yml` 의 `SWIFT_EMIT_LOC_STRINGS: NO` — 추출 자체를 끄는 보조 장치.
   `xcodegen generate` 를 다시 돌려야 적용되므로 1번이 주된 방어선이다.
3. 정규 형식 검사 — 카탈로그를 손으로 고쳤으면 `python3 scripts/check-localizations.py --format`.

그래도 `pull` 이 이 파일 때문에 막히면, 로컬 변경은 도구가 만든 것이라 버려도 된다:

```bash
cp Shared/Localization/Localizable.xcstrings /tmp/xcstrings-backup.json   # 백업(선택)
git restore Shared/Localization/Localizable.xcstrings
git pull origin develop && xcodegen generate
```

## 브랜치

`main`(배포) ← `develop`(통합) ← `feature/*`.
**`main` push 는 곧 TestFlight 자동 배포**(`deploy.yml`)라, `develop → main` 승격은
지시자 승인이 있을 때만 한다.
