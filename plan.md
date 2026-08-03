# 작업 계획

> 진행 중인 작업의 배경·범위·구현 항목·리스크를 적는다. 완료되면 비운다.

---

## 진행 중 — 출시 후 기능 업데이트 (2026-07-30)

> **브랜치 규칙(이번 지시)**: 앱이 이미 스토어에 출시됐으므로 배포 안정성 우선.
> 모든 작업은 `develop`까지만 병합한다. `main` 머지는 지시자의 명시적 승인이 있을 때만.
> (`CLAUDE.md`의 "CI 그린이면 main 자동 머지" 절차보다 이 지시가 우선한다.)

### ✅ 공유 텍스트 제목 길이 제한 (웹·앱 공통)

인스타 어댑터가 `og:title`(=캡션 전문)을 제목으로 쓰기 때문에(웹 `lib/adapters/instagram.ts`)
공유 텍스트가 캡션 통째로 길어졌다. 제목을 자르고 말줄임(`…`)으로 처리한다.

- `ClipNote/Util/ShareText.swift` — `shareTitleMaxLength = 80`(말줄임표 포함), `truncateShareTitle`
  추가. 공백·개행을 한 칸으로 정리(캡션 개행이 `제목\nURL` 포맷을 깨뜨려 링크 줄을 못 찾게 된다).
  호출부 3곳(`ShareResultModal`·`HomeView`·`ClipsStore`)이 이미 `buildShareText`로 모여 있어 수정은 1곳.
- `ClipNoteTests/ShareTextTests.swift` — 3 → 12케이스(상한 경계·개행 정리·이모지 비분할·인스타 캡션).
- 웹은 `lib/shareText.ts`가 같은 규칙·같은 상수(`SHARE_TITLE_MAX=80`)를 구현. **한쪽만 바꾸지 않는다.**
  웹은 `Intl.Segmenter`로 그래핌 단위를 맞춘다(`Array.from`은 코드포인트라 `☕️`가 쪼개져 iOS와 어긋남).

### 🟡 광고 미게재 해소

출시 후 실광고가 나오지 않는 문제. 원인 후보를 순서대로 정리:

1. **app-ads.txt 인증 실패** — 웹 저장소에 `public/app-ads.txt`가 없었다(있던 건 퍼블리셔 ID가 다른
   `ads.txt`). → 웹 `develop`에 `google.com, pub-3019917862455282, DIRECT, f08c47fec0942fa0` 추가 완료.
   AdMob 은 App Store 등록정보의 개발자 웹사이트 도메인 루트를 크롤링하므로 **iOS 저장소에는 넣을 자리가 없다.**
2. 🔒 **Release 빌드의 실 AdMob ID 주입 미확인** — `AdConfig`는 DEBUG에 구글 테스트 unit ID를
   하드코딩하고 RELEASE만 `Secrets.xcconfig` 값을 쓴다. 그 값은 CI에서 GitHub Secret
   `SECRETS_XCCONFIG`로 주입된다(`deploy.yml`). 이 시크릿이 비었거나 `Secrets.example.xcconfig`의
   테스트 ID(`ca-app-pub-3940256099942544`) 그대로면 광고가 안 나온다. **개발 중엔 항상 DEBUG
   경로였으므로 실 ID 경로는 한 번도 검증된 적이 없다.**
   - 게다가 `AdBannerView`는 로드 실패 시 높이 0으로 숨기고(빈 공간 방지) App ID가 없으면 아예
     렌더하지 않아, **실패가 조용하다.** 진단은 Console.app `clipnote.ads` 로그로만 가능.
3. ⬜ 후속 검토: 신규 광고 단위 활성 대기, AdMob 계정 지급 정보, UMP/ATT 동의(미구현 — 개인화 광고 불가).

### 🟡 앱 다국어 (한국어·영어·일본어·중국어 간체) — 웹 완료분 이식

웹(`clipnote`)이 2026-07-31 다국어를 완료해 운영 반영했다(웹 `plan.md` 14장). 앱은 기반과
설정 화면까지만 되어 있어 **나머지 화면을 웹과 같은 키·같은 문구로** 채운다.

#### 현재 상태

