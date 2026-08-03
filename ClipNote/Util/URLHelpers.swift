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

/// 중복 판정용 정규화 — "사람 눈에 같은" 주소를 같은 문자열로 만든다.
///
/// 웹 `lib/metadata.ts` 의 `canonicalizeUrl` 이식. **서버가 저장할 때 쓰는 규칙과 같아야
/// 한다** — 로그인 목록에서 서버 사본과 이 기기 사본을 겹쳐 보일 때, 규칙이 다르면 같은
/// 링크가 두 줄로 남는다.
///
/// - 호스트 소문자, 기본 포트 제거
/// - 끝 슬래시 제거(루트 제외)
/// - 광고·추적 파라미터 제거(`utm_*` 와 아래 목록)
///
/// `www` 는 건드리지 않는다 — 사이트에 따라 리다이렉트가 깨질 수 있어 웹도 보수적으로 둔다.
func canonicalURLKey(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let base = trimmed.range(of: "^https?://", options: [.regularExpression, .caseInsensitive]) != nil
        ? trimmed : "https://\(trimmed)"
    guard var comps = URLComponents(string: base) else { return base }

    comps.host = comps.host?.lowercased()
    if (comps.scheme == "https" && comps.port == 443) || (comps.scheme == "http" && comps.port == 80) {
        comps.port = nil
    }
    if let items = comps.queryItems {
        let kept = items.filter { item in
            let name = item.name.lowercased()
            return !name.hasPrefix("utm_") && !trackingParams.contains(name)
        }
        comps.queryItems = kept.isEmpty ? nil : kept
    }
    if comps.path.count > 1, comps.path.hasSuffix("/") {
        comps.path = String(comps.path.reversed().drop(while: { $0 == "/" }).reversed())
    }
    return comps.string ?? base
}

private let trackingParams: Set<String> = [
    "fbclid", "gclid", "gclsrc", "dclid", "msclkid", "yclid", "igshid",
    "mc_eid", "mc_cid", "_hsenc", "_hsmi", "spm",
]
