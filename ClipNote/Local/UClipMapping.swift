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
            gradient: c.gradient, tags: c.tags, shared: c.shared, local: false
        )
    }

    /// 로컬 클립 → 통합 뷰 모델. id = url, 공유 불가(local=true).
    @MainActor
    init(_ c: LocalClip) {
        self.init(
            id: c.url, slug: nil, url: c.url, title: c.title,
            description: c.clipDescription, image: c.image, siteName: c.siteName,
            gradient: c.gradient, tags: c.tags, shared: false, local: true
        )
    }
}
