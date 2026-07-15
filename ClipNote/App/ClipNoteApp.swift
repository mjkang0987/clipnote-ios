import SwiftUI

@main
struct ClipNoteApp: App {
    var body: some Scene {
        WindowGroup {
            RootPlaceholderView()
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
