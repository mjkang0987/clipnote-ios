# TestFlight 자동 배포 (맥 없이)

GitHub Actions의 **클라우드 맥 러너**가 빌드·서명·업로드를 대신한다. 로컬 맥이 필요 없다.
한 번만 아래 시크릿을 등록해두면, 이후엔 **버튼 한 번(workflow_dispatch)**으로 TestFlight까지 올라간다.

## 동작 개요
`.github/workflows/deploy.yml` → fastlane(`fastlane/Fastfile`) `beta` 레인:
1. `match`가 Apple Distribution 인증서 + AppStore 프로파일을 **자동 생성/설치**(첫 실행 시 생성).
   서명 파일은 이 저장소의 **`match-storage` 브랜치에 암호화 저장**(별도 저장소 불필요).
2. 빌드번호를 현재 TestFlight 최신 +1 로 올려 아카이브.
3. TestFlight 업로드.

---

## 1회 설정 — GitHub Secrets 등록

`Settings → Secrets and variables → Actions → New repository secret`에서 아래 **5개**를 등록한다.
전부 **브라우저로만** 준비 가능(맥 불필요).

| 시크릿 이름 | 값 | 어디서 |
|---|---|---|
| `ASC_KEY_ID` | App Store Connect API 키 ID | 아래 ② |
| `ASC_ISSUER_ID` | Issuer ID | 아래 ② |
| `ASC_KEY_P8` | `.p8` 키 파일 내용을 **base64 인코딩**한 문자열 | 아래 ② |
| `MATCH_PASSWORD` | 서명 파일 암호화용 **임의 비밀번호**(직접 정함, 분실 금지) | 직접 정함 |
| `SECRETS_XCCONFIG` | `Secrets.xcconfig` **전체 내용** | 아래 ③ |

> `GITHUB_TOKEN`은 워크플로가 자동 제공 → 등록 불필요.

### ② App Store Connect API 키 (맥 불필요, 브라우저)
1. https://appstoreconnect.apple.com → **사용자 및 액세스 → 통합(Integrations) → App Store Connect API**
2. **키 생성(+)** → 이름 아무거나, 액세스 권한 **App Manager** → 생성
3. **Key ID** → `ASC_KEY_ID`, 상단 **Issuer ID** → `ASC_ISSUER_ID`
4. **API 키(.p8) 다운로드**(한 번만 받을 수 있음). 그 파일 내용을 base64로 변환해 `ASC_KEY_P8`에 넣는다.
   - 맥/리눅스: `base64 -i AuthKey_XXXX.p8 | pbcopy`
   - 온라인 base64 인코더에 `.p8` 텍스트를 붙여 변환해도 됨(파일 내용 자체가 민감정보이니 신뢰할 수 있는 곳에서)

### ③ SECRETS_XCCONFIG
로컬 `Secrets.xcconfig` 파일 내용을 그대로 넣는다. 형식(값은 각 대시보드에서 확인 — 전부 웹):
```
API_BASE = https:/$()/clipnote.co.kr
SUPABASE_URL = https://<프로젝트>.supabase.co
SUPABASE_ANON_KEY = <Supabase 대시보드 anon key>
NAVER_CLIENT_ID = <네이버 개발자센터>
ADMOB_APP_ID = ca-app-pub-3019917862455282~9380940221
ADMOB_BANNER_UNIT_ID = ca-app-pub-3019917862455282/6008671423
```

> ⚠️ **이 시크릿은 되읽을 수 없고 전체 덮어쓰기만 된다.** 한 줄만 고치려 해도 6줄을 다
> 손에 들고 있어야 한다. 준비 없이 Update 를 누르면 나머지 5줄을 잃는다.

**AdMob ID 두 개는 비밀값이 아니다.** 앱 ID 는 앱 바이너리의 `Info.plist` 에 그대로 실려
나가고, 퍼블리셔 ID 는 이미 `clipnote.co.kr/app-ads.txt` 로 공개돼 있다. 그래서 여기에
실제 값을 적어 둔다 — 복구할 때 콘솔을 뒤지지 않아도 되게. **나머지 네 줄은 적지 않는다.**

**두 ID 는 생김새가 거의 같다. 구분자 하나만 다르다.**

| | 구분자 | 어디서 | 길이 |
|---|---|---|---|
| `ADMOB_APP_ID` | **`~`** (물결) | AdMob → 앱 → ClipNote → **앱 설정** | 38자 |
| `ADMOB_BANNER_UNIT_ID` | **`/`** (슬래시) | AdMob → **광고 단위** | 38자 |

둘 다 `ca-app-pub-` 로 시작하고 길이도 같아서 화면만 보고는 구분되지 않는다.
**앱 ID 칸에 광고 단위 ID 를 넣으면 앱이 실행 즉시 죽는다** — GoogleMobileAds SDK 가
`GADApplicationIdentifier` 를 스스로 검증하고, 유효하지 않으면
`GADInvalidInitializationException` 으로 앱을 종료시킨다. 실제로 그렇게 배포된 적이 있다
(2026-08-03, `plan.md` "진행 중 — 1.1.0 배포 크래시" 절 참고).

