import Foundation

/// 자동 메타 추출을 시도할 만한 URL인지. RN `isFetchableUrl` 이식(host에 "." 포함).
func isFetchableUrl(_ raw: String) -> Bool {
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty else { return false }
    let s = t.hasPrefix("http") ? t : "https://\(t)"
    guard let u = URL(string: s), let host = u.host else { return false }
    return host.contains(".")
}

/// 원본 대표 이미지를 서버 프록시(`/api/image`)로 감싼 URL.
/// 앱이 원본을 직접 부르면 hotlink·referer·혼합콘텐츠(http)로 자주 막혀서 우리 서버를 거쳐 불러온다
/// (네이버 CDN referer 처리 포함). 웹 clipnote bfdc553/c03c97e와 동일. 저장되는 원본 값은 그대로 유지.
func proxiedImageURL(_ original: String?, base: URL = Config.apiBase) -> URL? {
    guard let s = original?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
    var comps = URLComponents(url: base.appendingPathComponent("api/image"), resolvingAgainstBaseURL: false)
    comps?.queryItems = [URLQueryItem(name: "url", value: s)]
    return comps?.url
}

/// 표시용 호스트+경로. RN `prettyHost` 이식(www. 제거, 루트 경로는 생략).
func prettyHost(_ raw: String) -> String {
    let s = raw.hasPrefix("http") ? raw : "https://\(raw)"
    guard let u = URL(string: s), let host = u.host else { return raw }
    let h = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    let path = u.path
    return h + (path != "/" && !path.isEmpty ? path : "")
}