| 항목 | 상태 |
|---|---|
| `AppLanguage`(ko·en·ja·zh-Hans) | ✅ `e5091c8` |
| `LocalizationStore`(재시작 없는 전환·한국어 폴백) | ✅ `e5091c8` |
| `project.yml` `CFBundleLocalizations` | ✅ `e5091c8` |
| 설정 화면 + 표시 언어 선택 UI | ✅ `e5091c8`·`218df1f` |
| `LocalizationStoreTests`(번들 해석·언어별 값 차이) | ✅ `e5091c8` |
| 나머지 화면 문자열 | ✅ 전 화면 완료 (2026-07-31, 키 191개) |
| 공유 확장(`ClipNoteShare`) | ✅ `Shared/Localization` 이동 + App Group 저장 |
| 카탈로그 무결성 검사 | ✅ `scripts/check-localizations.py` (CI 첫 스텝) |

#### 웹에서 확정돼 앱에도 그대로 적용되는 결정

웹 작업에서 정한 것 중 **플랫폼과 무관한 규칙**은 다시 논의하지 않고 이식한다.

- **한국어가 원본, 나머지는 부분 사전.** 번역이 없는 키는 한국어로 폴백한다.
  앱은 `LocalizationStore.t(_:)` 가 "번역 없으면 키 자체 반환" 규약을 감지해 한국어 번들로 되짚는다.
- **개인정보 처리방침 본문은 번역하지 않는다.** 법적 문서라 기계 번역 게시는 효력 문제가 생긴다.
  제목·버튼만 번역하고 비한국어에서는 `language.koreanOnlyNotice`("이 문서는 한국어로만 제공됩니다")를
  붙인다. 웹 `/{en,ja,zh}/privacy` 와 같은 처리다.
- **사용자가 입력한 클립 제목·태그는 원문 유지.** 번역 대상이 아니다.
- **공급자 이름은 라틴 표기 고정**(`Google`·`Kakao`·`Naver`). 언어마다 `카카오`/`カカオ`/`卡考` 로
  갈리면 사용자가 자기 계정을 못 알아본다. 웹 `login.subtitleWithKakao` 참고.
- **날짜·수량 표기는 사전에 넣지 않는다.** 웹은 `Intl.RelativeTimeFormat`·`DateTimeFormat` 이
  4개 언어를 만들어 준다(`2025년 3월` / `March 2025` / `2025年3月` 는 사전으로 표현 불가).
  앱은 `Date.FormatStyle` + 선택 언어의 `Locale` 로 같은 결과를 낸다.
- **문장 중간의 강조·링크는 자리표시자로 둔다.** 앞/강조/뒤로 쪼개면 어순이 다른 언어에서 깨진다
  (ko `기존 태그에 {강조}` vs en `{강조} to existing tags` — 강조 낱말 위치가 반대).
  웹은 `{token}`, 앱은 `String(format:)` 의 `%@` 를 쓴다.
- **FAQ 는 단일 출처.** 웹은 화면 `<dl>` 과 FAQPage JSON-LD 가 같은 배열을 쓴다. 앱은 JSON-LD 가
  없으니 `FaqView` 한 곳이면 되지만, **문항·문구는 웹과 같은 것을 쓴다**(웹이 이번에 개선한 판).

#### 앱 특화 결정 (웹에 없는 것)

- **키 이름의 소스오브트루스는 웹 사전**(`lib/i18n/messages/ko.ts`, 189키). 앱 카탈로그가 웹에
  없는 이름을 쓰고 있으면 앱을 고친다 — 웹은 이미 운영 반영됐고 사전이 10배 크다.
  - 현재 어긋난 것: `settings.account.loggedIn`↔`settings.signedInWith`,
    `settings.account.provider`↔`settings.accountLabel`,
    `settings.account.providerFallback`↔`settings.providerUnknown`,
    `settings.contact.action`↔`settings.contactAction`, `settings.contact.note`↔`settings.contactNote`,
    `settings.row.view`↔`settings.viewLink`, `settings.danger.*`↔`settings.dangerTitle`·`dangerBody`·`withdraw`,
    `settings.signOut`↔`common.logout`, `settings.privacy`↔`common.privacy`
  - 앱에만 있는 개념(`settings.guardBody`·`guardHome` — 비로그인 가드 화면)은 앱 전용 키로
    남기되 이름 규칙은 웹처럼 평평하게 간다. 웹에는 해당 UI 가 없다.
  - 값이 갈리는 것도 있다. 저장 위치의 이름(웹 `이 브라우저에` ↔ 앱 `이 기기에`)과
    `settings.withdraw` 영문(웹 `Delete account` ↔ 앱 `Delete my account` — 앱은 제목과 버튼이
    같은 상자에 붙어 있어 같은 문구면 구분이 안 된다). 이런 건 카탈로그 `comment` 에 이유를 남긴다.
