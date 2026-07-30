import SwiftUI
import GoogleMobileAds

@main
struct ClipNoteApp: App {
    @StateObject private var auth = AuthStore() ?? AuthStore.disabled()
    /// 표시 언어. RootView가 아니라 App에서 주입한다 — 온보딩 분기까지 한 번에 덮기 위해.
    @State private var i18n = LocalizationStore()

    init() {
        // App ID 없는 빌드(CI 등)에선 시작하지 않음 — SDK가 GADApplicationIdentifier 부재 시 크래시.
        if AdConfig.enabled {
            MobileAds.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environment(i18n)
                .onOpenURL { url in
                    Task { await auth.handle(url: url) }
                }
        }
        .modelContainer(for: LocalClip.self)
    }
}
