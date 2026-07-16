import SwiftUI

/// 온보딩 플래그. Phase 5의 실제 온보딩 화면도 같은 키를 쓴다.
enum OnboardingFlags {
    static let seenKey = "clipnote.onboardingSeen"
}

/// 루트 게이트 — 최초 실행이면 온보딩, 아니면 홈. `@AppStorage`는 동기라 렌더 보류 불필요.
struct RootView: View {
    @AppStorage(OnboardingFlags.seenKey) private var onboardingSeen = false

    var body: some View {
        if onboardingSeen {
            NavigationStack { HomeView() }
                .modifier(LoginMigrationModifier())
        } else {
            OnboardingGateView { onboardingSeen = true }
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

/// 최초 실행 플레이스홀더 — "시작하기"로 플래그 설정 후 홈 진입.
/// Phase 5에서 기능 설명 슬라이드(TabView)로 교체(설계 §4.5).
struct OnboardingGateView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("ClipNote")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppColor.brand)
            Text("링크를 붙여넣으면 예쁜 공유 카드와 짧은 링크가 한 번에 만들어져요.")
                .font(.system(size: 15))
                .foregroundStyle(AppColor.fgMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button(action: onDone) {
                Text("시작하기")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bg)
    }
}

#Preview {
    OnboardingGateView(onDone: {})
}
