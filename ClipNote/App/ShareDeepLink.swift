import Foundation

/// 공유 확장(Share Extension)이 여는 `clipnote://share?url=<원본>` 딥링크 파서.
/// auth 딥링크(`clipnote://auth/...`)와 별개 — 홈 입력칸에 URL만 채운다(저장 X).
enum ShareDeepLink {
    static func parse(_ url: URL) -> String? {
        guard url.scheme == "clipnote",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.host == "share" else { return nil }
        return comps.queryItems?
            .first { $0.name == "url" }?
            .value
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}
