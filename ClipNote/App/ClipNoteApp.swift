import SwiftUI
import GoogleMobileAds

@main
struct ClipNoteApp: App {
    @StateObject private var auth = AuthStore() ?? AuthStore.disabled()

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
                .onOpenURL { url in
                    Task { await auth.handle(url: url) }
                }
        }
        .modelContainer(for: LocalClip.self)
    }
}
