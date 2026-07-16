import SwiftUI

@main
struct ClipNoteApp: App {
    @StateObject private var auth = AuthStore() ?? AuthStore.disabled()

    var body: some Scene {
        WindowGroup {
            NavigationStack { HomeView() }
                .environmentObject(auth)
                .onOpenURL { url in
                    Task { await auth.handle(url: url) }
                }
        }
        .modelContainer(for: LocalClip.self)
    }
}
