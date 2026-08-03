import SwiftUI

/// 온보딩 플래그. Phase 5의 실제 온보딩 화면도 같은 키를 쓴다.
enum OnboardingFlags {
    static let seenKey = "clipnote.onboardingSeen"
}

/// 루트 게이트 — 최초 실행이면 온보딩, 아니면 홈. `@AppStorage`는 동기라 렌더 보류 불필요.
struct RootView: View {
    @AppStorage(OnboardingFlags.seenKey) private var onboardingSeen = false
    @Environment(LocalizationStore.self) private var i18n
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router
        if onboardingSeen {
            NavigationStack(path: $router.path) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .clips: ClipsView()
                        case .about: AboutView()
                        case .faq: FaqView()
                        case .privacy: PrivacyView()
                        case .accountDelete: AccountDeleteView()
                        case .settings: SettingsView()
                        }
                    }
            }
            .environment(router)
            // 공유 확장 딥링크(clipnote://share?url=) → 홈으로 이동 + 입력칸 채우기(열기 hack 성공 시 즉시).
            .onOpenURL { url in
                if let shared = ShareDeepLink.parse(url) {
                    router.home()
                    router.pendingSharedURL = shared
                }
            }
            // App Group 폴백: 확장이 저장한 URL을 포그라운드 진입 시 소비(열기 hack 실패해도 유실 없음).
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { consumeSharedFromAppGroup() }
            }
            .onAppear { consumeSharedFromAppGroup() }
            .sheet(isPresented: $router.showLogin) { LoginView() }
            .sheet(item: $router.safari) { item in SafariView(url: item.url) }
            // 사용법 투어 — 모달로 띄워 NavigationStack 중첩(크래시)을 피한다. 첫 실행 온보딩과 동일 구조.
            .fullScreenCover(isPresented: $router.showTour) {
                // fullScreenCover는 조상의 환경을 자동 상속하지 않을 수 있어 명시 재주입.
                // 표시 언어까지 함께 넘긴다 — 빠지면 투어만 조용히 한국어로 나온다.
                OnboardingView { router.showTour = false }
                    .environmentObject(auth)
                    .environment(i18n)
            }
            .modifier(LoginMigrationModifier())
        } else {
            OnboardingView { onboardingSeen = true }
        }
    }

    /// 공유 확장이 App Group에 저장한 URL이 있으면 홈 입력칸에 채운다(1회 소비).
    private func consumeSharedFromAppGroup() {
        if let shared = SharedURLStore.consume() {
            router.home()
            router.pendingSharedURL = shared
        }
    }
}