- **웹에 없는 화면**: 온보딩 스포트라이트 투어(`onboarding.*`), 공유 확장(`share.*`).
  이 두 네임스페이스는 앱이 원본이고 웹으로 갈 일이 없다.
- **`{token}` → `%@` 변환 시 순서 주의.** 한 문장에 자리표시자가 둘 이상이면 언어별로 순서가
  바뀔 수 있다. 그때는 `%1$@`·`%2$@` 위치 지정자를 쓴다(웹은 이름으로 참조해 이 문제가 없다).
- **공유 확장(`ClipNoteShare`)은 별도 번들이다.** 아래 "공유 확장을 위한 구조 변경" 참고.
- **사용자에게 보이는 오류는 문자열이 아니라 케이스로 둔다**(`HomeError`·`AuthErrorMessage`).
  표시 언어를 아는 건 뷰인데 모델은 접근할 수 없고, 모델에 스토어를 주입하면 문장이 만들어진
  시점의 언어로 굳어 언어를 바꿔도 오류만 옛 언어로 남는다. 서버·시스템이 준 문장은 그대로 통과시킨다.
- **투어 단계처럼 배열로 든 문구는 계산 프로퍼티로 둔다.** `let` 저장 프로퍼티면 뷰가 처음
  만들어진 시점의 언어로 굳는다.

#### 범위

- **포함**: 홈·내 클립·로그인·소개·FAQ·온보딩·회원 탈퇴·공통 메뉴·모달 전체의 UI 문자열,
  사용자에게 보이는 오류 메시지, 내비게이션 타이틀.
- **제외**: 개인정보 처리방침 **본문**(제목·버튼은 포함), 로그·주석·`os_log` 문자열,
  `AppLanguage.label`(각 언어를 그 언어로 표기하는 게 의도).

#### 작업 순서 (각 단위마다 작업>리뷰>개선>검증)

0. ✅ 카탈로그 무결성 검사 스크립트 — `scripts/check-localizations.py` + CI 배선.
   원래 마지막 단계였는데 **앞으로 당겼다.** 2~9단계가 전부 이 검사에 걸리는 실수를 낼 수 있고,
   Xcode 없이 도는 유일한 자동 검증이라 뒤에 두면 아홉 번 헛돈다.
1. ✅ 문자열 카탈로그 키를 웹 사전에 정렬 + `common.*` 도입
2. ✅ 공통 내비(`HeaderMenu`·`RootView`) — `1e71838`
3. ✅ 홈(`HomeView`·`HomeViewModel`) — `6077aa0`
4. ✅ 내 클립(`ClipsView`·모달 3종) — `4975db8`
5. ✅ 로그인(`LoginView`·`AuthStore`) — `c50a7b8`
6. ✅ 소개·FAQ(`AboutView`·`FaqView`) — `fa8a292`
7. ✅ 온보딩·투어(`OnboardingView`·`SpotlightTour`) — `104b15a`
8. ✅ 회원 탈퇴 + 개인정보(제목·안내) — `66a4107`
9. ✅ 공유 확장(`ClipNoteShare`) — 번들 구조 변경 동반
10. 🟡 `LocalizationStoreTests` 보강 + 전 화면 CI 그린 — 테스트 3건 추가, CI 확인 중
    - 네임스페이스별 대표 키가 **언어마다 다른 값**을 주는지(값이 갈리는지를 봐야 언어 번들이
      실제로 실렸는지 안다 — 키가 그대로 나오는지만 보면 `en.lproj` 가 통째로 빠져도 한국어로
      폴백해 통과한다)
    - 위치 지정자(`%1$@`·`%2$@`) 문장에서 두 인자가 모두 살아 있는지
    - 표시 언어가 `standard` 가 아니라 App Group 에 저장되는지(회귀 방지)

