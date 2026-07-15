# CLAUDE.md

> 이 저장소에서 Claude가 항상 따라야 할 지시사항. 세션 시작 시 `index.md`·`plan.md`와 함께 읽는다.

## Priority Order
1. Core Principles
2. Session Startup Rules
3. Development Workflow
4. Work Request Flow
5. iOS/Swift Standards
6. Documentation Maintenance

## Core Principles
- If unsure, say so instead of guessing.
- Point out problems with my approach directly.
- If something fails, investigate the root cause before retrying.

## Session Startup Rules
- 새 세션 시작 시 `index.md`·`plan.md`를 먼저 읽는다.
- `index.md`는 프로젝트 구조·현재 상태의 source of truth, `plan.md`는 현재/향후 작업의 source of truth.
- 문서와 구현이 다르면 불일치를 보고하고 확인받은 뒤 진행한다.

## Development Workflow
- 작업 전에 `plan.md`에 요구사항·구현 방식·영향 파일·기대 결과를 적고 확정한 뒤 코드를 만진다.
- **프로젝트는 XcodeGen 기반**: `.xcodeproj`는 커밋하지 않고 `project.yml`에서 생성한다(`xcodegen generate`). 타깃/스킴/설정 변경은 `project.yml`에서 한다.
- **빌드에 `Secrets.xcconfig` 필요**(gitignored). 로컬은 `Secrets.example.xcconfig`를 복사해 채운다. 시크릿을 소스/커밋에 넣지 않는다.
- 버전은 `project.yml`의 `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`으로 관리(릴리스 시 수동 범프).

## Work Request Flow (업무 처리 절차)
> 사용자가 업무를 요청하면 아래 순서를 따른다.

**세부 규약:**
- **이슈당 브랜치 · 이슈당 PR.** 브랜치명 `claude/issue-<번호>-<짧은슬러그>`, `main`에서 분기·`main`으로 PR. 한 번에 한 이슈.
- **자동 머지.** 8단계(코드검증·자동리뷰·CI)가 그린이면 사용자 승인 없이 머지.
- **라벨**: `feature`/`fix`/`chore`/`refactor`/`docs`(없으면 생성). 하위 3개 이상이면 에픽+서브이슈.
- **검증 범위**: 항상 빌드(`xcodebuild build`). 로직 변경은 테스트(`xcodebuild test`)까지.

1. **업무 요청 접수** — 모호하면 먼저 질문해 범위를 확정한다(추측 금지).
2. **이슈 분할·생성** — 작업 단위로 GitHub 이슈 생성(배경·작업 체크리스트·완료 조건·관련 파일). 큰 기능은 에픽+서브이슈.
3. **작업** — `main`에서 이슈당 브랜치를 만들어 구현. 커밋은 최소 단위·한국어·conventional prefix(`On Commit`).
4. **검증** — `xcodegen generate` 후 `xcodebuild build`(+로직 변경 시 `xcodebuild test`)로 컴파일·동작 확인.
5. **코드리뷰** — `/code-review`로 diff 리뷰.
   1. **리팩토링** — 지적 반영 + `/simplify`.
6. **재검증** — 리팩토링 후 다시 빌드/테스트.
7. **PR 생성** — 본문에 `Closes #<이슈>`. PR 생성 시 자동 CI(`.github/workflows/pr-review.yml`, macOS 빌드)가 실행된다.
8. **코드 검증** — PR 상태에서 CI(빌드) 결과 확인. 지적이 있으면 4~6 반복.
9. **머지** — 그린이면 `main`으로 자동 머지. 이슈 자동 종료, `index.md`·`plan.md` 갱신.
10. **릴리스·배포** — App Store/TestFlight 배포는 수동(Xcode Archive 또는 fastlane). 릴리스 시 `project.yml` 버전 범프.

## iOS/Swift Standards
- **옵셔널**: 강제 언래핑(`!`)·강제 캐스팅 지양. `guard let`/`if let`/`??` 사용.
- **메모리**: 클로저·델리게이트 순환참조 주의(`[weak self]`).
- **동시성**: Swift 6 strict concurrency 준수(액터 격리·`@MainActor`·`Sendable`). UI 갱신은 메인 액터.
- **보안**: 시크릿·토큰을 코드에 하드코딩하지 않는다(`Secrets.xcconfig`/Keychain). 로그에 민감정보 금지.
- **SwiftUI**: 뷰는 작고 선언적으로. 상태 관리(`@State`/`@Observable`) 남용·불필요한 재렌더 주의.
- 접근성(Dynamic Type·VoiceLabel) 고려.

## Documentation Maintenance
- 작업 완료 후 `index.md`·`plan.md`를 갱신한다.

## On Commit
- 커밋은 최소 단위로 나눈다. 한국어. conventional prefix(`feat:`/`fix:`/`refactor:`/`chore:` 등). 커밋 후 항상 push.
