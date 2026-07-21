import SwiftUI

/// 상위 화면 라우트(헤더 메뉴 이동 대상).
enum AppRoute: Hashable {
    case clips
    case about
    case faq
    case privacy
    case accountDelete
    case settings
}

/// `.sheet(item:)`용 URL 래퍼(개인정보 웹뷰 등).
struct SafariItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// 앱 내비게이션 상태. 헤더 메뉴가 조작하고 RootView가 소유.
@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = []
    var showLogin = false
    /// 사용법(투어)은 모달로 띄운다 — navigationDestination으로 push하면 OnboardingView 내부의
    /// NavigationStack이 RootView NavigationStack에 중첩돼 크래시. 첫 실행 온보딩과 같은 토폴로지 유지.
    var showTour = false
    var safari: SafariItem?
    /// 공유 확장이 넘긴 URL — 홈 입력칸에 채우고 소비 후 nil. (§공유 확장)
    var pendingSharedURL: String?

    func go(_ route: AppRoute) { path.append(route) }
    func home() { path.removeAll() }
    func openPrivacy() { safari = SafariItem(url: URL(string: "https://clipnote.co.kr/privacy")!) }
}