#### 공유 확장을 위한 구조 변경 (9단계)

`ClipNote/Localization/` 을 `Shared/Localization/` 으로 옮겼다. `project.yml` 에서 확장 타깃의
소스가 `ClipNoteShare` + `Shared` 뿐이라, 그 아래로 옮겨야 문자열 카탈로그가 확장 번들에도
컴파일된다. 확장 타깃에도 `CFBundleLocalizations` 를 선언했다.

**선택 언어의 저장 위치를 `UserDefaults.standard` 에서 App Group 으로 바꿨다.** 확장은 앱과
`standard` 도메인이 달라서, standard 에 두면 확장이 사용자의 선택을 읽지 못한다 — 앱은 영어인데
공유 시트만 한국어로 뜬다. 아직 출시되지 않은 기능이라 기존 값을 옮길 필요는 없다.

#### 옮기기 레이어 플로우 정렬 (웹 → 앱)

문구만이 아니라 **동작**도 웹에 맞췄다. 웹은 세 단계로 다듬어져 있었다
(`a0f931d` 레이어 신설 → `ec7221d` 거절 시 삭제 확인 → `4323eb6` 그냥 닫으면 보류).

- **왜 거절에 삭제 확인이 붙나** — 로그인 목록은 DB 를 보여준다(`ClipsStore.load`). 옮기지 않은
  로컬 클립은 그때부터 화면에서 볼 방법이 없어 남겨 둘 자리가 없다. 웹도 같은 이유다.
- **확인 계열은 액션 시트가 아니라 레이어다.** 웹이 네이티브 `confirm()` 을 걷어내고 레이어로
  바꿔 놨다(`c6c1d54` 이후 `/clips` 확인 6개가 전부 `ModalShell`). 앱도 맞춘다 —
  `ConfirmLayer` 신설, 옮기기·삭제 확인·단건 삭제·일괄 삭제 4개를 옮겼다.
  - 모양 때문만이 아니라 **동작 때문이다.** `confirmationDialog` 는 바깥을 눌러 닫은 것과
    취소를 누른 것을 구분하지 못한다. 옮기기 흐름은 그 둘이 달라야 한다(닫기=보류,
    취소=옮기지 않겠다는 의사 → 삭제 확인). 버튼을 직접 그려야 구분이 선다.
  - 세 갈래: `옮기기`(진행 중 레이어 유지·스와이프 잠금) / `취소`(→ 삭제 확인) / 스와이프(보류).
  - 삭제는 웹과 똑같이 한 단계 더 확인받는다(되돌릴 수 없다 — 서버 사본이 없다).
  - `ConfirmLayer` 는 내용 높이를 재서 detent 로 쓴다. 고정 높이면 번역문이 긴 언어에서 잘린다.
  - 남은 고정 높이: `EditClipModal`(280) · `TagApplyModal`(340) · `ShareResultModal`(320).
    이 셋은 이번에 손대지 않았다 — 눈으로 확인한 뒤 필요하면 같은 방식으로 옮긴다.

#### 검증

- 로컬 빌드 불가(리눅스 컨테이너, Xcode 없음) → `develop` push 로 `pr-review.yml`
  (`xcodebuild build` + `xcodebuild test`) 그린까지를 검증으로 본다.
