# 작업 계획

> 진행 중인 작업의 배경·범위·구현 항목·리스크를 적는다. 완료되면 비운다.

---

## 🚨 실제 리젝 사유 — 연령 등급에 광고 미표시 (2.3.6)

**코드 문제가 아니다. ASC 에서 클릭 한 번으로 끝난다.**

받은 두 통은 **같은 건 하나**다.

- 자동 분석: "app may include advertising but you did not select **Yes** for the
  **Advertising** content descriptor on the Age Rating selection".
- `2.3.6 Performance: Accurate Metadata` — 2.3.6 이 곧 **연령 등급 조항**이다
  ("Answer the age rating questions honestly so that your app aligns properly with
  parental controls").

앱에 AdMob 배너가 실려 있는데(`Ads/AdBannerView.swift`, 홈·내 클립 하단) 연령 등급 설문에서
광고를 "예" 로 고르지 않았다. 심사가 시작조차 되지 않은 **자동 반려**다.

### 고치는 법 (사람이 ASC 에서, 저장소 작업 없음)

1. App Store Connect → 앱 → **앱 정보** → **연령 등급** → 편집.
2. **광고(Advertising)** 항목을 **"예"** 로.
3. 저장 → App Review 페이지에서 회신하거나 재제출.

> 애플 메일에도 적혀 있다 — 메타데이터만 고치는 경우 **재제출 없이 회신으로 끝난다.**

### ❌ 내가 틀린 것

거절 메일에 사유가 없어(정형 템플릿) **Guideline 4.8(Sign in with Apple)로 추정하고 먼저
구현했다. 추정이 틀렸다.** 실제 사유는 연령 등급이고 애플 로그인과 무관하다.

사유를 확인하지 않은 채 큰 기능을 만든 것이 잘못이다. 그 작업은 아래 절로 분리해 남긴다 —
**이번 리젝과는 무관하며, 지금 내보낼 이유가 없다.**

---

## 보류 — Sign in with Apple (이번 리젝과 무관, 별건)

> **이번 심사 반려와 관계없다.** 위 추정 착오로 먼저 만들어진 작업이라 브랜치에만 올려 두고
> 판단을 기다린다. 내보낼지 접을지는 지시자가 정한다.

### 그래도 언젠가 필요한 이유

Guideline 4.8 은 서드파티/소셜 로그인으로 계정을 만들면 **동등한 프라이버시 로그인**을
함께 제공하라고 요구한다(수집을 이름·이메일로 제한, 이메일 숨기기 지원). 현재 로그인 수단은
Google·Kakao·Naver 셋뿐이라 이 조건을 만족하지 못한다. 다만 **이번에 그것으로 반려된 것은
아니다** — 시급하지 않다.

### 왜 웹 OAuth 가 아니라 네이티브인가

Supabase 의 `signInWithOAuth(provider: .apple)` 로도 로그인은 된다(Google·Kakao 와 같은 경로).
그런데 **그 길로 가면 4.8 을 만족하지 못할 수 있다.** 애플 로그인을 웹뷰로 띄우면 사용자는
시스템 시트(Face ID · 이메일 숨기기)를 보지 못하고, "이메일 가리기"가 빠지면 4.8 이 요구하는
동등성 자체가 성립하지 않는다. 리젝을 고치러 갔다가 같은 조항에 다시 걸릴 이유가 없다.

그래서 `ASAuthorizationAppleIDCredential` 로 identity token 을 받아
`auth.signInWithIdToken(credentials: .init(provider: .apple, idToken:, nonce:))` 로 넘긴다.
API 는 SPM 이 실제로 물어 올 **v2.54.1** 소스에서 확인했다(`from: "2.51.0"` → 최신 2.x).

### nonce 를 두 벌 쓰는 이유

애플에는 **해시**를 주고 Supabase 에는 **원본**을 준다. 애플은 `request.nonce` 로 받은 값을
그대로 id token 의 `nonce` 클레임에 박아 넣는데, 원본을 그대로 주면 그 값이 토큰에 평문으로
남는다. 그래서 관례대로 SHA-256 을 넘기고, 검증하는 쪽(Supabase)에는 원본을 줘서 해시를
맞춰 보게 한다. **둘을 바꿔 넣으면 로그인이 조용히 실패한다** — 토큰은 받아지는데 서버 검증만
떨어져서, 화면에는 원인을 알 수 없는 오류만 뜬다.

### 버튼은 시스템 것을 쓴다 (`SignInWithAppleButton`)

애플 로고·모서리·문구는 브랜딩 규정이 있어 직접 그리면 그 자체가 지적 사유가 된다.
기존 `brandButton` 을 재사용하지 않는 유일한 예외다.

- **대신 갈리는 점이 하나 있다** — 이 버튼은 **기기 언어**로 문구를 만든다. 앱 안에서 언어를
  영어로 바꿔도 기기가 한국어면 버튼만 "Apple로 계속하기" 로 남는다. 시스템이 그리는 버튼이라
  `LocalizationStore` 가 닿지 않는다. 규정 준수와 문구 일관성 중 **규정을 택했다.**
- 순서는 **맨 위**. 4.8 은 동등한 노출을 요구하고, 아래로 밀면 그 자체가 지적거리다.
- 동의 체크박스 게이트는 다른 버튼과 똑같이 건다. 그런데 `SignInWithAppleButton` 은 탭을
  가로챌 자리가 없어(`onRequest` 는 이미 요청이 시작된 뒤다) **투명 버튼을 위에 덮어** 막는다.

### 함께 고치는 것 — 로그인 취소 후 버튼이 잠기던 것

`LoginView.start()` 는 `loadingProvider` 를 세워 두고 `auth.lastError` 가 **바뀔 때만** 내린다.
그런데 취소는 에러가 아니라서(`isUserCancellation`) `lastError` 가 `nil` 그대로다 —
`nil` → `nil` 은 변화가 아니므로 `onChange` 가 안 뜬다. 즉 **구글 로그인을 한 번 취소하면
로그인 버튼 전체가 비활성으로 굳는다.** 화면을 다시 만들기 전엔 안 풀린다.

범위 밖으로 미룰까 했는데 미루지 않는다. 심사자가 로그인을 취소해 보는 건 정상 동선이고,
그 상태는 "앱이 반응하지 않는다"(2.1)로 읽힌다. 리젝을 고치러 가면서 리젝거리를 남길 이유가 없다.
고치는 방법은 `await` 뒤에서 직접 내리는 것 — 신호를 기다리지 않으면 놓칠 일도 없다.

### 범위

- **포함**: entitlement, `AuthStore` 의 애플 경로(nonce·id token·취소 판정·공급자 표기),
  `LoginView` 버튼, 오류 문구 1개(4개 언어), 취소 잠김 수정, 테스트, 수동 설정 절차 문서화.
- **제외**: ATT/UMP(별건, `plan.md` 위 절 참고), App Privacy 설문 응답(ASC 에서 사람이),
  스크린샷·메타데이터.

### 사람이 해야 하는 것 (이걸 안 하면 코드가 있어도 로그인이 안 된다)

코드만으로 끝나지 않는다. 셋 다 사람이 콘솔에서 해야 하고, **빠지면 증상이 제각각이다.**

1. **Apple Developer → Identifiers → `kr.co.clipnote.app` → Sign in with Apple 활성화.**
   빠지면 아카이브가 프로비저닝 오류로 **실패**한다(entitlement 가 프로파일에 없다).
2. **프로비저닝 프로파일 재발급** — 서명이 `Manual`(`match AppStore kr.co.clipnote.app`)이라
   기존 프로파일에는 새 entitlement 가 없다. 1번 후 `fastlane match` 재실행이 필요하다.
   CI 는 `CODE_SIGNING_ALLOWED=NO` 라 **이 문제를 잡지 못한다** — 그린이어도 안심할 수 없다.
3. **Supabase → Authentication → Providers → Apple 활성화**, 그리고 **Client IDs 에
   번들 ID `kr.co.clipnote.app` 을 추가.** 네이티브 흐름의 id token 은 `aud` 가 Services ID 가
   아니라 **번들 ID** 라, 이게 빠지면 토큰은 받아지는데 Supabase 가 거부한다.

절차는 `docs/DEPLOY.md` 에 적는다.

### 🚨 재제출 전 반드시 — 5.1.1(v) 애플 토큰 폐기 (서버 작업, **이 저장소 밖**)

**애플 로그인을 넣는 순간 새 의무가 생긴다.** 5.1.1(v) 는 Sign in with Apple 을 제공하는 앱이
계정 삭제 시 **애플 REST API 로 토큰을 폐기**하도록 요구한다. 안 하면 사용자가 앱에서 탈퇴해도
설정 > Apple ID > "Apple로 로그인" 목록에 ClipNote 가 남는다. **4.8 을 고치고 5.1.1(v) 로
다시 리젝된다** — 심사 사이클을 한 번 더 태우는, 이번 작업에서 가장 큰 위험이다.

코드리뷰에서 잡혔고, **이 저장소만으로는 끝낼 수 없다.**

- 지금 `DELETE /api/account` 는 Bearer 토큰만 보낸다(`APIClient.swift:109`). 본문이 없다.
- 폐기하려면 서버(`clipnote`)가 애플 `/auth/revoke` 를 불러야 하고, 그러려면 애플 개인키로
  서명한 client_secret JWT 가 필요하다. **키도 서명도 서버 쪽 일이다.**
- 클라이언트가 댈 것은 로그인 때 받는 `authorizationCode` 하나뿐이다. 다만 삭제는 며칠 뒤일 수
  있어 Keychain 에 들고 있다가 삭제 요청에 실어 보내야 한다.

**지금 클라이언트에 미리 넣지 않았다.** 서버가 받지 않는 필드를 실어 보내는 코드는 죽은 코드고,
죽은 채로 머지되면 "했다" 로 기억된다. 서버 엔드포인트가 정해지면 그때 한 벌로 넣는다.

순서: ① 서버에 폐기 배선(`clipnote` 저장소) → ② 앱에서 `authorizationCode` 보관·전송 →
③ 실기기에서 탈퇴 후 설정 목록에서 사라지는지 확인 → ④ 재제출.

### 안 한 것 (의도)

- **네이버 nonce 를 `randomNonce` 로 통일하지 않았다.** 리뷰 지적대로 지금 두 벌
  (`UUID` 앞 10자 vs 32자)이 한 파일에 있다. 그런데 네이버 `state` 는 서버와 오가는 값이고
  여기서는 **빌드도 실행도 못 한다.** 재제출 직전에, CSRF 용으로 충분한 값을, 검증 못 하는
  채로 건드릴 이유가 없다. 별건으로 남긴다.

### 검증

- 로컬 빌드 불가(리눅스·Xcode 없음) → 브랜치 push 로 `pr-review.yml`(`xcodebuild test`) 그린까지.
- `scripts/check-localizations.py` — 키 1개 추가분 4개 언어·정규 형식.
- `/code-review` 1회 — 8건 중 6건 반영(아래), 1건은 서버 의존(위), 1건은 의도적 보류(위).
  - 네이버 시트를 쓸어내려 닫으면 로그인 버튼 넷이 굳던 것 → `onDismiss` 로 잠금 해제.
    **`start()` 만 고치고 끝낸 줄 알았는데 같은 버그가 한 함수 아래 살아 있었다.**
  - `onChange(of: lastError)` 가 애플 토큰 교환 도중 잠금을 풀던 것 → 그 줄을 없앴다
    (이제 세 경로가 각자 직접 푼다).
  - 동의 게이트가 VoiceOver 로 우회되던 것 → `accessibilityHidden` + 오버레이에 레이블.
  - '최근 로그인' 배지를 애플 버튼 위에 얹던 것 → **뗐다.** 애플은 버튼을 가리는 것을 금지한다.
  - `clipShape` 로는 시스템 버튼의 모서리가 안 깎여 혼자 각져 보이던 것 → `cornerRadius`.
  - 이름과 달리 `.appleTokenMissing` 을 덮지 못하던 테스트 → 이름·주석을 실제 범위로 고쳤다.
- **사람만 가능**: 실기기에서 실제 애플 로그인(이메일 숨기기 포함), 위 3단계 설정 후 동작.

---

## 진행 중 — App Store 제출 준비 (2026-08-04)

> **범위는 제출 버튼 직전까지.** 심사 제출은 실기기에서 앱이 켜지는 것을 확인한 뒤 사람이 누른다.

### 배경

1.1.0 은 TestFlight 까지 갔고 크래시 대응 빌드가 올라가 있다. 그런데 **심사 제출에 필요한 스토어
목록 정보가 저장소에 없다** — fastlane 에는 `beta`(TestFlight) 레인만 있고 `fastlane/metadata/` 에는
릴리스 노트뿐이다. 지금 상태로는 ASC 웹에서 손으로 4개 언어를 채워야 하고, 다음 릴리스에 또 반복된다.

### 범위

- **포함**: 스토어 메타데이터 4개 언어(부제·설명·키워드·프로모션 문구·URL 3종·저작권),
  메타데이터 업로드 레인, ASC 제출 체크리스트.
- **제외**: 심사 제출, 스크린샷 촬영(맥 필요), 앱 이름·카테고리, UMP/ATT.

### 왜 UMP·ATT 를 빼나

UMP 부재는 **애플 심사 블로커가 아니다.** 구글 정책이라 EEA/영국 사용자에게 광고가 게재되지 않는
문제이지 리젝 사유가 아니다. ATT 는 개인화 광고(IDFA)를 쓸 때만 필요한데 지금은 쓰지 않는다.
둘 다 별건으로 미룬다.

다만 ASC 의 **App Privacy 설문**은 AdMob 을 실은 상태에 맞춰 답해야 한다 — 체크리스트에 넣는다.
`PrivacyInfo.xcprivacy` 는 광고 도입 전 상태(`NSPrivacyTracking: false`, 추적 도메인 비어 있음)라
설문 답과 어긋나지 않는지 제출 전에 한 번 본다.

### 구현

- `fastlane/metadata/{ko,en-US,ja,zh-Hans}/` — `subtitle`·`description`·`keywords`·
  `promotional_text`·`support_url`·`marketing_url`·`privacy_url`.
  `release_notes.txt` 는 이미 있고 건드리지 않는다.
- `fastlane/metadata/copyright.txt`
- `Fastfile` 에 `metadata` 레인. **`Deliverfile` 은 두지 않았다** — 옵션이 레인과 파일 두 곳에
  흩어지면 어느 쪽이 이기는지 매번 확인해야 한다.
- ASC 제출 체크리스트는 `docs/APPSTORE.md` 를 새로 만들지 않고 **`docs/DEPLOY.md` 에 붙였다.**
  배포 문서가 이미 있는데 제출만 따로 두면 둘 다 절반씩 읽게 된다.

### 일부러 넣지 않는 파일

`deliver` 는 **존재하는 파일만** 반영하고 없는 항목은 ASC 의 현재 값을 그대로 둔다. 이 성질을 이용해
건드리면 안 되는 것을 아예 파일로 만들지 않는다.

- `name.txt` — 등록된 앱 이름(`ClipNote by pikaworks`)을 덮어쓴다. 이름 변경은 심사 대상이라
  의도 없이 바꾸면 안 된다.
- `primary_category.txt`·`secondary_category.txt` — 이미 설정돼 있는데 현재 값을 확인하지 못했다.
  잘못 덮으면 조용히 바뀐다.

### 리스크

- **`deliver` 는 ASC 를 덮어쓴다.** 시크릿과 같은 종류의 위험이다 — 레인을 CI 에 걸지 않고 사람이
  부른다. `skip_binary_upload: true`·`submit_for_review: false` 로 두어 바이너리 업로드와 심사
  제출은 하지 않는다. 처음 올리기 전에 `deliver download_metadata` 로 현재 값을 받아 둔다.
- **문구는 초안이다.** 스토어에 나가는 글이라 사용자 확인을 받고 올린다.

### 검증

CI 그린(PR #116). 앱 코드 변경이 없어 빌드 영향 없음. 문구는 `humanize-korean` 으로 AI 티를
걸렀다(C-11 연결어미 뒤 쉼표 2건·A-10 `~할 수 있다` 1건 수정, 변경률 1.8%).

### 저장소 쪽은 끝났다 (2026-08-04, `795612b`)

남은 것은 전부 ASC 에서 사람이 하는 일이다.

- 스크린샷(맥에서 촬영, 6.9"·6.5" 필수), 카테고리·연령등급, App Privacy 설문, 수출규정 신고, 심사 제출.
- `fastlane metadata` 로 목록 정보를 올릴 때 **처음 한 번은 `deliver download_metadata` 로 현재
  ASC 값을 먼저 받아 둔다.** 덮어쓰기라 되돌리려면 이전 값이 필요하다.

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

- ~~**왜 거절에 삭제 확인이 붙나**~~ — **2026-08-03 에 없앴다.** 근거는 "로그인 목록에서 볼
  방법이 없어 남겨 둘 자리가 없다" 였는데, 그러면 거절이 곧 삭제를 뜻해 선택지가 아니게 된다.
  자리를 만들어 해결했다 — `LocalClipsView`(‘이 기기에 남은 클립’) + 목록 위 진입 줄.
  이제 거절은 그냥 닫히고, 삭제는 사용자가 그 화면에서 직접 부를 때만 확인을 띄운다.
  웹도 같이 고쳤다(`LocalClipsPanel`).
- **확인 계열은 액션 시트가 아니라 레이어다.** 웹이 네이티브 `confirm()` 을 걷어내고 레이어로
  바꿔 놨다(`c6c1d54` 이후 `/clips` 확인 6개가 전부 `ModalShell`). 앱도 맞춘다 —
  `ConfirmLayer` 신설, 옮기기·삭제 확인·단건 삭제·일괄 삭제 4개를 옮겼다.
  - 모양 때문만이 아니라 **동작 때문이다.** `confirmationDialog` 는 바깥을 눌러 닫은 것과
    취소를 누른 것을 구분하지 못한다. 옮기기 흐름은 그 둘이 달라야 한다(닫기=보류,
    취소=옮기지 않겠다는 의사 → 삭제 확인). 버튼을 직접 그려야 구분이 선다.
  - 두 갈래: `옮기기`(진행 중 레이어 유지·스와이프 잠금) / `취소`·스와이프(그냥 닫기).
  - `ConfirmLayer` 는 내용 높이를 재서 detent 로 쓴다. 고정 높이면 번역문이 긴 언어에서 잘린다.
  - 고정 높이 3곳(`EditClipModal`·`TagApplyModal`·`ShareResultModal`)도 `sheetHeightFitsContent()`
    로 옮겼다(2026-08-03) — 높이 계산이 한 곳에만 있다.

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
- **아래쪽 면은 걷지 않는다.** 광고 배너·홈 인디케이터와 겹치는 자리다. 오른쪽 → 위 → 왼쪽
  세 면만 돌고, 빠진 아래쪽은 사라졌다 반대편에서 나타나는 구간이 된다. 면을 빼는 것만으로는
  부족했다 — 양옆 벽이 바닥까지 내려와 바닥 모서리에서 나타나고 사라졌다. 도는 사각형을
  배너 높이만큼 올렸다.
- **출발점은 로딩마다 다르다.** 면을 고정하니 늘 같은 자리에서 나왔다. 진행도에 0~1 오프셋만
  더한다 — 경로·속도·도약은 그대로다.
- **도트 스프라이트 4프레임**(47×45, `Assets.xcassets/DinoRun{1..4}`). 원본 시트는 `art/dino.png`
  이고 `scripts/slice-dino.py` 가 배경 제거·해상도 복원·잔상 제거·프레임 분할을 한다(5.4MB → 13KB).
  **출처**: 사용자가 Gemini 로 생성 — 라이선스 문제 없음.
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

### ✅ 자잘한 수정

- `ModalOutlinedDangerButton` 배경이 `Color.clear` 라 테두리만 떠 있었다 → 흰 면.
- `@ViewBuilder` 가 애트리뷰트와 선언 사이에 낀 상수에 붙어 빌드가 깨졌다 →
  `check-localizations.py` 에 `check_view_builder_targets` 추가(로컬에서 걸린다).

### ✅ 그 밖에 함께 한 것

- **런치 스크린** — 비어 있어 켤 때 흰 화면만 떴다. 흰 배경 + 로고(120pt, `LaunchLogo`).
  배경을 흰색 자산으로 못박은 건 생략 시 다크 모드 기기에서 검게 떴다가 흰 앱으로 바뀌기
  때문이다. iOS 가 앱 코드 없이 그리는 정지 화면이라 애니메이션은 못 넣는다.
- **표시 버전이 반영되지 않던 것** — `MARKETING_VERSION` 만 올리면 화면에 안 나온다. XcodeGen 이
  `Info.plist` 에 기본값 `1.0` 을 리터럴로 써넣어 빌드 세팅이 덮이지 않는다(fastlane 이
  `CFBundleVersion` 에서 겪고 플리스트를 직접 쓰는 것으로 우회한 것과 같은 문제). **출시된
  1.0.0 은 스토어에 1.0 으로 올라가 있다.** 두 타깃 `info.properties` 에
  `CFBundleShortVersionString` 을 명시해 실제로 반영되게 했다 — 앞으로 두 값을 함께 올린다.
- **버전 1.1.0 + 릴리스 노트 4개 언어**(`fastlane/metadata/{ko,en-US,ja,zh-Hans}/release_notes.txt`).
  TestFlight 테스트 정보는 언어별이 아니라 하나만 받으므로 한국어 노트를 쓰고, 같은 파일을
  App Store 제출이 그대로 읽는다.
- **내 클립 날짜 그룹 머리글**(웹 `groupByDate` 이식). 통합 모델이 저장 시각을 버리고 있어
  `UClip.savedAt` 부터 만들었다. 라벨은 카탈로그에 넣지 않는다 — `2026년 7월` 은 형식 자체가
  언어마다 달라 사전으로 표현할 수 없다(웹이 `Intl` 에 맡긴 것과 같은 판단).
- **로그아웃 확인 레이어** — 헤더 메뉴·설정 둘 다 누르는 즉시 로그아웃됐다. 상태는 `AppRouter`,
  레이어는 `RootView` 한 곳.
- **로컬 클립 삭제 레이어 버튼 색** — 이 화면만 취소가 채운 버튼이고 삭제가 테두리였다.
  다른 레이어와 같게 맞추고 `emphasis.cautious` 를 없앴다.

### ✅ 공유 확장 — 닫는 길 3종 + 앱 열기 제거

- 바깥 탭 / 아래로 쓸어내리기 / `닫기` 버튼. 바깥 탭은 root view 에 제스처만 붙여선 안 먹어
  **실제 뷰를 깔았다**(확장은 시스템 컨테이너 안에서 돌아 문서대로만 굴러가지 않는다).
  backdrop 색을 빼자 탭이 다시 안 먹어 되돌렸다 — 추론보다 실제 동작을 따랐다.
- **`앱 열기` 버튼을 없앴다.** `NSExtensionContext.open(_:)` 은 문서상 Today 위젯용이고
  responder chain 우회도 최근 iOS 에서 막혔다 — 실제로 시도했고 둘 다 실패했다. 공유 시트에서
  앱이 바로 열리는 사례는 대개 **보내는 쪽 앱**이 스킴으로 열거나 파일을 넘겨
  `LSItemContentTypes` 경로로 여는 것이라, URL 을 받는 확장이 따라 할 수 있는 길이 아니다.
  안내를 "앱을 열면 입력칸에 채워져 있다" 로 바꿨다.

### ✅ 웹에도 공룡 이식 (`clipnote`)

같은 스프라이트·같은 움직임. 앱과 갈라진 점 둘 — 웹은 **네 면을 모두 걷고**(가릴 배너가 없다),
**한 바퀴 상한이 24초**다(창이 커서 7초를 맞추면 463px/s 까지 올라간다). 위쪽만 헤더 높이
(56px)만큼 내려 시작한다. 웹 `main` 까지 머지·배포 완료.

### ✅ 시트 높이를 내용에 맞춘다

`presentationDetents` 는 숫자를 요구하는데 모달 3종이 그 숫자를 박아 뒀다
(`EditClipModal` 280 / `TagApplyModal` 340 / `ShareResultModal` 320). 영어·일본어가 한국어보다
길어 한국어 기준으로 잡은 값이 모자라면 아래가 잘린다.

눈으로 확인해 숫자를 늘리는 대신 **재서 넘긴다**. `ConfirmLayer` 가 쓰던 방식을
`sheetHeightFitsContent()` 로 뽑아 네 곳이 함께 쓴다 — 같은 4줄과 `fixedSize` 함정(없으면
초기 detent 에 갇혀 영영 커지지 않는다)이 복사되는 걸 막는다.

### 남은 것
- **`main` 머지 승인** — `main` push 가 곧 TestFlight 자동 배포다. 버전·릴리스 노트는 준비됐다.
- AdMob → 앱 → **app-ads.txt 업데이트 확인** 클릭(웹 배포로 파일이 공개됐다), Search Console
  사이트맵 재제출.

### 실기기·시뮬레이터 확인 결과 (2026-08-03)

- ✅ 실기기 **광고 노출 확인**.
- ✅ 내 클립 화면이 확대되어 그려지던 문제 — 배너 수정 후 **재현되지 않음**. 다시 나오면 그때
  `AdBannerView` 부터 본다.
- ⬜ 모달 3종이 긴 번역에서 잘리는지는 아직 눈으로 확인하지 않았다.

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
