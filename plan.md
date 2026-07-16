# 작업 계획

> 진행 중인 작업의 배경·범위·구현 항목·리스크를 적는다. 완료되면 비운다.

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

## 예정 — Phase 3: 로컬저장(SwiftData) + HomeView (에픽)

설계 §3.4(LocalClipStore)·§4.1(HomeView). RN `lib/local-clips.ts` + `app/index.tsx` 이식.
비로그인 사용자가 URL 붙여넣기 → 메타 추출 → 미리보기 → 기기 저장(로컬)까지. 로그인 사용자는 공유링크/DB 저장.

> 착수 방식: CLAUDE.md Work Request Flow. 하위 3개↑ → **에픽 이슈 + 서브이슈**. 서브별 브랜치 `claude/issue-N-슬러그` → plan.md 세부 확정 → TDD → 빌드/테스트(`iPhone 17 Pro`) → `/code-review` → PR → CI → 머지. 새 세션은 index.md·plan.md 먼저 읽을 것.

### 서브 분할(의존순)

**#A LocalClipStore (SwiftData) — 순수 로직, TDD**
- `@Model LocalClip { url, title, description?, image?, siteName?, gradient, tags:[String], savedAt: Date }`.
- 규칙: 같은 `url`은 최신으로 upsert(중복 제거) · 최대 **300개**(초과 시 오래된 것 제거) · 최신순 정렬.
- `save(_:)`, `all()`, `delete(url:)`, `clearLocalClips()`(로그인 마이그레이션 후 비움).
- 알려진 태그 빈도 `knownTags`(자동완성용, 빈도 내림차순). SwiftData 또는 UserDefaults JSON.
- 검증: in-memory `ModelContainer`로 upsert·300캡·정렬·태그빈도 유닛테스트.
- 영향: 신규 `ClipNote/Local/LocalClipStore.swift`, `ClipNote/Local/LocalClip.swift`, 테스트. project.yml에 SwiftData 링크(기본 제공).

**#B UClip 통합 매핑 + 저장 흐름 로직 — 순수, TDD**
- `LocalClip`→`UClip`, `DbClip`→`UClip` 매핑(id 규칙: 로컬=url, DB=slug). Phase 1 `UClip` 재사용.
- 태그 파싱(쉼표 구분, 최대 6개, 트림·빈값 제거) 순수 함수 + 테스트.
- 영향: `ClipNote/Models` 확장 또는 `ClipNote/Local`, 테스트.

**#C HomeView — URL 디바운스 메타 추출 + 폼 (UI + 추출 로직)**
- URL 입력 → **600ms 디바운스** 후 유효 URL이면 `APIClient.fetchMetadata` 자동 호출(`Task`+`Task.sleep`, URL 바뀌면 이전 취소). 디바운스/유효성 로직은 분리해 테스트.
- 제목(미입력 시 메타 title 자동 채움), 태그 입력(#B 파서).
- 비로그인: **"이 기기에 저장"**(LocalClipStore) / 로그인: **"공유 링크 만들기"**(→ShareResult, Phase 4)·**"내 클립에 저장"**(`createClip(save:true)`).
- 영향: 신규 `ClipNote/Views/HomeView.swift`, 뷰모델(`@Observable`), 루트를 HomeView로(로그인 상태 무관 진입). 수동/프리뷰 검증.

**#D 미리보기 카드 — SwiftUI 컴포넌트**
- 공유 카드: `LinearGradient`로 OG 카드 재현(비율 1200:630, siteName·title·description·"ClipNote", `pickGradient` 동일 색).
- 클립 카드: 썸네일(원본 image or 그라디언트) + 제목·호스트·태그.
- 영향: 신규 `ClipNote/Views/SharePreviewCard.swift`·`ClipCardView.swift`. 프리뷰/수동 검증.

**#E 온보딩 게이트(플래그만) — 작은 작업**
- `@AppStorage("clipnote.onboardingSeen")`. 최초 실행 시 온보딩 라우팅 훅(온보딩 화면 자체는 Phase 5). 플래그 확인 전 렌더 보류.
- 영향: `ClipNoteApp`/루트. (범위 최소 — 화면 UI는 이월.)

### 범위 밖(후속)
- ClipsView·편집·다중선택·공유복사(§4.2/4.3) = Phase 4.
- 로그인 마이그레이션(`MigrateLocalClips`, §5) = Phase 4와 함께 or 별도.
- Onboarding/About/FAQ/AccountDelete 화면·AdMob = Phase 5.

### 리스크
- SwiftData `@Model` + Swift 6 동시성(`@MainActor` ModelContext). 테스트는 in-memory 컨테이너.
- 디바운스 취소 타이밍 — URL 빠르게 바뀔 때 이전 Task 확실히 취소.
- HomeView는 유닛테스트 한계 → 추출/파싱 로직 분리 테스트 + UI는 수동/프리뷰.