- `scripts/check-localizations.py` — 카탈로그 JSON 을 직접 검사한다. Xcode 없이 도는 유일한
  자동 검증이라 CI 의 첫 스텝으로 배선했다(빌드 전에 몇 초 만에 거른다).
  - 모든 키가 4개 언어를 다 갖는가 / 값이 비지 않았는가
  - 언어별 포맷 지시자(`%@`·`%1$@`) 개수·순서가 한국어와 같은가 — 다르면 **런타임 크래시**
  - 4개 언어 값이 전부 같은가(번역을 잊은 것). 의도면 `comment` 로 이유를 남기게 한다
  - 코드가 쓰는 키가 카탈로그에 있는가 / 카탈로그 키를 쓰는 곳이 있는가
  - `CLEAN_FILES` 에 올린 파일에 한글 리터럴이 되살아났는가 — **화면을 끝낼 때마다 이 목록에
    추가한다.** 목록 자체가 진행 상황이자 되돌림 방지 장치다
  - 카탈로그가 **정규 형식**인가 — 아래 참고
  - 5개 검사 모두 일부러 깨뜨려 잡히는 걸 확인했다(누락·지시자 불일치·전 언어 동일·없는 키·죽은 키).

#### 카탈로그 형식 고정 (2026-07-31)

로컬에서 `git pull` 이 두 번 막혔다. 원인이 둘이었고 **둘 다 내 실수다.**

1. **Xcode 의 문자열 자동 추출** — SwiftUI `Text("리터럴")` 은 `LocalizedStringKey` 를 받는다.
   카탈로그가 프로젝트에 있으면 빌드마다 화면의 한글 리터럴이 키로 밀려 들어온다(200개 넘게 들어왔다).
   → `project.yml` 에 `SWIFT_EMIT_LOC_STRINGS: NO`.
2. **형식 불일치** — 카탈로그를 파이썬 스크립트로 썼는데 파이썬 `json.dump` 기본 구분자는 `": "` 이고
   Xcode 는 `" : "` 다. Xcode 가 파일을 만질 때마다 자기 형식으로 전체를 다시 써서, 내용이 하나도
   안 바뀌었는데 파일 전체가 diff 로 잡혔다.
   → `canonical_json()` 으로 Xcode 형식(Foundation `.prettyPrinted | .sortedKeys`, 끝 개행 없음)을
   못박고, 어긋나면 CI 가 떨어뜨린다. `--format` 으로 다시 쓴다.

⚠️ **한 번 확인이 필요하다** — Xcode 의 직렬화 옵션은 문서로 확인한 게 아니라 출력 형태에서 추론했다.
받아서 빌드하고 카탈로그를 Xcode 에서 열어 본 뒤 `git status` 가 깨끗하면 맞은 것이다. diff 가 나면
그 diff 가 Xcode 의 진짜 형식이니 `canonical_json()` 을 거기 맞춘다.
- **사람만 가능**: 시뮬레이터/실기기에서 4개 언어 전환 시 재시작 없이 바뀌는지, 레이아웃이
  긴 번역(독일어 같은 극단은 없지만 영어가 한국어보다 길다)에 깨지지 않는지.

---

## 진행 중 — 다국어 이후 손질 (2026-08-02~03)

다국어를 끝낸 뒤 실기기·시뮬레이터에서 눈에 걸린 것들을 고쳤다. 전부 `develop` 까지만 올라가 있다.

### ✅ 로딩 공룡 (`RunningDino`)

메타 추출은 원본 사이트를 대신 열어 보는 일이라 몇 초씩 걸린다(어댑터 → 다른 UA 재시도 →
이미지 실재 확인). 스피너만 돌면 멈춘 것처럼 느껴져서 기다리는 시간을 견딜 만하게 만들었다.

- **나오는 곳**: 홈(메타 추출 중), 내 클립(목록 조회 중). 둘 다 **화면 가장자리**를 돈다.
- **안쪽에서 벽을 밟는다.** 바깥에 세우면 상자 밖으로 나가는 만큼이 잘린다. 천장 면에서는
  거꾸로 매달린다. 발이 벽을 향하도록 회전에 180° 를 더하고, 회전이 진행 방향까지 뒤집으므로
  도는 방향도 반시계로 맞춘다 — 셋 중 하나만 빠지면 뒷걸음질이 된다.
- **네 면 중 한 면은 건너뛴다.** 어느 면일지는 로딩마다 새로 뽑는다(`@State`). 건너뛴 면은
  공룡이 사라졌다 반대편에서 나타나는 구간이 된다.
