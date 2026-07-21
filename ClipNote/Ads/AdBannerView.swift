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

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView()
        banner.adUnitID = AdConfig.bannerUnitID
        banner.delegate = context.coordinator
        // GADBannerView는 rootViewController가 없으면 광고를 로드·표시하지 못한다(필수).
        banner.rootViewController = Self.rootViewController()
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        guard !context.coordinator.requested else { return }
        context.coordinator.requested = true
        // 로드·adSize 설정을 앱의 초기 레이아웃 패스에서 분리(async)한다.
        // 초기 패스 중에 하면 콜드 부팅 시 화면 스케일이 깨지는 문제가 있었음.
        DispatchQueue.main.async {
            if banner.rootViewController == nil { banner.rootViewController = Self.rootViewController() }
            let width = Self.keyWindowWidth()
            guard width > 0 else { context.coordinator.requested = false; return }
            banner.adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
            // SDK 초기화가 끝나기 전에 요청하면 어댑터가 없어 no-fill이 난다.
            // start 완료(이미 완료면 즉시) 콜백 안에서 로드해 순서를 보장한다.
            MobileAds.shared.start { _ in
                Coordinator.log.debug("배너 광고 로드 요청(width \(width, privacy: .public))")
                banner.load(Request())
            }
        }
    }

    /// 현재 키 윈도우의 rootViewController(배너 표시 컨텍스트).
    static func rootViewController() -> UIViewController? {
        keyWindow()?.rootViewController
    }

    static func keyWindowWidth() -> CGFloat {
        keyWindow()?.bounds.width ?? UIScreen.main.bounds.width
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

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
