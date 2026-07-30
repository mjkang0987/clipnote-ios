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
- **작업 계획 수립:** 모든 작업을 시작하기 전 `plan.md`를 작성할 것. 요구사항, 구현 방식, 영향받는 파일,
  예상 결과를 기록하고 검토가 끝난 후 코드를 수정할 것. (개발 중 범위가 변경되면 `plan.md` 즉시 업데이트)
- **작업 분할 및 브랜치 생성:** 작업 요청 시 가장 작은 단위의 이슈로 나누고, `develop` 브랜치 파생으로
  개별 `feature` 브랜치를 생성하여 시작할 것.
- **Feature 검증 사이클:** `작업` > `코드리뷰` > `개선` > `검증` > `수정작업` > `코드리뷰` > `개선` > `검증`
  — 이 프로세스를 `feature` 브랜치 내에서 완벽히 완료할 것. 리뷰를 건너뛰고 푸시하지 않는다.
- **Dev 병합 및 2차 검증:** 단일 `feature` 검증이 끝나면 `develop` 브랜치에 머지 + 푸시할 것.
  `develop` 에서도 동일한 사이클을 거쳐 통합 부작용을 해결할 것.
- **Main 배포:** `develop` 진행이 완료되면 PR을 생성하고 `main` 머지를 **요청**할 것.
  지시자의 명시적 승인 없이 `main`에 머지하지 않는다.
- **버전 펌핑:** PR 머지 시 변경 규모(Patch / Minor / Major)를 판단하여 버전을 올릴 것. (iOS: `project.yml` 의 `MARKETING_VERSION`)

## Work Request Flow (업무 처리 절차)
> 사용자가 업무를 요청하면 아래 순서를 따른다.

**세부 규약:**
- **이슈당 브랜치 · 이슈당 PR.** 브랜치명 `feature/<짧은슬러그>`(또는 `claude/issue-<번호>-<슬러그>`), `develop`에서 분기·`develop`으로 머지. 한 번에 한 이슈.
- **`develop` 까지만 자동 진행.** 검증·리뷰가 그린이면 `develop` 에 머지. `main` 머지는 지시자의 명시적 승인이 있을 때만.
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
9. **머지** — 그린이면 `develop`으로 머지(`main` 머지는 지시자 승인 후). 이슈 자동 종료, `index.md`·`plan.md` 갱신.
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

## 위험한 명령 금지 (사고 재발 방지)

되돌릴 수 없는 작업으로 실제 데이터를 잃은 사고가 있었다(GitHub Secret 덮어쓰기, 그 이전 DB 삭제).
아래는 예외 없이 지킨다.

- **되돌릴 수 없는 명령은 제안하지 않는다.** 덮어쓰기·삭제·원격 반영은 명령 대신 **UI 경로로 안내**한다.
  (시크릿 갱신, force push, DB 마이그레이션·삭제, `rm`, 기존 파일을 덮는 `cp`/`>` 등)
- 명령이 불가피하면 **무엇이 사라지는지 먼저 적고, 승인을 받은 뒤** 제시한다.
- **읽기 명령과 쓰기 명령을 한 묶음으로 주지 않는다.**
  금지 예: `cp Secrets.example.xcconfig Secrets.xcconfig` 다음에 `gh secret set ... < Secrets.xcconfig` 를 이어 붙이기.
- 기존 값이 있는 대상은 **현재 상태를 먼저 확인**하는 단계를 둔다(덮어쓰기 전에 무엇이 들어있는지).
- 값을 다시 읽을 수 없는 저장소(GitHub Secrets 등)는 특히 주의한다 — 버전 이력도 백업도 없다.