- **코너는 점프로 돈다.** 앞뒤 30pt 를 하나의 도약으로 묶어 각도를 나눠 돌린다. 전에는 90° 가
  즉시 꺾여 순간이동처럼 보였다. 경로의 처음·끝(건너뛴 면 쪽 이음매)에서는 뛰지 않는다.
- **속도와 한 바퀴 시간을 둘 다 건다.** 속도만 고정하면 큰 상자에서 한 바퀴가 10초씩 걸려
  로딩이 끝날 때까지 모서리에서 꿈틀대고, 시간만 고정하면 작은 상자에서 총알이 된다.
  목표 150pt/s 로 시간을 정하되 3~7초로 자른다.
- **프레임은 시간이 아니라 걸은 거리로 넘긴다**(보폭 36pt). 시간 기준이면 빨리 달릴수록
  다리가 헛돌아 미끄러진다.
- **`Canvas` 로 그린다. `GeometryReader` 를 쓰지 않는다.** 후자는 잰 크기를 자식에게 흘려보내는
  측정 도구라 레이아웃이 한 바퀴 돌 여지가 있다. 장식 때문에 화면 레이아웃이 흔들릴 이유가 없다.
- 검증: 상자 4종 × 경로 4종을 6000분할로 훑어 프레임 사이 위치 변화 0.4pt·각도 변화 0.9° 이하,
  발이 항상 벽을 향하고 진행 방향이 면과 나란함을 확인(Swift 를 리눅스에서 빌드할 수 없어
  수식만 파이썬으로 옮겨 확인).

#### 스프라이트 자산 (`scripts/slice-dino.py`)

받은 시트를 그대로 쓸 수 없어 네 단계를 거친다. 원본은 `art/dino.png`(앱 번들에 안 들어감).

1. **"투명 배경" 이 아니었다.** 알파가 전부 255고, 투명을 나타내는 회색 격자가 그림으로
   구워져 있었다(5.4MB). 색만 보고 지우면 눈동자 흰자까지 뚫리므로, 가장자리에서 번져 나가며
   바깥과 이어진 회색만 지운다.
2. **원래 해상도로 복원.** 2816×1536 은 47×45 도트를 11.8배로 키운 것(실루엣 경계 주기로 측정,
   우연 대비 3.5배). 칸 평균을 내면 격자 위상이 어긋나 외곽선이 뭉개져서, 칸마다 **최빈색**을 쓴다.
3. 체커보드와 외곽선 사이 압축 잡티가 흰 테두리로 남는다 → 투명과 맞닿은 밝은 회색만 지운다.
4. 프레임 간격이 눈으로만 고르다 → 알파로 실제 자리를 찾아 자르고, 세로는 네 프레임의 공통
   윗변·아랫변을 쓴다(따로 떼면 걸을 때 발바닥 높이가 흔들린다).

5.4MB → 4장 합쳐 13KB. `Contents.json` 은 **Xcode 형식**(`" : "`)으로 쓴다 — 표준 JSON 이면
빌드할 때마다 Xcode 가 고쳐 써서 `git pull` 이 막힌다(문자열 카탈로그에서 겪은 것과 같은 함정).

⚠️ **출처 확인 필요** — 스프라이트 원본의 라이선스를 확인하지 못했다. 스토어 배포 전에 짚을 것.

### ✅ 광고 배너가 화면 스케일을 깨뜨리던 것

증상: 내 클립에 들어가면 화면이 통째로 확대되어 그려지고 좌우가 잘린다. 선택 모드로 들어가면
정상으로 돌아온다(그때 하단 `safeAreaInset` 이 배너 → 일괄 바로 바뀐다).

- `adSize`·`load` 를 `updateUIView` 에서 했다. 이 함수는 부모가 다시 그려질 때마다 불리고
  대부분 레이아웃 도중이다. 콜드 부팅만 `async` 로 피해 뒀는데, **화면 전환으로 배너가 새로
  만들어지는 순간**이 정확히 같은 상황이었다. → `didMoveToWindow` 에서 한 번만, 한 틱 미뤄서.
- 폭과 `rootViewController` 를 앱 전체의 키 윈도우에서 가져왔다. 키 윈도우는 키보드처럼 시스템이
  띄운 창일 수 있다 → 다른 폭 기준으로 받아 온 광고를 이 자리에 늘려 그린다.
  → **배너가 실제로 올라간 창**에서 가져온다.

