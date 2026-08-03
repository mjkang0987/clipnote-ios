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
/// **거절해도 잃는 게 없다.** 로그인 목록 위에 ‘이 기기에 남은 클립 3개’ 진입 줄이 서고,
/// 거기서 언제든 다시 옮기거나 지울 수 있다(`LocalClipsView`). 전에는 서버 것만 보여줘서
/// 옮기지 않은 로컬 클립은 로그인하는 순간 볼 방법이 없어졌고 — 그래서 거절하면 "그럼
/// 지울까?" 를 물어야 했다. 이제 그 확인이 없다.
///
/// 옮기면 좋은 이유는 남아 있다. 서버 사본만 **공유 링크를 만들 수 있고**(로컬은 slug 가 없다)
/// 다른 기기에서도 보인다. 그래서 묻기는 하되 강요하지 않는다.
///
/// 레이어·결과 알림은 `MigrateLocalClipsLayer` 가 들고 있다 — 로컬 클립 화면과 같은 것을 쓴다.
private struct LoginMigrationModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthStore

    // 개수를 그리는 레이어는 `.sheet(item:)` 으로 값을 실어 보낸다 — `ClipCount` 주석 참고.
    @State private var migrateRequest: ClipCount?
    @State private var prompted = false

    func body(content: Content) -> some View {
        content
            .onChange(of: auth.loggedIn) { _, now in
                if now { check() } else { prompted = false }
            }
            .migrateLocalClipsLayer(request: $migrateRequest)
    }

    private func check() {
        guard !prompted else { return }
        let count = LocalClipStore(container: modelContext.container).all().count
        guard count > 0 else { return }
        prompted = true
        migrateRequest = ClipCount(value: count)
    }
}
