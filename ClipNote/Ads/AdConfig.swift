import Foundation

/// AdMob 설정. RN `lib/ads.ts` 이식.
/// DEBUG=구글 공식 테스트 unit(실광고 자가클릭 → 계정 정지 방지), RELEASE=Secrets 실 unit.
enum AdConfig {
    /// 배너 예약 높이(pt). 앵커 적응형은 기기폭 따라 50~90 변동 → 여유 64.
    static let bannerHeight: CGFloat = 64

    /// Info.plist에 주입된 AdMob App ID. 비어 있으면 SDK를 시작하지 않는다(크래시 방지).
    static var appID: String? { Config.string("GADApplicationIdentifier") }

    /// 광고 사용 가능 여부 — **App ID 와 배너 unit ID 가 둘 다 있어야** 한다.
    ///
    /// 전에는 App ID 만 봤다. 그런데 unit ID 는 **Release 에서만** Secrets 에서 온다
    /// (DEBUG 는 구글 테스트 ID 하드코딩). 비어 있으면 빈 문자열로 `BannerView.load` 를
    /// 부르게 되고 SDK 가 예외를 던진다 — 배너는 홈 첫 화면에 붙어 있어서 **켜자마자** 죽는다.
    ///
    /// DEBUG·CI 에서는 두 값이 항상 유효해 이 경로가 한 번도 실행되지 않는다. 그래서
    /// "개발에선 멀쩡한데 TestFlight 에서만 죽는" 모양이 된다. 값이 없으면 광고만 끄고
    /// 앱은 살린다 — 배너가 안 나오는 것보다 앱이 안 켜지는 게 훨씬 나쁘다.
    static var enabled: Bool {
        appID?.isEmpty == false && !bannerUnitID.isEmpty
    }

    static var bannerUnitID: String {
        #if DEBUG
        // 구글 공식 iOS 적응형 배너 테스트 ID
        return "ca-app-pub-3940256099942544/2435281174"
        #else
        return Config.string("ADMOB_BANNER_UNIT_ID") ?? ""
        #endif
    }
}
