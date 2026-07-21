import Foundation

/// Reads build-time configuration injected into Info.plist from `Secrets.xcconfig`.
/// Values are surfaced under top-level Info.plist keys (see `project.yml` `info.properties`).
enum Config {
    static func string(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else { return nil }
        return value
    }

    static var apiBase: URL {
        // 설정값이 깨져(host 없음) 있으면 강제 언래핑 크래시 대신 기본값으로 폴백.
        if let s = string("API_BASE"), let url = URL(string: s), url.host() != nil { return url }
        return URL(string: "https://clipnote.co.kr")!
    }

    /// host가 없는(깨진) URL이면 nil — AuthStore가 disabled로 폴백해 앱이 켜자마자 죽지 않게 한다.
    static var supabaseURL: URL? {
        guard let url = string("SUPABASE_URL").flatMap(URL.init(string:)), url.host() != nil else { return nil }
        return url
    }

    static var supabaseAnonKey: String? {
        string("SUPABASE_ANON_KEY")
    }

    static var naverClientID: String? {
        string("NAVER_CLIENT_ID")
    }
}
