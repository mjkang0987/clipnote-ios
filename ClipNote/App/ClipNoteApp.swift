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

/// 임시 루트 — 로그인 상태 확인용(Phase 7에서 실제 홈/네비게이션으로 교체).
struct RootPlaceholderView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        if auth.loggedIn {
            VStack(spacing: 12) {
                Text("로그인됨")
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.success)
                Button("로그아웃") {
                    Task { await auth.signOut() }
                }
            }
            .padding(24)
        } else {
            LoginView()
        }
    }
}
