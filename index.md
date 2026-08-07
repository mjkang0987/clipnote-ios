# ClipNote iOS — index.md

> 프로젝트 구조와 현재 상태의 source of truth. 작업 완료 시 갱신한다.

## 프로젝트 정보
- **이름**: ClipNote (iOS 앱)
- **번들 ID**: `kr.co.clipnote.app` (URL 스킴 `clipnote://`)
- **스택**: Swift 6 · SwiftUI · iOS 17+ · **XcodeGen**(`project.yml` → `ClipNote.xcodeproj`)
- **백엔드**: `API_BASE`(clipnote.co.kr) · Supabase · 네이버 로그인 · AdMob (설정은 `Secrets.xcconfig`)
- **배포**: `main` push → `deploy.yml` 이 fastlane 으로 TestFlight 자동 업로드. App Store 심사 제출만 수동

## 빌드
```bash
cp Secrets.example.xcconfig Secrets.xcconfig   # 값 채우기 (gitignored)
xcodegen generate                              # ClipNote.xcodeproj 생성
xcodebuild build -scheme ClipNote -destination 'generic/platform=iOS Simulator'
```

## 구조 (`ClipNote/`)
| 경로 | 역할 |
|------|------|
| `App/ClipNoteApp.swift` | 앱 진입점(@main), `.onOpenURL` 딥링크, AuthStore·LocalizationStore 주입, `modelContainer(LocalClip)` |
| `Auth/AuthStore.swift` | 인증(@MainActor): 세션·토큰·OAuth·네이버·**애플**(nonce 원본/해시 분리 → `signInWithIdToken`) |
| `Auth/AuthDeepLink.swift` | `clipnote://auth/...` 파싱 |
| `Models/Models.swift` | 도메인 모델 |
| `Networking/APIClient.swift` | API 통신 |
| `Local/LocalClip.swift` | `@Model` 로컬 클립(SwiftData) |
| `Local/LocalClipStore.swift` | 로컬 저장소(@MainActor): upsert·300캡·최신순·knownTags |
| `Local/UClipMapping.swift` | `UClip` 매핑(Local/Db) + `parseTags` |
| `Util/APIClient·Config` | Config: Info.plist 설정 읽기 |
| `Util/ShareText.swift` | 공유 텍스트 유틸 |
| `Util/URLHelpers.swift` | `isFetchableUrl`·`prettyHost`·`proxiedImageURL`(`/api/image?url=` 이미지 프록시) |
| `Clips/ClipsStore.swift` | 목록 상태·로직(@MainActor @Observable): 로드·편집·삭제·makeShared·applyTags·shareText |
| `Clips/ClipsView.swift` | 내 클립 목록(필터칩·카드·스와이프·⋯메뉴·다중선택 + 로컬 클립 진입 줄) |
| `Clips/FilterChip.swift` | 태그 필터 칩 |
| `Clips/ClipsRefresh.swift` | 목록 새로고침 신호(NotificationCenter) |
| `Clips/MigrateLocalClips.swift` | 로컬→DB 업로드 실행(§5). 전량 성공 시에만 로컬을 비운다 |
| `Clips/MigrateLocalClipsLayer.swift` | 옮기기 확인·진행·결과 알림(공용 modifier). 로그인 훅과 로컬 클립 화면이 함께 쓴다 |
| `Clips/LocalClipsView.swift` | ‘이 기기에 남은 클립’ — 로그인 상태에서 로컬 클립만 보는 화면(옮기기·모두 삭제) |
| `scripts/check-secrets.sh` | 시크릿 형식 검증(값은 출력 안 함). 배포 게이트·`Secrets Check` 가 쓴다 |
| `scripts/check-localizations.py` | 문자열 카탈로그 무결성 검사. CI 첫 스텝 |
| `Views/RootView.swift` | 루트 게이트(온보딩 분기 + 로그인 마이그레이션 훅) |
| `Views/HomeView.swift` | 홈(URL 디바운스 메타·미리보기·저장·로딩 인디케이터·투어 앵커), `HomeViewModel`. 헤더 타이틀 없음 |
| `Views/SharePreviewCard·ClipCardView.swift` | 미리보기 카드(OG 재현·클립 카드·TagChip) |
| `Views/ClipThumbnail.swift` | 공용 썸네일(그라디언트 + **프록시 경유** 원본 이미지). 홈 카드·목록 행이 함께 쓴다 — 전에 따로 그리다 목록만 프록시가 빠졌었다 |
| `Views/EditClipModal·ShareResultModal·TagApplyModal.swift` | 편집·공유결과·태그일괄 모달 |
| `Views/ConfirmLayer.swift` | 공용 확인 레이어(제목·본문·확인/취소) + `emphasized()` 강조 텍스트 + `sheetHeightFitsContent()`(시트 높이를 내용에 맞춤 — 모달 4곳이 함께 쓴다). 웹 `ModalShell` 대응 — 확인 계열은 액션 시트가 아니라 레이어로 띄운다 |
| `Views/SpinnerLabel.swift` | 공용 인라인 로딩 스피너 라벨 |
| `Views/RunningDino.swift` | 로딩 중 **화면 가장자리 안쪽을 걸어 다니는** 도트 공룡(4프레임, `Canvas`). 네 면 중 한 면은 건너뛰고 코너는 점프로 돈다. 동작 줄이기 설정 존중 |
| `Views/SpotlightTour.swift` | 온보딩 스포트라이트 투어(앵커·오버레이·역마스크·`ClipsPreviewMock`) |
| `Views/AppRouter.swift` | 내비게이션 상태(@Observable): path·로그인·Safari |
| `Views/HeaderMenu.swift` | 공통 좌측 메뉴(이동·로그인/로그아웃/회원탈퇴·개인정보) |
| `Views/OnboardingView.swift` | 온보딩 — 실제 홈 UI 스포트라이트 투어(URL·제목/태그·저장·공유 + 내 클립 미리보기 목업) |
| `Views/AboutView·FaqView·BrandLogo.swift` | 소개·FAQ·브랜드 로고(BrandLogo = 앱 아이콘 `BrandIcon` 에셋) |
| `Views/PrivacyView.swift` | 개인정보처리방침(네이티브 정적) |
| `Views/AccountDeleteView.swift` | 회원 탈퇴(deleteAccount) |
| `Ads/AdConfig·AdBannerView.swift` | AdMob 배너(GoogleMobileAds 12, 앵커 적응형) |
| `Views/LoginView.swift` | 로그인(**Apple**/Google/Kakao/네이버). 애플은 시스템 `SignInWithAppleButton` — 브랜딩 규정 탓에 직접 그리지 않는다 |
| `Views/SafariView.swift` | SFSafariViewController 래퍼(네이버·바로가기·개인정보) |
| `Theme/Theme.swift` | 테마/스타일 |
| `Info.plist` | 앱 설정 |
| `PrivacyInfo.xcprivacy` | 개인정보 매니페스트(심사) |
| `ClipNoteTests/` | 유닛 테스트 |

