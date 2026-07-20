import Foundation

/// AdMob 설정. RN `lib/ads.ts` 이식.
/// DEBUG=구글 공식 테스트 unit(실광고 자가클릭 → 계정 정지 방지), RELEASE=Secrets 실 unit.
enum AdConfig {
    /// 배너 예약 높이(pt). 앵커 적응형은 기기폭 따라 50~90 변동 → 여유 64.
    static let bannerHeight: CGFloat = 64

    /// Info.plist에 주입된 AdMob App ID. 비어 있으면 SDK를 시작하지 않는다(크래시 방지).
    static var appID: String? { Config.string("GADApplicationIdentifier") }

    /// 광고 사용 가능 여부 — App ID가 설정된 빌드에서만.
    static var enabled: Bool { appID?.isEmpty == false }

    static var bannerUnitID: String {
        #if DEBUG
        // 구글 공식 iOS 적응형 배너 테스트 ID
        return "ca-app-pub-3940256099942544/2435281174"
        #else
        return Config.string("ADMOB_BANNER_UNIT_ID") ?? ""
        #endif
    }
}
