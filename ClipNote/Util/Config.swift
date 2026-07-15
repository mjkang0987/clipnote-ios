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
        URL(string: string("API_BASE") ?? "https://clipnote.co.kr")!
    }

    static var supabaseURL: URL? {
        string("SUPABASE_URL").flatMap(URL.init(string:))
    }

    static var supabaseAnonKey: String? {
        string("SUPABASE_ANON_KEY")
    }

    static var naverClientID: String? {
        string("NAVER_CLIENT_ID")
    }
}