⚠️ 재현을 확인하지 못했다. 내 클립을 여러 번 드나들어 재발하는지 확인이 필요하다.

### ✅ 목록 조회 실패를 빈 목록과 구분

`getClips` 가 실패해도 `(false, [])` 라 로그아웃 상태의 빈 목록과 구분되지 않았다. 네트워크가
끊기면 DB 에 클립이 있는데도 "아직 저장한 클립이 없어요" 가 뜬다 — 사용자는 클립이 날아간 줄
안다. 웹 `a6a4984` 와 같은 문구·같은 구조로 맞췄다(문구는 웹에 4개 언어가 이미 있었다).

`failed` 를 함께 돌려주고, 실패 화면을 **빈 목록보다 먼저** 본다. 이미 받아 둔 목록이 있으면
실패해도 지우지 않는다.

### ✅ 그 밖

- `ModalOutlinedDangerButton` 배경이 `Color.clear` 라 테두리만 떠 있었다 → 흰 면.
- `@ViewBuilder` 가 애트리뷰트와 선언 사이에 낀 상수에 붙어 빌드가 깨졌다 →
  `check-localizations.py` 에 `check_view_builder_targets` 추가(로컬에서 걸린다).

### 남은 것

- **`README.md`·`plan.md` 갱신** — 이 문단이 그 작업이다.
- **버전**: `MARKETING_VERSION` `1.0.0` → `1.1.0`(다국어 4개 언어 규모). 빌드번호는 fastlane 이 계산.
- **릴리스 노트가 없다**: `fastlane/metadata/{ko,en-US,ja,zh-Hans}/release_notes.txt` 신설 +
  `Fastfile` `upload_to_testflight(changelog:)`. 지금은 TestFlight 테스트 정보가 매번 빈칸이다.
- **`main` 머지 승인** — `main` push 가 곧 TestFlight 자동 배포다.
- 보류: 모달 3종 고정 높이(`EditClipModal` 280 / `TagApplyModal` 340 / `ShareResultModal` 320)가
  긴 번역에서 잘리는지, 내 클립 날짜 그룹 헤더(웹엔 있고 앱엔 없음).

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

## 완료 — 로그인 상태 첫 진입 화면 깜빡임 수정 (2026-07-23)

이미 로그인한 사용자가 처음 진입할 때 홈 액션이 게스트 UI→로그인 UI로 튀던 문제.

