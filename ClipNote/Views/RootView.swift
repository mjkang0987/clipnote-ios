import SwiftUI

/// 온보딩 플래그. Phase 5의 실제 온보딩 화면도 같은 키를 쓴다.
enum OnboardingFlags {
    static let seenKey = "clipnote.onboardingSeen"
}

/// 루트 게이트 — 최초 실행이면 온보딩, 아니면 홈. `@AppStorage`는 동기라 렌더 보류 불필요.
struct RootView: View {
    @AppStorage(OnboardingFlags.seenKey) private var onboardingSeen = false
    @EnvironmentObject private var auth: AuthStore
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
                        }
                    }
            }
            .environment(router)
            // 공유 확장 딥링크(clipnote://share?url=) → 홈으로 이동 + 입력칸 채우기.
            .onOpenURL { url in
                if let shared = ShareDeepLink.parse(url) {
                    router.home()
                    router.pendingSharedURL = shared
                }
            }
            .sheet(isPresented: $router.showLogin) { LoginView() }
            .sheet(item: $router.safari) { item in SafariView(url: item.url) }
            // 사용법 투어 — 모달로 띄워 NavigationStack 중첩(크래시)을 피한다. 첫 실행 온보딩과 동일 구조.
            .fullScreenCover(isPresented: $router.showTour) {
                // fullScreenCover는 조상의 @EnvironmentObject를 자동 상속하지 않을 수 있어 명시 재주입.
                OnboardingView { router.showTour = false }
                    .environmentObject(auth)
            }
            .modifier(LoginMigrationModifier())
        } else {
            OnboardingView { onboardingSeen = true }
        }
    }
}

/// 로그인 전환 감지 → 로컬 클립 있으면 1회 확인 후 DB로 옮김(§5). 중복 프롬프트 가드.
private struct LoginMigrationModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthStore
    @State private var ask = false
    @State private var pendingCount = 0
    @State private var resultMessage: String?
    @State private var prompted = false

    func body(content: Content) -> some View {
        content
            .onChange(of: auth.loggedIn) { _, now in
                if now { check() } else { prompted = false }
            }
            .confirmationDialog("클립 옮기기", isPresented: $ask, titleVisibility: .visible) {
                Button("옮기기") { migrate() }
                Button("나중에", role: .cancel) {}
            } message: {
                Text("이 기기에 저장한 클립 \(pendingCount)개를 내 계정으로 옮길까요?")
            }
            .alert("클립 옮기기", isPresented: resultBinding) {
                Button("확인", role: .cancel) { resultMessage = nil }
            } message: {
                Text(resultMessage ?? "")
            }
    }

    private var resultBinding: Binding<Bool> {
        Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })
    }

    private func check() {
        guard !prompted else { return }
        let count = LocalClipStore(container: modelContext.container).all().count
        guard count > 0 else { return }
        pendingCount = count
        prompted = true
        ask = true
    }

    private func migrate() {
        let store = LocalClipStore(container: modelContext.container)
        let token = auth.accessToken
        Task {
            let (uploaded, allOK) = await MigrateLocalClips(localStore: store).run(accessToken: token)
            resultMessage = allOK
                ? "클립 \(uploaded)개를 옮겼어요."
                : "일부만 옮겨졌어요. 다시 시도해 주세요."
        }
    }
}

