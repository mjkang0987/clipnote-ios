import Foundation

struct ClipMetadata: Codable, Equatable {
    let url: String
    let title: String?
    let description: String?
    let image: String?
    let siteName: String?
    let source: String
    let reason: String?
}

struct DbClip: Codable, Equatable, Identifiable {
    let slug: String
    let url: String
    let title: String
    let description: String?
    let image: String?
    let siteName: String?
    let gradient: String
    let tags: [String]
    let saved: Bool
    let shared: Bool
    let createdAt: String
    var id: String { slug }
}

struct CreateClipInput: Codable {
    let url: String
    let title: String
    var description: String?
    var image: String?
    var siteName: String?
    var tags: [String]?
    var gradient: String
    var save: Bool?

    enum CodingKeys: String, CodingKey {
        case url, title, description, image, siteName, tags, gradient, save
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(url, forKey: .url)
        try c.encode(title, forKey: .title)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(image, forKey: .image)
        try c.encodeIfPresent(siteName, forKey: .siteName)
        try c.encodeIfPresent(tags, forKey: .tags)
        try c.encode(gradient, forKey: .gradient)
        try c.encodeIfPresent(save, forKey: .save)
    }
}

struct DeleteAccountResult: Codable, Equatable {
    let ok: Bool
    let error: String?
}

struct CreateClipResult: Codable {
    let slug: String?
    let shareUrl: String?
    let alreadySaved: Bool?
    let error: String?
}

/// Unified view model over local (AsyncStorage-equivalent) and DB clips.
/// `id` = slug for DB clips, url for local clips.
struct UClip: Identifiable, Equatable {
    let id: String
    let slug: String?
    let url: String
    let title: String
    let description: String?
    let image: String?
    let siteName: String?
    let gradient: String
    let tags: [String]
    let shared: Bool
    let local: Bool
    /// 저장 시각. 목록을 날짜로 묶는 데 쓴다(웹과 같은 구성).
    ///
    /// DB 클립은 `createdAt`(ISO 문자열), 로컬 클립은 `savedAt` 에서 온다. 전에는 통합
    /// 모델이 이 값을 버려서 앱만 날짜 그룹이 없었다.
    let savedAt: Date
}
