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
/// **왜 거절에 삭제 확인이 따라붙나** — 로그인 상태의 내 클립 목록은 DB 를 보여준다(`ClipsStore.load`).
/// 옮기지 않은 로컬 클립은 그때부터 화면에서 볼 방법이 없으니 남겨 둘 자리가 없다. 웹도 같은 이유로
/// 거절하면 삭제를 확인받는다(`ClipsClient.askDiscardLocal`).
///
/// **웹과 다른 점** — 웹은 `[옮기기] [취소]` 두 버튼이고 `취소` 가 삭제 확인으로 넘어간다.
/// iOS 에서 취소 역할 버튼이 삭제 흐름을 여는 건 관례에 어긋나고, `confirmationDialog` 는
/// 바깥 탭으로 닫힌 것과 취소를 누른 것을 구분할 수 없다. 그래서 의도를 라벨에 드러내
/// `[옮기기] [이 기기에서 삭제] [나중에]` 세 버튼으로 편다. 삭제는 웹과 똑같이 한 단계 더 확인받고,
/// 애매한 닫힘(바깥 탭)은 어느 경우든 **결정 보류**로 떨어진다 — 로컬 클립은 그대로 남는다.
private struct LoginMigrationModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocalizationStore.self) private var i18n
    @EnvironmentObject private var auth: AuthStore
    @State private var ask = false
    @State private var askDiscard = false
    @State private var pendingCount = 0
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
            .confirmationDialog(
                i18n.t("clips.migrateTitle"), isPresented: $ask, titleVisibility: .visible
            ) {
                Button(i18n.t("clips.migrateConfirm", args: countUnit(pendingCount))) { migrate() }
                Button(i18n.t("clips.discardAction"), role: .destructive) { askDiscard = true }
                Button(i18n.t("clips.migrateLater"), role: .cancel) {}
            } message: {
                Text(i18n.t("clips.migrateBody", args: countUnit(pendingCount)))
            }
            // 삭제 확인. 로컬 클립은 이 기기에만 있고 서버 사본이 없어 되돌릴 수 없다 —
            // 그래서 한 단계를 더 둔다. 여기서 취소하면 아무 일도 일어나지 않는다(보류).
            .confirmationDialog(
                i18n.t("clips.discardTitle"), isPresented: $askDiscard, titleVisibility: .visible
            ) {
                Button(i18n.t("common.delete"), role: .destructive) { discard() }
                Button(i18n.t("common.cancel"), role: .cancel) {}
            } message: {
                Text(i18n.t("clips.discardBody",
                            args: countUnit(pendingCount), i18n.t("clips.discardIrreversible")))
            }
            // 결과 알림 제목은 확인 다이얼로그와 다르다 — 후자는 의문형("…옮길까요?")이라
            // "3개를 옮겼어요" 위에 얹으면 말이 안 된다.
            .alert(i18n.t("clips.migrateResultTitle"), isPresented: resultBinding) {
                Button(i18n.t("common.confirm"), role: .cancel) { resultMessage = nil }
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
                ? i18n.t("clips.migrateDone", args: countUnit(uploaded))
                : i18n.t("clips.migratePartial")
        }
    }

    /// 이 기기의 클립을 전부 지운다. **되돌릴 수 없다**(서버 사본이 없다).
    /// 목록이 열려 있을 수 있으니 새로고침 신호를 보낸다.
    private func discard() {
        LocalClipStore(container: modelContext.container).clearLocalClips()
        ClipsRefresh.emit()
    }
}
