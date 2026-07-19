import SwiftUI

/// 상위 화면 라우트(헤더 메뉴 이동 대상).
enum AppRoute: Hashable {
    case clips
    case onboarding
    case about
    case faq
    case accountDelete
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
    var safari: SafariItem?

    func go(_ route: AppRoute) { path.append(route) }
    func home() { path.removeAll() }
    func openPrivacy() { safari = SafariItem(url: URL(string: "https://clipnote.co.kr/privacy")!) }
}
