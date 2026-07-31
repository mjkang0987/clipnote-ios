import Foundation
import Observation

enum TagMode { case add, replace }

/// 내 클립 목록 상태·로직. RN `app/clips.tsx` 이식. 로컬(게스트)/DB(로그인) 통합.
@MainActor
@Observable
final class ClipsStore {
    /// nil = 로딩 중.
    private(set) var clips: [UClip]?

    /// 목록에 있는 모든 태그(순서 보존·중복 제거).
    ///
    /// **목록이 바뀔 때 한 번만 계산한다.** 전에는 계산 프로퍼티라 접근할 때마다 전체를 훑었는데,
    /// 필터 칩과 `filtered` 가 각각 읽어서 렌더 한 번에 클립 수만큼을 두 번씩 순회했다.
    private(set) var allTags: [String] = []

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
            apply(db.map(UClip.init))
        } else {
            apply(localStore.all().map(UClip.init))
        }
    }

    /// 목록과 그로부터 나오는 값을 함께 갱신한다. 목록은 여기서만 바뀐다.
    private func apply(_ next: [UClip]) {
        clips = next
        allTags = orderedUnique(next.flatMap(\.tags))
    }

    func reload() async {
        await load(loggedIn: ctx.loggedIn, accessToken: ctx.token)
    }

    // MARK: - Derived

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

    /// 다중선택 일괄 삭제.
    ///
    /// 서버 왕복을 **동시에** 보낸다. 전에는 순차 `await` 라 10개를 지우면 왕복 10번을 줄줄이
    /// 기다렸다 — 모바일 네트워크에서 체감이 크다. 대상 조회도 매번 배열을 훑는 대신 사전을 쓴다.
    func bulkDelete(ids: [String]) async {
        let targets = lookup(ids)
        guard !targets.isEmpty else { return }
        await forEachConcurrently(targets) { await self.removeOne($0) }
        await reload()
    }

    /// id 목록을 클립으로 바꾼다. `ids` 하나마다 배열을 훑으면 선택이 늘수록 제곱으로 느려진다.
    private func lookup(_ ids: [String]) -> [UClip] {
        guard let clips else { return [] }
        let byID = Dictionary(clips.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    /// 동시에 띄울 요청 수 상한. 무제한으로 풀면 선택이 많을 때(로컬 캡 300개) 서버를 때린다.
    private static let maxInFlight = 6

    /// 각 클립에 대해 `work` 를 **동시에, 그러나 상한을 두고** 실행한다.
    /// 하나 끝날 때마다 다음 하나를 띄운다.
    private func forEachConcurrently(
        _ clips: [UClip],
        _ work: @escaping @Sendable (UClip) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            var pending = clips.makeIterator()
            for _ in 0..<min(Self.maxInFlight, clips.count) {
                guard let clip = pending.next() else { break }
                group.addTask { await work(clip) }
            }
            while await group.next() != nil {
                guard let clip = pending.next() else { continue }
                group.addTask { await work(clip) }
            }
        }
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
    /// 삭제와 같은 이유로 서버 왕복을 동시에 보낸다.
    func applyTags(ids: [String], tags: [String], mode: TagMode) async {
        let targets = lookup(ids)
        guard !targets.isEmpty else { return }
        await forEachConcurrently(targets) { clip in
            let next: [String]
            switch mode {
            case .add: next = Array(orderedUnique(clip.tags + tags).prefix(6))
            case .replace: next = Array(tags.prefix(6))
            }
            await self.applyTags(to: clip, tags: next)
        }
        await reload()
    }

    private func applyTags(to clip: UClip, tags: [String]) async {
        if clip.local {
            localStore.update(url: clip.url, title: nil, tags: tags)
        } else if let slug = clip.slug {
            _ = await api.updateClip(slug: slug, title: nil, tags: tags, shared: nil, accessToken: ctx.token)
        }
    }
}

/// 순서 보존 중복 제거.
func orderedUnique(_ arr: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for x in arr where seen.insert(x).inserted { out.append(x) }
    return out
}
