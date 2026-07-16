import Foundation

/// 자동 메타 추출을 시도할 만한 URL인지. RN `isFetchableUrl` 이식(host에 "." 포함).
func isFetchableUrl(_ raw: String) -> Bool {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty else { return false }
    let s = t.hasPrefix("http") ? t : "https://\(t)"
    guard let u = URL(string: s), let host = u.host else { return false }
    return host.contains(".")
}

/// 표시용 호스트+경로. RN `prettyHost` 이식(www. 제거, 루트 경로는 생략).
func prettyHost(_ raw: String) -> String {
    let s = raw.hasPrefix("http") ? raw : "https://\(raw)"
    guard let u = URL(string: s), let host = u.host else { return raw }
    let h = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    let path = u.path
    return h + (path != "/" && !path.isEmpty ? path : "")
}
