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
            // 로그아웃 확인 — 헤더 메뉴와 설정 두 곳이 부르지만 레이어는 여기 하나뿐이다.
            // 확인 계열은 전부 레이어로 띄운다(웹과 동일) — `ConfirmLayer` 주석 참고.
            .sheet(isPresented: $router.confirmLogout) { logoutLayer }
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

    /// 로그아웃 확인.
    ///
    /// 되돌릴 수 없는 일은 아니지만, 다시 들어오려면 OAuth 를 한 번 더 거쳐야 해서 잘못
    /// 누르면 성가시다. 본문이 "클립은 그대로 있다" 를 먼저 말하는 것도 그래서다 — 이 화면에서
    /// 사용자가 가장 먼저 떠올리는 게 "지금 나가면 저장한 게 사라지나" 이다.
    private var logoutLayer: some View {
        ConfirmLayer(
            title: i18n.t("logout.confirmTitle"),
            message: Text(i18n.t("logout.confirmBody")),
            confirmLabel: i18n.t("common.logout"),
            cancelLabel: i18n.t("common.cancel"),
            onConfirm: {
                router.confirmLogout = false
                Task { await auth.signOut() }
            },
            onCancel: { router.confirmLogout = false }
        )
    }

    /// 공유 확장이 App Group에 저장한 URL이 있으면 홈 입력칸에 채운다(1회 소비).
    private func consumeSharedFromAppGroup() {
        if let shared = SharedURLStore.consume() {
            router.home()
            router.pendingSharedURL = shared
        }
    }
}

/// 로그인 전환 감지 → 로컬 클립이 있으면 계정으로 옮길지 **권한다**(§5). 중복 프롬프트 가드.
///
/// **거절해도 잃는 게 없다.** 로그인 목록이 서버와 이 기기를 함께 보여주기 때문이다
/// (`ClipsStore.merged`). 전에는 서버 것만 보여줘서, 옮기지 않은 로컬 클립은 로그인하는 순간
/// 볼 방법이 없어졌다 — 그래서 거절하면 "그럼 지울까?" 를 물어야 했다. 이제 그 확인이 없다.
///
/// 옮기면 좋은 이유는 남아 있다. 서버 사본만 **공유 링크를 만들 수 있고**(로컬은 slug 가 없다)
/// 다른 기기에서도 보인다. 그래서 묻기는 하되 강요하지 않는다.
private struct LoginMigrationModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocalizationStore.self) private var i18n
    @EnvironmentObject private var auth: AuthStore

    // 개수를 그리는 레이어는 `.sheet(item:)` 으로 값을 실어 보낸다 — `ClipCount` 주석 참고.
    @State private var migrateRequest: ClipCount?
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
            .sheet(item: $migrateRequest) { migrateLayer($0.value) }
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
            onCancel: { migrateRequest = nil }
        )
        // 진행 중에는 스와이프로 닫지 못하게 막는다 — 중간에 닫히면 무엇이 옮겨졌는지 알 수 없다.
        .interactiveDismissDisabled(migrating)
    }

    // MARK: - 동작

    private var resultBinding: Binding<Bool> {
        Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })
    }

    private func check() {
        guard !prompted else { return }
        let count = LocalClipStore(container: modelContext.container).all().count
        guard count > 0 else { return }
        prompted = true
        migrateRequest = ClipCount(value: count)
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

}
