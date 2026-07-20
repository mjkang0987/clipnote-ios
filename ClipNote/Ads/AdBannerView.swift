import SwiftUI
import GoogleMobileAds

/// 하단 앵커 적응형 배너. RN `components/AdBanner.tsx` 이식.
/// 로드 성공 전까진 높이 0(빈 공간 방지). AdConfig.enabled=false(App ID 없음)면 아예 렌더 안 함.
struct AdBannerView: View {
    @State private var loaded = false

    var body: some View {
        if AdConfig.enabled {
            BannerRepresentable(loaded: $loaded)
                .frame(height: loaded ? AdConfig.bannerHeight : 0)
                .clipped()
        }
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    @Binding var loaded: Bool

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        // 폭이 정해진 뒤 1회 로드(앵커 적응형은 폭 기준 크기 계산).
        guard !context.coordinator.requested else { return }
        let width = banner.superview?.bounds.width ?? UIScreen.main.bounds.width
        guard width > 0 else { return }
        context.coordinator.requested = true
        banner.adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        banner.load(Request())
    }

    func makeCoordinator() -> Coordinator { Coordinator(loaded: $loaded) }

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var loaded: Bool
        var requested = false

        init(loaded: Binding<Bool>) { _loaded = loaded }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            loaded = true
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            loaded = false
        }
    }
}
