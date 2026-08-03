import Testing
import Foundation
import SwiftData
@testable import ClipNote

/// ClipsStore 전용 URLProtocol 스텁.
final class ClipsStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, body) = Self.handler?(request) ?? (500, Data())
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
@Suite(.serialized) struct ClipsStoreTests {
    private let base = URL(string: "https://clipnote.co.kr")!

    private func make() throws -> (ClipsStore, LocalClipStore) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalClip.self, configurations: config)
        let defaults = UserDefaults(suiteName: "t-\(UUID().uuidString)")!
        let local = LocalClipStore(container: container, defaults: defaults)
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [ClipsStubURLProtocol.self]
        let api = APIClient(baseURL: base, session: URLSession(configuration: cfg))
        return (ClipsStore(api: api, localStore: local, shareBase: base), local)
    }

    @Test func loadGuestMapsLocalClips() async throws {
        let (store, local) = try make()
        local.save(url: "https://a.com", title: "A", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["x"])
        await store.load(loggedIn: false, accessToken: nil)
        #expect(store.clips?.count == 1)
        #expect(store.clips?.first?.id == "https://a.com")
        #expect(store.clips?.first?.local == true)
    }

    @Test func loadLoggedInMapsDbClips() async throws {
        let (store, _) = try make()
        ClipsStubURLProtocol.handler = { _ in
            (200, #"{"loggedIn":true,"clips":[{"slug":"s1","url":"https://x.com","title":"T","description":"D","image":null,"siteName":"X","gradient":"grape","tags":["a"],"saved":true,"shared":false,"createdAt":"2026-01-01T00:00:00Z"}]}"#.data(using: .utf8)!)
        }
        await store.load(loggedIn: true, accessToken: "tok")
        #expect(store.clips?.count == 1)
        #expect(store.clips?.first?.id == "s1")
        #expect(store.clips?.first?.local == false)
    }

    @Test func allTagsDedupAndFilter() async throws {
        let (store, local) = try make()
        local.save(url: "https://1", title: "1", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["dev", "ui"])
        local.save(url: "https://2", title: "2", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["dev"])
        await store.load(loggedIn: false, accessToken: nil)
        #expect(Set(store.allTags) == ["dev", "ui"])
        store.activeTag = "ui"
        #expect(store.filtered.map(\.url) == ["https://1"])
        store.activeTag = nil
        #expect(store.filtered.count == 2)
    }

    @Test func applyTagsAddDedupCapsSix() async throws {
        let (store, local) = try make()
        local.save(url: "https://u1", title: "T", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["a", "b"])
        await store.load(loggedIn: false, accessToken: nil)
        await store.applyTags(ids: ["https://u1"], tags: ["b", "c", "d", "e", "f", "g"], mode: .add)
        #expect(store.clips?.first?.tags == ["a", "b", "c", "d", "e", "f"])
    }

    @Test func applyTagsReplaceCapsSix() async throws {
        let (store, local) = try make()
        local.save(url: "https://u1", title: "T", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["a", "b"])
        await store.load(loggedIn: false, accessToken: nil)
        await store.applyTags(ids: ["https://u1"], tags: ["x", "y"], mode: .replace)
        #expect(store.clips?.first?.tags == ["x", "y"])
    }

    @Test func saveEditLocalUpdatesTitleAndTags() async throws {
        let (store, local) = try make()
        local.save(url: "https://u1", title: "old", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["a"])
        await store.load(loggedIn: false, accessToken: nil)
        let clip = store.clips!.first!
        await store.saveEdit(clip, title: "new", tags: ["z"])
        #expect(store.clips?.first?.title == "new")
        #expect(store.clips?.first?.tags == ["z"])
    }

    @Test func deleteLocalRemovesClip() async throws {
        let (store, local) = try make()
        local.save(url: "https://u1", title: "T", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: [])
        await store.load(loggedIn: false, accessToken: nil)
        await store.delete(store.clips!.first!)
        #expect(store.clips?.isEmpty == true)
    }

    @Test func shareTextUsesBuildShareTextForDbClip() throws {
        let (store, _) = try make()
        let db = DbClip(slug: "s1", url: "https://x.com", title: "제목", description: "설명",
                        image: nil, siteName: nil, gradient: "grape", tags: [],
                        saved: true, shared: true, createdAt: "2026-01-01T00:00:00Z")
        let text = store.shareText(UClip(db))
        // 설명(description)은 붙여넣기 글이 길어져 제외한다(#74/PR #75, buildShareText).
        // DbClip에 description을 넣어도 결과엔 빠지는지 확인.
        #expect(text == "제목\nhttps://clipnote.co.kr/s1")
    }

    @MainActor
    @Test func shareTextNilForLocalClip() throws {
        let (store, local) = try make()
        local.save(url: "https://x.com", title: "T", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: [])
        let clip = UClip(local.all().first!)
        #expect(store.shareText(clip) == nil)
    }

    @Test func makeSharedReturnsTrueOn2xx() async throws {
        let (store, _) = try make()
        ClipsStubURLProtocol.handler = { req in
            if req.httpMethod == "PATCH" { return (200, Data()) }
            return (200, #"{"loggedIn":true,"clips":[]}"#.data(using: .utf8)!)
        }
        await store.load(loggedIn: true, accessToken: "tok")
        let db = DbClip(slug: "s1", url: "https://x.com", title: "T", description: nil,
                        image: nil, siteName: nil, gradient: "grape", tags: [],
                        saved: true, shared: false, createdAt: "2026-01-01T00:00:00Z")
        let ok = await store.makeShared(UClip(db))
        #expect(ok == true)
    }

    /// 로그인 목록은 **계정 클립만** 보여 주고, 이 기기 클립은 개수로만 알린다.
    ///
    /// 한 목록에 섞었다가 되돌린 자리다. 섞으면 공유 링크를 만들 수 없는 줄이 만들 수 있는 줄과
    /// 나란히 서서 눌러 보고 나서야 안 되는 걸 알게 된다. 대신 목록 위에 ‘이 기기에 남은 클립
    /// n개’ 진입 줄을 세우고 `LocalClipsView` 로 보낸다 — 그 줄이 쓰는 값이 `localOnlyCount` 다.
    @Test func loggedInListIsAccountOnlyAndCountsLocal() async throws {
        let (store, local) = try make()
        local.save(url: "https://only-local.com", title: "L", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: [])
        ClipsStubURLProtocol.handler = { _ in
            (200, #"{"loggedIn":true,"clips":[{"slug":"s1","url":"https://x.com","title":"T","description":null,"image":null,"siteName":null,"gradient":"grape","tags":[],"saved":true,"shared":false,"createdAt":"2026-01-01T00:00:00Z"}]}"#.data(using: .utf8)!)
        }
        await store.load(loggedIn: true, accessToken: "tok")
        #expect(store.clips?.map(\.id) == ["s1"])
        #expect(store.localOnlyCount == 1)
    }

    /// 게스트 목록은 그 자체가 로컬이라 진입 줄이 설 이유가 없다 — 같은 클립을 두 번 세게 된다.
    @Test func guestLoadKeepsLocalCountAtZero() async throws {
        let (store, local) = try make()
        local.save(url: "https://a.com", title: "A", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: [])
        await store.load(loggedIn: false, accessToken: nil)
        #expect(store.clips?.count == 1)
        #expect(store.localOnlyCount == 0)
    }

    @Test func clipsRefreshEmitFiresObserver() {
        final class Box: @unchecked Sendable { var fired = false }
        let box = Box()
        // queue: nil → 게시 스레드에서 동기 전달.
        let token = NotificationCenter.default.addObserver(
            forName: ClipsRefresh.name, object: nil, queue: nil) { _ in box.fired = true }
        ClipsRefresh.emit()
        NotificationCenter.default.removeObserver(token)
        #expect(box.fired == true)
    }
}
