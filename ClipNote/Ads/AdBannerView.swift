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
                .frame(maxWidth: .infinity)
                .frame(height: loaded ? AdConfig.bannerHeight : 0)
                .clipped()
        }
    }
}

private struct BannerRepresentable: UIViewRepresentable {
    @Binding var loaded: Bool

    func makeUIView(context: Context) -> AttachAwareBannerView {
        let banner = AttachAwareBannerView()
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator

        let coordinator = context.coordinator
        banner.onAttach = { [weak banner] window in
            guard let banner, !coordinator.requested else { return }
            coordinator.requested = true
            // **창에 붙는 순간은 레이아웃 패스 한가운데다.** 여기서 adSize 를 바꾸거나 광고를
            // 로드하면 그 패스를 다시 흔들어 화면 스케일이 깨진다. 한 틱 미뤄 패스가 끝난
            // 뒤에 손댄다.
            DispatchQueue.main.async {
                let width = window.bounds.width
                guard width > 0 else { coordinator.requested = false; return }
                // GADBannerView 는 rootViewController 가 없으면 광고를 로드·표시하지 못한다(필수).
                banner.rootViewController = window.rootViewController
                banner.adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
                // SDK 초기화가 끝나기 전에 요청하면 어댑터가 없어 no-fill 이 난다.
                // start 완료(이미 완료면 즉시) 콜백 안에서 로드해 순서를 보장한다.
                MobileAds.shared.start { _ in
                    Coordinator.log.debug("배너 광고 로드 요청(width \(width, privacy: .public))")
                    banner.load(Request())
                }
            }
        }
        return banner
    }

    /// 설정은 창에 붙을 때 **한 번만** 한다. 여기서 할 일은 없다.
    ///
    /// 전에는 이 안에서 adSize 를 정하고 광고를 실었다. `updateUIView` 는 부모가 다시 그려질
    /// 때마다 불리는데 그 대부분이 레이아웃 도중이고, 화면 전환처럼 배너가 새로 만들어지는
    /// 순간이 특히 그렇다 — 콜드 부팅만 피하면 되는 문제가 아니었다.
    func updateUIView(_ banner: AttachAwareBannerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(loaded: $loaded) }

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var loaded: Bool
        var requested = false
        private var retried = false

        init(loaded: Binding<Bool>) { _loaded = loaded }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            loaded = true
            Self.log.debug("배너 광고 로드 성공")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            loaded = false
            // 광고 미표시 원인 진단용(no-fill·네트워크·설정 등). Console.app에서 "clipnote.ads"로 필터.
            Self.log.error("배너 광고 로드 실패: \(error.localizedDescription, privacy: .public)")
            // 초기화·네트워크 타이밍으로 인한 일시적 no-fill 대비 1회만 재시도.
            guard !retried else { return }
            retried = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { bannerView.load(Request()) }
        }

        static let log = Logger(subsystem: "clipnote.ads", category: "banner")
    }
}

/// 자기가 올라간 창을 알려 주는 배너.
///
/// 광고 폭과 표시 컨텍스트(`rootViewController`)는 **이 배너가 실제로 올라간 창**에서
/// 가져와야 한다. 전에는 앱 전체에서 키 윈도우를 뒤져 썼는데, 키 윈도우는 키보드처럼
/// 시스템이 띄운 창일 수 있다 — 그러면 폭도 루트 컨트롤러도 엉뚱한 값이 잡히고, 광고는
/// 다른 폭 기준으로 받아 온 그림을 이 자리에 늘려 그린다.
final class AttachAwareBannerView: BannerView {
    /// 창에 붙을 때 그 창을 넘긴다. 떨어질 때(`window == nil`)는 부르지 않는다.
    var onAttach: ((UIWindow) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }
        onAttach?(window)
    }
}
