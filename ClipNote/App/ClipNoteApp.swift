import SwiftUI

@main
struct ClipNoteApp: App {
    @StateObject private var auth = AuthStore() ?? AuthStore.disabled()

    var body: some Scene {
        WindowGroup {
            RootPlaceholderView()
                .environmentObject(auth)
                .onOpenURL { url in
                    Task { await auth.handle(url: url) }
                }
        }
    }
}

struct RootPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("ClipNote")
                .font(.largeTitle.bold())
            Text("Foundation online")
                .foregroundStyle(.secondary)
        }
    }
}
