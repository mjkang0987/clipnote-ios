import Foundation

/// Parsed auth deep link. Ports RN `.onOpenURL` routing (설계 §3.7).
/// - `clipnote://auth/callback?code=...`  → Supabase OAuth code 교환 (Google/Kakao)
/// - `clipnote://auth/naver?token_hash=...` → 네이버 magiclink verify
enum AuthDeepLink: Equatable {
    case oauthCallback(code: String)
    case naver(tokenHash: String)

    static let scheme = "clipnote"

    /// Returns the route for a `clipnote://auth/...` URL, or nil if it is not an auth link.
    static func parse(_ url: URL) -> AuthDeepLink? {
        guard url.scheme == scheme,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.host == "auth" else { return nil }

        func query(_ name: String) -> String? {
            comps.queryItems?.first { $0.name == name }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }

        switch comps.path {
        case "/callback":
            return query("code").map(AuthDeepLink.oauthCallback)
        case "/naver":
            return query("token_hash").map(AuthDeepLink.naver)
        default:
            return nil
        }
    }
}