- **원인**: `AuthStore.state`가 `loading:true, accessToken:nil`로 시작 → 첫 프레임 `loggedIn=false`. Supabase Keychain 세션 비동기 복원(`authStateChanges`→`apply`) 전까지 `HomeView.actions`가 게스트 UI를 먼저 렌더 → 복원 후 재렌더.
- **수정**: `AuthStore`에 지난 실행 로그인 여부를 `UserDefaults`에 저장, 세션 확정 전(loading)엔 이 힌트로 판단하는 `displayLoggedIn` 추가. `HomeView.actions` 분기를 `displayLoggedIn`으로 교체. 토큰 필요한 동작은 여전히 `accessToken`으로 가드. 유닛 테스트 4개 추가. (PR #107)
- **CI**: `claude/**` 브랜치 push에도 iOS 빌드가 돌도록 `pr-review.yml`에 push 트리거 추가(+concurrency 중복 방지, `if` 가드 push 허용). (PR #107)
- ⚠️ 실제 깜빡임 제거는 실기기/시뮬 시각 확인 권장(빌드/테스트로는 검증 불가).

---

## 완료 — TestFlight 배포 자동 트리거(main push) (2026-07-24)

`deploy.yml`을 수동(`workflow_dispatch`) 전용에서 **main push 자동 배포**로 확장.

- `on.push.branches: [main]` 추가(+`paths-ignore: **/*.md`로 문서만 바뀐 머지는 스킵). 수동 실행 유지.
- `concurrency: deploy-testflight`(cancel-in-progress: false)로 배포 직렬화 — 짧은 간격 머지가 같은 빌드번호(TestFlight 최신+1)를 계산해 업로드 거부되는 충돌 방지.
- 빌드번호는 fastlane이 TestFlight 최신+1로 계산하고 git에 커밋하지 않으므로 배포가 자기 자신을 재트리거하지 않음(무한루프 없음).

---

## 완료 — CI에 유닛 테스트 자동 실행 추가 (2026-07-24)

CI 게이트를 `xcodebuild build`(컴파일만) → `xcodebuild test`로 확장. push(`claude/**`)·PR 모두에서 build+test 실행. (PR #109)

- `pr-review.yml`: `xcodebuild test`. 시뮬레이터는 `xcrun simctl`로 사용 가능한 iPhone UDID 동적 선택(러너 Xcode별 차이에 강건).
- 테스트 추가로 드러난 **선재 이슈 2건 수정**(둘 다 기능 결함 아님):
  - AdMob 빈 App ID → GoogleMobileAds SDK 자동 검증에서 테스트 호스트 앱이 부팅 중 크래시. `Secrets.example.xcconfig`에 구글 공식 테스트 App ID 지정(실배포 무관).
  - `shareTextUsesBuildShareTextForDbClip` 기대값이 옛 동작(설명 포함)에 머물러 실패 → 현재 동작(설명 제외, #74/PR #75)에 맞게 수정. `ClipsStore.shareText` 주석도 정정.
- 검증: 80 tests / 13 suites 그린.

---

## 완료 — 출시 후속 UI 개선 (2026-07-20)

기능 패리티 완성 후 UX 다듬기. 이슈당 브랜치·PR, CI(macOS 빌드) 그린 자동 머지.

- #61 홈 헤더 `ClipNote` 타이틀 제거 — 헤더는 메뉴·내클립(·뒤로가기)만. (PR #65)
- #62 `BrandLogo` 아이콘을 무관한 SF심볼(`link.circle.fill`)에서 앱 아이콘(`BrandIcon` 에셋, icon-512)으로 교체. (PR #66)
- #63 주요 async 작업 로딩 인디케이터 — 공용 `SpinnerLabel`, 홈 공유/저장 버튼·메타 읽는 중 행, 편집/공유결과 모달, 클립 행 공유, 대량 삭제/태그 블로킹 오버레이. (PR #67)
- #64 온보딩을 실제 홈 UI 스포트라이트 투어로 개편(슬라이드 4장 폐기) — `SpotlightTour`(앵커 프리퍼런스·dim+구멍 역마스크·말풍선). (PR #68)
- #69 투어 툴바 단계 제거 + 내 클립 미리보기 목업 — 툴바(메뉴·내클립)는 nav bar 별도 호스팅이라 구멍 좌표 미도달. 메뉴 단계 제거, 내클립은 `ClipsPreviewMock`으로 대체. 투어 = URL·제목/태그·저장·공유(스포트라이트) + 내 클립 미리보기(목업). (PR #70)
- #72 URL 입력 텍스트·커서 색을 검정(`fg`)으로 고정 — 파란 accent라 링크처럼 보이던 문제. (PR #73)
- #74 공유 링크 복사 시 설명 제외, `제목\n링크`만 복사 — 붙여넣기 글이 길어지던 문제. 웹 clipnote c4c4ad9와 동일. (PR #75)
- #76 공유 카드/썸네일에 원본 대표 이미지 표시 + 서버 이미지 프록시 — 웹 정책(5cc38dd·7815b41·bfdc553·c03c97e) 반영. `proxiedImageURL`(`/api/image?url=`)로 hotlink·referer·혼합콘텐츠 회피(네이버 CDN referer는 서버 처리), SharePreviewCard 이미지 배경+스크림 0.55 폴백. (PR #77)

### 남은 일 / 보류
- **투어 시각 검증**(실기기/시뮬) — 사용자 직접.
- **다국어(KO/EN/JA/ZH)**: 보류 해제 — 위 "앱 다국어" 절에서 진행 중.
- **보류**: 내 클립 무한스크롤 — 임계 도달 시 cursor 기반(서버 `?before=&limit=` 필요), 지금은 미착수.

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