### ④ ADMOB_APP_ID (선택 — 한 줄만 고칠 때)
`SECRETS_XCCONFIG` 는 6줄을 한 덩어리로 담아서, 앱 ID 한 줄을 고치려 해도 전부를 알아야 한다.
`ADMOB_APP_ID` 라는 **별도 시크릿**이 있으면 배포·검증 워크플로가 그 값을 파일 끝에 덧붙여
덮어쓴다(xcconfig 는 뒤에 온 정의가 이긴다). 나머지 5줄을 건드리지 않고 앱 ID 만 고칠 수 있다.

- 값을 **정상화한 뒤에는 이 시크릿을 지우고** `SECRETS_XCCONFIG` 를 정본으로 되돌린다.
  같은 설정의 출처가 둘로 남으면, 나중에 `SECRETS_XCCONFIG` 를 고쳐도 이쪽이 조용히 이긴다.
- 없으면 아무 동작도 하지 않는다(기존 동작 그대로).

### 검증 — 배포 전에 자동으로 막힌다
`Deploy TestFlight` 는 빌드 전에 `scripts/check-secrets.sh` 를 돌린다. 시크릿이 비었거나
형식이 깨졌으면 **빌드 자체가 만들어지지 않는다.** 배포 없이 확인만 하려면
`Actions → Secrets Check → Run workflow`.

값은 절대 로그에 찍지 않는다(공개 저장소) — 존재 여부·형식·길이·구분자 개수만 판정한다.

---

## 배포 실행
1. GitHub → **Actions → Deploy TestFlight → Run workflow** 클릭
2. 클라우드 맥에서 빌드·서명·업로드(수 분 소요)
3. 완료되면 App Store Connect → TestFlight에 새 빌드가 뜬다(처리 후 테스터 배포)

## 주의
- 첫 실행 때 `match`가 **새 Apple Distribution 인증서**를 만든다(계정당 개수 제한 있음 — 부족하면 콘솔에서 오래된 것 정리).
- `MATCH_PASSWORD`를 잃어버리면 `match-storage`의 서명 파일을 복호화 못 한다 → 안전하게 보관.
- 심사 제출(정식 출시)은 이 파이프라인이 아니라 App Store Connect에서 수동으로 진행.

---

## Sign in with Apple 설정 (코드만으로는 안 켜진다)

앱에는 Sign in with Apple 이 들어가 있다(Guideline 4.8 — 소셜 로그인을 쓰면 동등한 프라이버시
로그인을 함께 줘야 한다). **아래 셋은 콘솔에서 사람이 해야 하고, 빠지면 증상이 제각각이다.**

| # | 할 일 | 빠뜨리면 |
|---|---|---|
| 1 | Apple Developer → Identifiers → `kr.co.clipnote.app` → **Sign in with Apple** 체크 | 아카이브가 프로비저닝 오류로 **실패** |
| 2 | 1번 후 **프로비저닝 프로파일 재발급**(`fastlane match` 재실행) | 같음 — 기존 프로파일엔 새 entitlement 가 없다 |
| 3 | Supabase → Authentication → Providers → **Apple** 켜고 **Client IDs 에 번들 ID `kr.co.clipnote.app` 추가** | 애플 시트는 뜨는데 로그인만 실패 |

3번이 특히 헷갈린다. 네이티브 로그인의 id token 은 `aud` 가 Services ID 가 **아니라 번들 ID** 라,
웹용 Services ID 만 등록해 두면 토큰은 정상인데 Supabase 가 거부한다. 화면에는 원인을 알 수 없는
오류만 뜬다.

> **CI 는 이걸 잡지 못한다.** `pr-review.yml` 은 `CODE_SIGNING_ALLOWED=NO` 로 빌드해서
> entitlement 와 프로파일이 맞는지 보지 않는다. CI 가 그린이어도 1·2번은 별도로 확인할 것.

## App Store 심사 제출

### 목록 정보 올리기 (`fastlane metadata`)

부제·설명·키워드·프로모션 문구·URL 3종을 `fastlane/metadata/{ko,en-US,ja,zh-Hans}/` 에서 관리한다.

```bash
ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8=<base64> bundle exec fastlane metadata
```

- **ASC 의 현재 값을 덮어쓴다.** 처음 올리기 전에 `bundle exec fastlane deliver download_metadata`.
- 바이너리·스크린샷·심사 제출은 하지 않는다.
- `name.txt`·`*_category.txt` 는 **일부러 두지 않았다** — 없는 파일은 건드리지 않으므로
  앱 이름과 카테고리는 ASC 값이 유지된다. 바꾸려면 그때 파일을 만든다.

### 사람이 ASC 에서 해야 하는 것

`fastlane metadata` 가 못 채우는 것만 남는다. 위에서부터 순서대로.

1. **스크린샷** — 맥에서 시뮬레이터로 찍는다. 6.9"·6.5" 는 필수.
2. **카테고리·연령등급** — 앱 정보 화면.
3. **App Privacy 설문** — AdMob 을 실은 상태에 맞춰 답한다. `PrivacyInfo.xcprivacy` 는
   광고 도입 전 상태(`NSPrivacyTracking: false`, 추적 도메인 없음)라 설문 답과 어긋나지 않는지 본다.
4. **수출 규정** — 암호화 사용 여부 신고.
5. **빌드 선택 → 심사 제출.**

> **제출 전 실기기에서 앱이 켜지는지 반드시 확인한다.** 1.1.0 이 실행 즉시 죽는 채로
> TestFlight 에 올라간 적이 있다(`plan.md` 크래시 절). 죽는 빌드를 제출하면 리젝이고
> 심사 사이클을 한 번 태운다.
