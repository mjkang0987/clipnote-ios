import Foundation
import Observation

enum TagMode { case add, replace }

/// 내 클립 목록 상태·로직. RN `app/clips.tsx` 이식. 로컬(게스트)/DB(로그인) 통합.
@MainActor
@Observable
final class ClipsStore {
    /// nil = 로딩 중.
    private(set) var clips: [UClip]?
    var activeTag: String?

    private let api: APIClient
    private let localStore: LocalClipStore
    private let shareBase: URL
    /// 마지막 로드 컨텍스트 — 변경 후 reload에 사용.
    private var ctx: (loggedIn: Bool, token: String?) = (false, nil)

    init(api: APIClient = .shared, localStore: LocalClipStore, shareBase: URL = Config.apiBase) {
        self.api = api
        self.localStore = localStore
        self.shareBase = shareBase
    }

    // MARK: - Load

    func load(loggedIn: Bool, accessToken: String?) async {
        ctx = (loggedIn, accessToken)
        if loggedIn {
            let (_, db) = await api.getClips(accessToken: accessToken)
            clips = db.map(UClip.init)
        } else {
            clips = localStore.all().map(UClip.init)
        }
    }

    func reload() async {
        await load(loggedIn: ctx.loggedIn, accessToken: ctx.token)
    }

    // MARK: - Derived

    var allTags: [String] {
        orderedUnique((clips ?? []).flatMap(\.tags))
    }

    var filtered: [UClip] {
        guard let clips else { return [] }
        if let t = activeTag, allTags.contains(t) {
            return clips.filter { $0.tags.contains(t) }
        }
        return clips
    }

    /// 공유 복사 텍스트(§4.3) — 제목+브릿지 링크(설명 제외, #74/PR #75). 로컬 클립은 slug 없어 nil.
    func shareText(_ c: UClip) -> String? {
        guard let slug = c.slug else { return nil }
        let url = shareBase.appendingPathComponent(slug).absoluteString
        return buildShareText(title: c.title, description: c.description, url: url)
    }

    // MARK: - Mutations (각자 reload로 마무리)

    func removeOne(_ c: UClip) async {
        if c.local {
            localStore.delete(url: c.url)
        } else if let slug = c.slug {
            _ = await api.deleteClip(slug: slug, accessToken: ctx.token)
        }
    }

    func delete(_ c: UClip) async {
        await removeOne(c)
        await reload()
    }

    func bulkDelete(ids: [String]) async {
        guard let clips else { return }
        for id in ids {
            if let c = clips.first(where: { $0.id == id }) { await removeOne(c) }
        }
        await reload()
    }

    func saveEdit(_ c: UClip, title: String, tags: [String]) async {
        if c.local {
            localStore.update(url: c.url, title: title, tags: tags)
        } else if let slug = c.slug {
            _ = await api.updateClip(slug: slug, title: title, tags: tags, shared: nil, accessToken: ctx.token)
        }
        await reload()
    }

    /// 공유 링크 켜기(shared=true). 성공 시 reload.
    func makeShared(_ c: UClip) async -> Bool {
        guard let slug = c.slug else { return false }
        let ok = await api.updateClip(slug: slug, title: nil, tags: nil, shared: true, accessToken: ctx.token)
        if ok { await reload() }
        return ok
    }

    /// 다중선택 태그 일괄. add=기존∪신규(dedup·최대6), replace=신규(최대6).
    func applyTags(ids: [String], tags: [String], mode: TagMode) async {
        guard let clips else { return }
        for id in ids {
            guard let c = clips.first(where: { $0.id == id }) else { continue }
            let next: [String]
            switch mode {
            case .add: next = Array(orderedUnique(c.tags + tags).prefix(6))
            case .replace: next = Array(tags.prefix(6))
            }
            if c.local {
                localStore.update(url: c.url, title: nil, tags: next)
            } else if let slug = c.slug {
                _ = await api.updateClip(slug: slug, title: nil, tags: next, shared: nil, accessToken: ctx.token)
            }
        }
        await reload()
    }
}

/// 순서 보존 중복 제거.
func orderedUnique(_ arr: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for x in arr where seen.insert(x).inserted { out.append(x) }
    return out
}
