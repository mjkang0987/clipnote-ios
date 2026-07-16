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
        } else {
            OnboardingGateView { onboardingSeen = true }
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