`Shared/`(앱·공유 확장 두 타깃이 함께 쓰는 코드)

| 경로 | 역할 |
|------|------|
| `Shared/SharedURLStore.swift` | 확장 → 앱 URL 전달(App Group) |
| `Shared/Localization/AppLanguage.swift` | 지원 언어 enum(ko·en·ja·zh-Hans) + 시스템 선호 언어 매칭 |
| `Shared/Localization/LocalizationStore.swift` | 표시 언어 상태·문자열 조회(@MainActor @Observable). 언어별 `.lproj` 직접 조회 → **재시작 없이 전환**, 번역 없으면 한국어 폴백. 선택값은 App Group 에 저장(확장과 공유) |
| `Shared/Localization/Localizable.xcstrings` | 문자열 카탈로그(원본 `ko`). 키 이름은 웹 `lib/i18n/messages/ko.ts` 와 맞춘다 |
| `scripts/check-localizations.py` | 카탈로그 무결성 검사(CI 첫 스텝). 번역 누락·포맷 지시자 불일치·미사용/미등록 키·잔여 한글 리터럴 + **정규 형식**. `--format` 으로 다시 쓴다 |

## 현재 상태
- **Phase 1~5 + AdMob 완료** — 빌드/테스트 그린(76 tests / 13 suites, iPhone 17 Pro). **RN 기능 패리티 완성**.
  - Phase 1: `Theme`(pickGradient JS해시 동일)·`Models`(Codable)·`APIClient`(actor 7엔드포인트: 메타·클립·OG·목록·수정·삭제·계정삭제)·`ShareText`(§4.3)
  - Phase 2: `AuthStore`(Supabase 2.51.0)·`AuthDeepLink`·Google/Kakao OAuth(ASWebAuth PKCE)·네이버 커스텀 OAuth(SFSafari+magiclink)·`Config`
  - Phase 3: `LocalClipStore`(SwiftData upsert·300캡·knownTags)·`UClip`매핑·`parseTags`·`HomeView`/`HomeViewModel`(600ms 디바운스 메타·게스트 로컬/로그인 DB 저장)·미리보기 카드.
  - Phase 4: `ClipsStore`·`ClipsView`(목록·필터·스와이프·⋯메뉴·다중선택)·`Edit/ShareResult/TagApply` 모달·공유복사(§4.3)·`MigrateLocalClips`.
  - Phase 5: `HeaderMenu`+`AppRouter`(공통 메뉴·로그아웃·전 화면 라우팅)·`AboutView`/`FaqView`/`AccountDeleteView`·`OnboardingView`(실제 슬라이드)·`deleteAccount` API·`PrivacyInfo.xcprivacy`(심사).
  - ⚠️ **#7/#8 실제 OAuth 로그인은 미검증 머지** — provider·서버 콜백 설정에 따라 실동작 별도 확인 필요.
  - AdMob(#48 재개·완료): `AdConfig`(DEBUG 테스트/RELEASE Secrets)·`AdBannerView`(앵커 적응형)·App ID 가드 start. Home(키보드 숨김)·Clips 하단. 실 App ID `~9380940221`, 배너 unit `/6008671423`(Secrets, gitignored).
- **배포 단계(TestFlight)** — App Store Connect "ClipNote by pikaworks"(App `6792600343`). `main` push 마다 `fastlane ios beta` 가 자동 업로드한다(빌드번호 = TestFlight 최신+1). 최근 업로드는 **1.1.0 빌드 21(2026-08-04, 배포 #18)** 이고 **실기기 구동 확인됨**. 배포 전 시크릿 검증 게이트가 걸려 있어 값이 깨져 있으면 빌드가 만들어지지 않는다. 배포 파이프라인·서명·API키 위치는 **plan.md "진행 중 — 배포" 절**과 `docs/DEPLOY.md` 참고.
  - 실기기 QA 수정: 로그인 시트 닫힘·개인정보 방침 네이티브(PR #59, 빌드3).
- **출시 후속 UI 개선(2026-07-20)**: 홈 헤더 타이틀 제거(#65)·BrandLogo 앱 아이콘 교체(#66)·주요 async 로딩 인디케이터(#67)·온보딩 스포트라이트 투어(#68, #70)·URL 입력 텍스트 검정 고정(#73)·공유 복사 제목·링크만(#75)·공유 카드 원본이미지+프록시(#77). 투어 시각 검증은 사용자 직접.
  - 보류: 내 클립 무한스크롤(임계 도달 시 cursor 방식). 다국어는 보류 해제 — 아래 항목 참고.
- **다국어(2026-07-30~31)**: 한국어(원본)·영어·일본어·중국어 간체, 전 화면 사전화 완료(키 191개).
  설정 > 표시 언어에서 **재시작 없이** 바뀐다. 키 이름·문구의 소스오브트루스는 웹 `clipnote` 사전이고,
  개인정보처리방침 **본문은 번역하지 않는다**(법적 문서 — 비한국어에서 안내만 붙인다).
  - `Shared/Localization/` 이 앱·공유 확장 두 타깃에 실린다. 선택 언어는 **App Group** 에 저장한다 —
    확장은 앱과 `standard` 도메인이 달라서, 맞추지 않으면 공유 시트만 다른 언어로 뜬다.
  - 사용자에게 보이는 오류는 문자열이 아니라 케이스(`HomeError`·`AuthErrorMessage`)로 두고 뷰가 번역한다.
    모델이 문장을 만들면 그 시점 언어로 굳어, 언어를 바꿔도 오류만 옛 언어로 남는다.
  - `scripts/check-localizations.py` 가 CI 첫 스텝에서 카탈로그를 검사한다(Xcode 없이 도는 유일한 검증).
  - **남은 것: 시뮬레이터/실기기에서 4개 언어 눈으로 확인**(고정 높이 시트의 번역문 잘림 등) — 사람만 가능.
  - 범위·결정·순서는 `plan.md` "앱 다국어" 절 참고.
- **로그인 첫 진입 깜빡임 수정(2026-07-23)**: 로그인 사용자가 처음 진입 시 홈 액션이 게스트→로그인 UI로 튀던 문제. `AuthStore`가 지난 실행 로그인 여부를 `UserDefaults`에 저장하고 세션 확정 전(loading)엔 `displayLoggedIn` 힌트로 렌더, `HomeView.actions`가 이를 사용. CI(`pr-review.yml`)에 `claude/**` push 트리거 추가. (PR #107)
- **로그인 상태의 로컬 클립 처리(2026-08-03)**: 로그인 목록은 **계정 클립만** 보여 준다.
  이 기기에만 남은 클립은 목록 위 ‘이 기기에 남은 클립 n개 ›’ 진입 줄에서 전용 화면
  (`LocalClipsView`)으로 들어가 옮기거나 모두 지운다.
  - 로그인 직후 옮기기를 **한 번 권하되**, 거절해도 아무것도 지우지 않는다. 전에는 거절이 곧
    "그럼 지울까?" 로 이어졌는데 — 로그인 목록에서 볼 방법이 없어 남겨 둘 자리가 없었다 —
    거절이 삭제를 뜻하면 그건 선택지가 아니다.
  - 한 목록에 **섞지 않는다.** 계정 클립만 공유 링크를 만들 수 있고(로컬은 slug 가 없다) 다른
    기기에서도 보인다. 겉모습이 같은데 할 수 있는 일이 다르면 눌러 보고 나서야 알게 된다.
  - 옮기기 확인·진행·결과 알림은 `MigrateLocalClipsLayer` 하나를 로그인 훅과 로컬 화면이 함께 쓴다.
  - 웹 `clipnote` 도 같은 구성(`LocalClipsPanel`). **한쪽만 바꾸지 않는다.**
- **1.1.0 실행 즉시 크래시 — 해결(2026-08-04, 빌드 21에서 구동 확인)**:
  `SECRETS_XCCONFIG` 의 `ADMOB_APP_ID` 칸에 **광고 단위 ID** 가 들어가 있었다(앱 ID 는 `~`,
  광고 단위는 `/` — 둘 다 `ca-app-pub-` 로 시작하고 38자라 눈으로 구분되지 않는다).
  GoogleMobileAds SDK 가 `GADApplicationIdentifier` 를 자체 검증해 앱을 종료시켰다.
  시크릿을 고쳐 다시 빌드하니 켜졌다. 경위는 git 히스토리(`plan.md` 크래시 절, `#113`) 참고.
  - **재발 방지 3중**: 배포 전 시크릿 검증 게이트(`deploy.yml`) · `check-secrets.sh` 형태 검사
    (길이·구분자 개수·두 ID 동일 여부) · `AdConfig.enabled` 가 두 ID 를 모두 확인해 값이 이상하면
    광고만 끄고 앱은 산다.
  - **아직 안 고친 것**: CI 가 Release 를 빌드하지 않는다(`-configuration` 없음). 앱을 한 번
    켜 보는 스모크 테스트도 없다 — 이번 건을 자동으로 잡을 수 있었던 유일한 검사다.
- **App Store 제출 준비(2026-08-04, `795612b`)**: 스토어 목록 정보를 저장소에서 관리한다.
  `fastlane/metadata/{ko,en-US,ja,zh-Hans}/` 에 부제·설명·키워드·프로모션 문구·URL 3종,
  `fastlane metadata` 레인이 ASC 에 올린다(바이너리·스크린샷·심사 제출은 하지 않는다).
  `name.txt`·카테고리 파일은 **일부러 두지 않았다** — 없는 파일은 deliver 가 건드리지 않으므로
  앱 이름이 조용히 바뀌는 것을 막는다. 절차는 `docs/DEPLOY.md` "App Store 심사 제출" 절.
- **심사 리젝 대응 — Sign in with Apple(2026-08-07)**: 첫 심사에서 리젝됐다. **거절 메일에는
  사유가 없고**(정형 템플릿) Resolution Center 원문을 아직 받지 못했다. 저장소에 애플 로그인이
  아예 없어 **Guideline 4.8**(소셜 로그인을 쓰면 동등한 프라이버시 로그인 필수)을 가장 유력하게
  보고 먼저 구현했다 — 사유가 달랐더라도 언젠가 걸릴 항목이라 헛일이 되지 않는다.
  - 웹 OAuth 가 아니라 **네이티브**(`ASAuthorizationAppleIDCredential` → `signInWithIdToken`).
    웹뷰로 띄우면 "이메일 가리기" 가 빠져 4.8 의 동등성이 성립하지 않는다.
  - **nonce 는 두 벌** — 애플엔 SHA-256 해시, Supabase 엔 원본. 뒤바꾸면 서버 검증만 조용히 떨어진다.
  - 함께 고침: 로그인을 **취소하면 버튼 전체가 잠긴 채 굳던 것**(취소는 `lastError` 를 바꾸지
    않아 `onChange` 가 안 떴다). 심사자 동선이라 2.1 로 읽힐 수 있어 미루지 않았다.
  - ⚠️ **콘솔 3단계가 남았다 — 안 하면 코드가 있어도 안 된다.** App ID 에 capability 활성화,
    프로파일 재발급(`match`), Supabase Apple provider 의 **Client IDs 에 번들 ID** 추가.
    CI 는 `CODE_SIGNING_ALLOWED=NO` 라 이걸 못 잡는다. 절차는 `docs/DEPLOY.md`.
- **미완/이월(사람만 가능)**:
  - **실기기 검증** — OAuth 3종 실제 로그인·실광고 노출, 전체 QA.
  - App Store Connect: 개인정보 URL(`https://clipnote.co.kr/privacy`) 입력(제출 필수)·스크린샷·설명·심사 제출(수동). 앱 아이콘은 사용자 제공 512→1024 업스케일본(원본 있으면 교체).
  - Privacy Manifest는 AdMob 포함 상태 재검토 여지(`NSPrivacyTracking`/추적 도메인 — 현재 false).

## 설정 파일
- `project.yml` — XcodeGen 프로젝트 정의(타깃·스킴·설정·버전)
  - ⚠️ `ClipNote/Info.plist`·`ClipNoteShare/Info.plist` 는 **XcodeGen 이 여기서 생성**하는데 git 에도
    추적된다. `info.properties` 를 고치면 `xcodegen generate` 후 생성된 plist 도 함께 커밋해야
    한다 — 안 그러면 로컬에서 빌드할 때마다 "modified" 로 뜬다.
  - `SWIFT_EMIT_LOC_STRINGS: NO` — Xcode 의 문자열 자동 추출을 끈다. 켜 두면 SwiftUI
    `Text("리터럴")` 이 빌드마다 문자열 카탈로그에 밀려 들어와 카탈로그가 오염된다.

### 문자열 카탈로그를 만질 때

`Localizable.xcstrings` 는 사람(스크립트)과 Xcode 가 번갈아 쓴다. **형식이 갈리면 내용이 그대로여도
파일 전체가 diff 로 잡혀 `git pull` 이 막힌다.** 그래서 정규 형식을 정해 두고 CI 가 강제한다.

- 정규 형식 = Xcode 가 쓰는 형식(Foundation `JSONSerialization` 의 `.prettyPrinted | .sortedKeys`):
  구분자 `" : "`(콜론 **앞에도** 공백), 들여쓰기 2칸, 키 정렬, 한글 이스케이프 없음, **끝에 개행 없음**.
- 손으로 고친 뒤에는 반드시 `python3 scripts/check-localizations.py --format` 를 돌린다.
- 파이썬 `json.dump` 기본값은 `": "` 라 그냥 쓰면 어긋난다.
- `Secrets.example.xcconfig` — 시크릿 템플릿 (실제 `Secrets.xcconfig`는 gitignored)
- `.github/workflows/pr-review.yml` — CI(macOS): `xcodebuild test`(build+유닛 테스트), PR + `claude/**` 브랜치 push 트리거
- `.github/workflows/deploy.yml` — TestFlight 배포(fastlane): **main push 자동**(md 제외·직렬화) + 수동(`workflow_dispatch`). 빌드번호=TestFlight 최신+1
