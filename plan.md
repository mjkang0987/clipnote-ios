# 작업 계획

> 진행 중인 작업의 배경·범위·구현 항목·리스크를 적는다. 완료되면 비운다.

---

## 완료 — 업무 처리 시스템 도입

- `CLAUDE.md`(업무 절차·iOS/Swift 표준), `.github/workflows/pr-review.yml`(macOS 빌드 CI), `REVIEW.md`(리뷰 기준), `index.md`/`plan.md` 스타터 추가.
- 이후 작업은 Work Request Flow(이슈→브랜치→검증→리뷰→PR→자동머지)를 따른다.

---

## 진행 중 — Phase 2 인증 (에픽 #4)

RN `lib/auth.tsx`·`login.tsx`·`lib/naver.ts` → Swift `AuthStore`(Supabase 래핑). 설계 스펙 §3.3/§3.7.

서브이슈: #5 Supabase+AuthStore 코어 → #6 딥링크 라우팅 → #7 Google/Kakao → #8 네이버.

### #6 딥링크 라우팅 (현재)

**요구사항**
- `.onOpenURL`로 `clipnote://auth/callback?code=...`(OAuth)·`clipnote://auth/naver?token_hash=...`(네이버) 라우팅.
- URL→라우트 파싱 순수 로직 유닛테스트. token_hash 1회용 가드.

**구현**
- `AuthDeepLink` enum + `parse(_:)` — scheme/host/path/query 검증(순수).
- `AuthStore.handle(url:)` — 파싱 후 `session(from:)`(OAuth)·`verifyOTP(tokenHash:type:.magiclink)`(네이버) 디스패치. 세션은 authStateChanges로 자동 반영.
- `markTokenHashConsumed(_:)` — Set.insert.inserted 기반 1회용 가드(분리·테스트).
- `ClipNoteApp`에 `@StateObject AuthStore` 주입 + `.onOpenURL`. 설정 없을 때 `AuthStore.disabled()` 폴백.

**영향 파일**
- 신규: `ClipNote/Auth/AuthDeepLink.swift`, `ClipNoteTests/AuthDeepLinkTests.swift`
- 수정: `ClipNote/Auth/AuthStore.swift`, `ClipNote/App/ClipNoteApp.swift`, `ClipNoteTests/AuthStoreTests.swift`

**기대 결과**
- 빌드 그린 + 파서 8케이스·가드 1케이스 테스트 통과. 실제 교환/verify는 #7/#8 수동 검증.

### #5 Supabase SPM 통합 + AuthStore 코어 (완료)

**요구사항**
- `supabase-swift` SPM 의존성 추가, 빌드 통과.
- `AuthStore`(@MainActor, ObservableObject): 세션·토큰·로그인상태 관찰, `onAuthStateChange` 구독, `signOut()`.
- 세션은 supabase-swift 기본 Keychain 저장·자동 갱신.

**구현 방식**
- `project.yml` `packages:`에 Supabase 추가, `ClipNote` 타깃 `dependencies`에 `package: Supabase / product: Supabase`.
- `SUPABASE_URL`/`SUPABASE_ANON_KEY`를 `Secrets.xcconfig`→`info.properties`로 주입(API_BASE 패턴 동일).
- `Config` 헬퍼: Info.plist에서 값 읽기(APIClient의 Bundle 읽기 패턴 통일).
- `AuthStore`: `SupabaseClient` 보관, `@Published session/loading`, 파생 `accessToken`/`loggedIn`. init에서 `authStateChanges` async 시퀀스 구독 Task.

**영향 파일**
- 수정: `project.yml`, `ClipNote/Info.plist`(생성물), `Secrets.example.xcconfig`(키 문서화)
- 신규: `ClipNote/Auth/AuthStore.swift`, `ClipNote/Util/Config.swift`, `ClipNoteTests/AuthStoreTests.swift`

**기대 결과**
- `xcodebuild build` 그린(supabase-swift 링크).
- AuthStore 상태 파생 로직(세션 유무→loggedIn/accessToken) 유닛테스트 통과.
- OAuth 실제 플로우는 #7/#8로 이월(이 서브에선 코어·상태만).

**리스크**
- supabase-swift Swift 6 동시성 호환: 최신 2.x 사용으로 대응. 실패 시 버전 핀 조정.
- SPM 첫 해석은 네트워크 필요(CI 러너 포함).
