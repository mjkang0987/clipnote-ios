import Foundation
import SwiftData

/// 비로그인 로컬 클립 저장소. RN `lib/local-clips.ts` 이식.
/// 규칙: 같은 url 최신으로 upsert · 최대 300개 · 최신순. knownTags는 UserDefaults 빈도맵.
@MainActor
final class LocalClipStore {
    private let context: ModelContext
    private let defaults: UserDefaults
    private let maxClips: Int
    private let tagsKey = "clipnote.knownTags.v1"

    init(container: ModelContainer, defaults: UserDefaults = .standard, maxClips: Int = 300) {
        self.context = ModelContext(container)
        self.defaults = defaults
        self.maxClips = maxClips
    }

    /// 최신순(savedAt 내림차순) 전체.
    func all() -> [LocalClip] {
        let d = FetchDescriptor<LocalClip>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        return (try? context.fetch(d)) ?? []
    }

    /// 저장(같은 url은 최신으로 갱신). 최대 개수 초과 시 오래된 것 제거.
    @discardableResult
    func save(
        url: String,
        title: String,
        description: String?,
        image: String?,
        siteName: String?,
        gradient: String,
        tags: [String]
    ) -> [LocalClip] {
        deleteEntries(url: url)
        context.insert(LocalClip(
            url: url, title: title, clipDescription: description,
            image: image, siteName: siteName, gradient: gradient,
            tags: tags, savedAt: Date()
        ))
        enforceCap()
        recordTags(tags)
        try? context.save()
        return all()
    }

    func delete(url: String) {
        deleteEntries(url: url)
        try? context.save()
    }

    /// 단건 편집 — 주어진 필드만 갱신(제목·태그). RN `updateLocalClip` 이식.
    func update(url: String, title: String?, tags: [String]?) {
        let d = FetchDescriptor<LocalClip>(predicate: #Predicate { $0.url == url })
        guard let clip = try? context.fetch(d).first else { return }
        if let title { clip.title = title }
        if let tags {
            clip.tags = tags
            recordTags(tags)
        }
        try? context.save()
    }

    /// 로그인 마이그레이션 후 로컬 클립 전체 비우기.
    func clearLocalClips() {
        try? context.delete(model: LocalClip.self)
        try? context.save()
    }

    /// 자주 쓴 순으로 정렬된 과거 태그(자동완성용).
    func knownTags() -> [String] {
        tagMap().sorted { $0.value > $1.value }.map(\.key)
    }

    // MARK: - Private

    private func deleteEntries(url: String) {
        let d = FetchDescriptor<LocalClip>(predicate: #Predicate { $0.url == url })
        for clip in (try? context.fetch(d)) ?? [] { context.delete(clip) }
    }

    private func enforceCap() {
        let all = all()
        guard all.count > maxClips else { return }
        for clip in all[maxClips...] { context.delete(clip) }
    }

    private func tagMap() -> [String: Int] {
        var map: [String: Int] = [:]
        for (k, v) in defaults.dictionary(forKey: tagsKey) ?? [:] {
            if let n = v as? Int { map[k] = n }
        }
        return map
    }

    private func recordTags(_ tags: [String]) {
        var map = tagMap()
        var changed = false
        for tag in tags {
            let key = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            map[key, default: 0] += 1
            changed = true
        }
        if changed { defaults.set(map, forKey: tagsKey) }
    }
}
