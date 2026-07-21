import SwiftUI
import GoogleMobileAds
import os

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
            Self.log.debug("배너 광고 로드 성공")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            loaded = false
            // 광고 미표시 원인 진단용(no-fill·네트워크·설정 등). Console.app에서 "clipnote.ads"로 필터.
            Self.log.error("배너 광고 로드 실패: \(error.localizedDescription, privacy: .public)")
        }

        static let log = Logger(subsystem: "clipnote.ads", category: "banner")
    }
}
