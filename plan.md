# 작업 계획

> 진행 중인 작업의 배경·범위·구현 항목·리스크를 적는다. 완료되면 비운다.

---

## 예정 — Phase 4: ClipsView + 편집/공유/다중선택 + 로그인 마이그레이션 (에픽)

설계 §4.2·§4.3·§4.7·§5. RN `app/clips.tsx` + `components/{ShareResultModal,EditClipModal,TagApplyModal}` + `lib/clips-refresh` 이식.
저장된 클립을 목록으로 보고(로컬/DB 통합), 편집·삭제·공유링크·다중선택 태그일괄, 로그인 시 로컬→DB 마이그레이션.

> 착수 방식: CLAUDE.md Work Request Flow. 하위 3개↑ → **에픽 이슈 + 서브이슈**. 서브별 브랜치 `claude/issue-N-슬러그` → TDD → 빌드/테스트(`iPhone 17 Pro`) → `/code-review` → PR → CI → 머지. 새 세션은 index.md·plan.md 먼저 읽을 것. Phase 3 산출물 재사용: `UClip` 매핑·`parseTags`·`LocalClipStore`·`ClipCardView`·`TagChip`·`buildShareText`·`APIClient`.

### 서브 분할(의존순)

**#A ClipsStore — 데이터 로직·순수·TDD**
- 통합 로드: 로그인 → `APIClient.getClips` → `[UClip]`(DB, id=slug); 게스트 → `LocalClipStore.all()` → `[UClip]`(로컬, id=url). Phase 3 `UClip` 매핑 재사용.
- 액션: `removeOne(UClip)`(로컬=LocalClipStore.delete / DB=deleteClip), `saveEdit(title,tags)`, `makeShared(slug)`(updateClip shared:true), `applyTags(ids, tags, mode:add|replace)` — add=기존∪신규 **dedup·최대6**, replace=신규 최대6.
- 파생: `allTags`(dedup), 태그 필터, `shareText(clip)` = `buildShareText(title, description, "{API_BASE}/{slug}")` (§4.3).
- `clips-refresh` 신호(NotificationCenter) — emit/subscribe(마이그레이션·편집 후 목록 갱신).
- 검증: 매핑, applyTags add/replace·dedup·6캡, 태그필터, allTags, shareText 순수 테스트(APIClient 스텁).
- 영향: 신규 `ClipNote/Clips/ClipsStore.swift`(@MainActor @Observable)·`ClipsRefresh.swift`, 테스트.

**#D1 모달 — EditClipModal·(전체)ShareResultModal (B 이전 필요)**
- `EditClipModal`: 제목·태그 단건 편집(저장은 호출부가 local/DB 결정).
- `ShareResultModal`(전체): 복사(§4.3)·열기(SFSafari)·내 클립에 저장·닫기 — 홈의 최소 시트 교체.
- 영향: 신규 `ClipNote/Views/EditClipModal.swift`·`ShareResultModal.swift`. HomeView 최소 시트 → ShareResultModal 교체.

**#B ClipsView — 목록·필터칩·카드·스와이프·⋯메뉴**
- 목록(List/ScrollView), `FilterChip` 가로 스크롤("전체"+태그별), loading("불러오는 중…")·empty("첫 클립 만들기") 상태.
- 카드: 썸네일·제목(2줄)·호스트·태그 + `⋯` 메뉴(편집→#D1 / 삭제 confirm). `ClipCardView` 확장 또는 전용 행.
- **스와이프**(`.swipeActions` 편집/삭제).
- 액션 행: DB클립 `shared=true`→**"공유 링크 복사"**(§4.3)/`false`→**"공유 링크 만들기"**(makeShared 후 갱신), **"바로가기"**(SFSafari). 로컬은 공유 액션 없음.
- 포커스 새로고침(`.task`/`onAppear`) + `clips-refresh` 구독.
- 진입점: HomeView 툴바에 "내 클립" 링크(임시 — 전체 헤더 메뉴는 Phase 5). NavigationStack 목적지 등록.
- 영향: 신규 `ClipNote/Clips/ClipsView.swift`·`FilterChip.swift`. HomeView 툴바 링크.

**#C 다중선택 — 롱프레스 진입·하단 바 (로그인 전용)**
- 롱프레스 → selectMode, 체크박스, 툴바(취소 / "n개 선택"). 게스트(로컬)는 비노출.
- 하단 바: "태그 적용"(→#D2 TagApplyModal), "삭제(n)"(bulk confirm → removeOne 반복 → 갱신·해제).
- 영향: `ClipsView` 확장.

**#D2 TagApplyModal — 다중선택 태그 일괄 (C와 함께)**
- 추가/교체 모드, `parseTags`. 적용은 #A `applyTags`.
- 영향: 신규 `ClipNote/Views/TagApplyModal.swift`.

**#E 로그인 마이그레이션 §5 — MigrateLocalClips**
- 로그인 전환 감지(`AuthStore` 상태) → 로컬 클립 존재 시 1회 Alert("옮기기"/"나중에"). 중복 실행 가드.
- "옮기기": 각 로컬 클립 `createClip(save:true)` 업로드 → `clearLocalClips()` → `clips-refresh` emit → 완료 알림. "나중에"면 유지.
- 영향: 신규 `ClipNote/Clips/MigrateLocalClips.swift`(@MainActor), 앱 루트에 훅. 로직 분리 테스트(업로드 목록 생성·가드).

### 범위 밖(후속)
- 헤더 메뉴 전체(About/FAQ/로그아웃/회원탈퇴)·실제 온보딩 슬라이드·AdBanner·심사 대비 = Phase 5.
- ⚠️ #7/#8 실제 OAuth 로그인 실기기 검증(사람만 가능) — 미해결 이월.

### 리스크
- 목록 갱신 일관성 — 편집/삭제/마이그레이션 후 `clips-refresh` 신호 누락 없이 반영.
- 다중선택 로그인 전용 조건(로컬 UClip은 로그아웃 상태에서만 존재) — 진입 가드.
- 마이그레이션 부분 실패(일부 업로드 실패) 시 `clearLocalClips` 타이밍 — 전부 성공 후 비우기 vs 성공분만. RN은 전량 업로드 후 clear. 부분 실패 처리 방침 확정 필요.
- §4.3 공유복사 규칙을 홈(ShareResultModal)·클립목록·모달 3곳 동일 적용(`buildShareText` 단일 소스).

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
