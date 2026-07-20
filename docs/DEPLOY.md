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
ADMOB_APP_ID = <AdMob 콘솔 App ID>
ADMOB_BANNER_UNIT_ID = <AdMob 콘솔 배너 unit ID>
```

---

## 배포 실행
1. GitHub → **Actions → Deploy TestFlight → Run workflow** 클릭
2. 클라우드 맥에서 빌드·서명·업로드(수 분 소요)
3. 완료되면 App Store Connect → TestFlight에 새 빌드가 뜬다(처리 후 테스터 배포)

## 주의
- 첫 실행 때 `match`가 **새 Apple Distribution 인증서**를 만든다(계정당 개수 제한 있음 — 부족하면 콘솔에서 오래된 것 정리).
- `MATCH_PASSWORD`를 잃어버리면 `match-storage`의 서명 파일을 복호화 못 한다 → 안전하게 보관.
- 심사 제출(정식 출시)은 이 파이프라인이 아니라 App Store Connect에서 수동으로 진행.