/// 로그인 전환 감지 → 로컬 클립이 있으면 계정으로 옮길지 묻는다(§5). 중복 프롬프트 가드.
///
/// **왜 거절에 삭제 확인이 따라붙나** — 로그인 상태의 내 클립 목록은 DB 를 보여준다
/// (`ClipsStore.load`). 옮기지 않은 로컬 클립은 그때부터 화면에서 볼 방법이 없으니 남겨 둘
/// 자리가 없다. 웹도 같은 이유로 거절하면 삭제를 확인받는다(`ClipsClient.askDiscardLocal`).
///
/// **세 갈래를 구분한다**(웹 `a0f931d`→`ec7221d`→`4323eb6` 과 같은 결론)
/// - `옮기기` — 계정으로 올리고 로컬을 비운다
/// - `취소` — 옮기지 않겠다는 의사 표시 → 삭제 확인으로 넘어간다
/// - 스와이프로 닫기 — **결정 보류**. 로컬 클립을 그대로 두므로 다음 로그인 때 다시 뜬다
///
/// 이 구분 때문에 `confirmationDialog` 를 쓸 수 없다 — 바깥 탭과 취소를 구분하지 못한다.
private struct LoginMigrationModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocalizationStore.self) private var i18n
    @EnvironmentObject private var auth: AuthStore

    // 개수를 그리는 레이어는 `.sheet(item:)` 으로 값을 실어 보낸다 — `ClipCount` 주석 참고.
    @State private var migrateRequest: ClipCount?
    @State private var discardRequest: ClipCount?
    /// `취소` 를 눌러서 닫혔는가. 스와이프로 닫힌 경우와 구분하려고 둔다 —
    /// `.sheet(onDismiss:)` 는 둘을 똑같이 알려주기 때문에 버튼 쪽에서 표시를 남겨야 한다.
    @State private var declined = false
    @State private var pendingCount = 0
    @State private var migrating = false
    @State private var resultMessage: String?
    @State private var prompted = false

    /// 수량 표기(`3개`·`3 clips`)는 언어마다 단위 위치가 달라 문장에서 떼어 둔다.
    /// 이걸 만들어 `%@` 자리에 끼워 넣는다 — 웹 `clips.countUnit` 과 같은 방식.
    private func countUnit(_ count: Int) -> String {
        i18n.t("clips.countUnit", args: count)
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: auth.loggedIn) { _, now in
                if now { check() } else { prompted = false }
            }
            .sheet(item: $migrateRequest, onDismiss: resolveMigrateDismiss) { migrateLayer($0.value) }
            .sheet(item: $discardRequest) { discardLayer($0.value) }
            // 옮기기 결과는 결정이 아니라 알림이라 레이어로 만들지 않는다.
            // (웹은 페이지가 그 자리에서 갱신돼 알림이 없지만, 앱은 네트워크 작업이라 결과를 알린다.)
            .alert(i18n.t("clips.migrateResultTitle"), isPresented: resultBinding) {
                Button(i18n.t("common.confirm"), role: .cancel) { resultMessage = nil }
            } message: {
                Text(resultMessage ?? "")
            }
    }

    // MARK: - 레이어

    private func migrateLayer(_ pending: Int) -> some View {
        let count = countUnit(pending)
        return ConfirmLayer(
            title: i18n.t("clips.migrateTitle"),
            message: emphasized(i18n.t("clips.migrateBody", args: count), [count]),
            confirmLabel: i18n.t("clips.migrateConfirm", args: count),
            busy: migrating,
            busyLabel: i18n.t("clips.migrating"),
            cancelLabel: i18n.t("common.cancel"),
            // 옮기는 동안 레이어를 열어 둔 채 스피너를 보여 준다(웹과 동일). 끝나면 닫는다.
            onConfirm: { migrate(pending) },
            onCancel: { declined = true; migrateRequest = nil }
        )
        // 진행 중에는 스와이프로 닫지 못하게 막는다 — 중간에 닫히면 무엇이 옮겨졌는지 알 수 없다.
        .interactiveDismissDisabled(migrating)
    }

    private func discardLayer(_ pending: Int) -> some View {
        let count = countUnit(pending)
        let irreversible = i18n.t("clips.discardIrreversible")
        return ConfirmLayer(
            title: i18n.t("clips.discardTitle"),
            message: emphasized(i18n.t("clips.discardBody", args: count, irreversible),
                                [count, irreversible]),
            confirmLabel: i18n.t("common.delete"),
            cancelLabel: i18n.t("common.cancel"),
            onConfirm: { discard(); discardRequest = nil },
            onCancel: { discardRequest = nil }
        )
    }

    // MARK: - 동작

    private var resultBinding: Binding<Bool> {
        Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })
    }

    private func check() {
        guard !prompted else { return }
        let count = LocalClipStore(container: modelContext.container).all().count
        guard count > 0 else { return }
        pendingCount = count
        prompted = true
        declined = false
        migrateRequest = ClipCount(value: count)
    }

    /// 레이어가 닫힌 뒤 다음 단계를 정한다.
    /// `취소` 를 눌렀으면 삭제 확인으로, 그냥 닫았으면 **보류**(로컬 클립을 건드리지 않는다).
    private func resolveMigrateDismiss() {
        guard declined else { return }
        declined = false
        discardRequest = ClipCount(value: pendingCount)
    }

    private func migrate(_ pending: Int) {
        let store = LocalClipStore(container: modelContext.container)
        let token = auth.accessToken
        migrating = true
        Task {
            let (uploaded, allOK) = await MigrateLocalClips(localStore: store).run(accessToken: token)
            migrating = false
            migrateRequest = nil
            resultMessage = allOK
                ? i18n.t("clips.migrateDone", args: countUnit(uploaded))
                : i18n.t("clips.migratePartial")
            ClipsRefresh.emit()
        }
    }

    /// 이 기기의 클립을 전부 지운다. **되돌릴 수 없다**(서버 사본이 없다).
    /// 목록이 열려 있을 수 있으니 새로고침 신호를 보낸다.
    private func discard() {
        LocalClipStore(container: modelContext.container).clearLocalClips()
        ClipsRefresh.emit()
    }
}
