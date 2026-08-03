import Foundation

/// 태그 입력 파싱: 쉼표 구분 · 트림 · 빈값 제거 · 최대 6개. RN `app/index.tsx` tags 로직 이식.
func parseTags(_ input: String) -> [String] {
    let cleaned: [String] = input
        .split(separator: ",", omittingEmptySubsequences: false)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    return Array(cleaned.prefix(6))
}

extension UClip {
    /// DB 클립 → 통합 뷰 모델. id = slug.
    init(_ c: DbClip) {
        self.init(
            id: c.slug, slug: c.slug, url: c.url, title: c.title,
            description: c.description, image: c.image, siteName: c.siteName,
            gradient: c.gradient, tags: c.tags, shared: c.shared, local: false,
            savedAt: parseISODate(c.createdAt) ?? .distantPast
        )
    }

    /// 로컬 클립 → 통합 뷰 모델. id = url, 공유 불가(local=true).
    @MainActor
    init(_ c: LocalClip) {
        self.init(
            id: c.url, slug: nil, url: c.url, title: c.title,
            description: c.clipDescription, image: c.image, siteName: c.siteName,
            gradient: c.gradient, tags: c.tags, shared: false, local: true,
            savedAt: c.savedAt
        )
    }
}

/// 서버가 준 ISO 시각 문자열을 `Date` 로.
///
/// Supabase 의 `timestamptz` 는 소수점 이하가 **여섯 자리**로 오는데
/// (`2026-07-30T04:19:12.345678+00:00`), `ISO8601DateFormatter` 는 세 자리를 기대해
/// `.withFractionalSeconds` 를 켜도 실패한다. 실패하면 소수부를 떼고 다시 읽는다 —
/// 날짜 그룹에 초 이하는 필요 없다.
func parseISODate(_ text: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: text) { return date }

    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    if let date = plain.date(from: text) { return date }

    guard let dot = text.firstIndex(of: "."),
          let zoneStart = text[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" })
    else { return nil }
    return plain.date(from: String(text[..<dot]) + String(text[zoneStart...]))
}
