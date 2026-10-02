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

    // MARK: - 검색 (#120)

    /// 검색 대상은 제목·URL·태그. 카드에 보이는 것으로 찾을 수 있어야 한다.
    @Test func searchMatchesTitleUrlAndTag() async throws {
        let (store, local) = try make()
        local.save(url: "https://news.example.com/a", title: "경제 브리핑", description: nil,
                   image: nil, siteName: nil, gradient: "ocean", tags: ["뉴스"])
        local.save(url: "https://github.com/vercel/next.js", title: "릴리스 노트", description: nil,
                   image: nil, siteName: nil, gradient: "ocean", tags: ["개발"])
        await store.load(loggedIn: false, accessToken: nil)

        store.query = "브리핑"                               // 제목
        #expect(store.filtered.map(\.title) == ["경제 브리핑"])
        store.query = "github"                              // URL (제목엔 없다)
        #expect(store.filtered.map(\.title) == ["릴리스 노트"])
        store.query = "뉴스"                                 // 태그 (제목·URL 엔 없다)
        #expect(store.filtered.map(\.title) == ["경제 브리핑"])
    }

    /// 대소문자를 가리지 않고, 앞뒤 공백만 있는 검색어는 안 건 것으로 본다.
    @Test func searchIgnoresCaseAndBlankQuery() async throws {
        let (store, local) = try make()
        local.save(url: "https://a.com", title: "Frontend 정리", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: [])
        local.save(url: "https://b.com", title: "백엔드 정리", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: [])
        await store.load(loggedIn: false, accessToken: nil)

        store.query = "FRONTEND"
        #expect(store.filtered.map(\.title) == ["Frontend 정리"])
        store.query = "   "
        #expect(store.filtered.count == 2)
        store.query = ""
        #expect(store.filtered.count == 2)
    }

    /// 태그와 검색어는 **함께** 건다. 한쪽이 다른 쪽을 지우면 태그를 고른 채로는 검색할 수 없다.
    @Test func searchAndTagNarrowTogether() async throws {
        let (store, local) = try make()
        local.save(url: "https://1", title: "디자인 토큰", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["개발"])
        local.save(url: "https://2", title: "릴리스 노트", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["개발"])
        local.save(url: "https://3", title: "디자인 레퍼런스", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["기타"])
        await store.load(loggedIn: false, accessToken: nil)

        store.activeTag = "개발"
        #expect(store.filtered.count == 2)
        store.query = "디자인"
        #expect(store.filtered.map(\.title) == ["디자인 토큰"])   // 둘 다 만족하는 것만
        store.query = "없는말"
        #expect(store.filtered.isEmpty)
        store.query = ""
        #expect(store.filtered.count == 2)                      // 검색어만 풀면 태그는 남는다
    }

    /// 선택한 뒤 목록을 좁히면, **화면에 없는 선택은 지우지 않는다.**
    ///
    /// 일괄 삭제가 전체 목록에서 대상을 찾으면 보이지 않는 클립까지 지운다 — 되돌릴 수 없다.
    /// 잊지는 않는다: 호출부의 선택은 그대로라, 필터를 풀면 다시 대상이 된다.
    @Test func bulkDeleteSkipsClipsHiddenByFilter() async throws {
        let (store, local) = try make()
        local.save(url: "https://keep.com", title: "남을 것", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: [])
        local.save(url: "https://gone.com", title: "지울 것", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: [])
        await store.load(loggedIn: false, accessToken: nil)

        store.query = "지울"                                  // ‘남을 것’ 은 화면에서 사라진다
        #expect(store.visibleSelectedCount(["https://keep.com", "https://gone.com"]) == 1)

        await store.bulkDelete(ids: ["https://keep.com", "https://gone.com"])
        #expect(local.all().map(\.url) == ["https://keep.com"])
    }

    /// 같은 규칙이 태그 일괄 적용에도 걸린다 — 안 보이는 클립의 태그를 바꾸지 않는다.
    @Test func applyTagsSkipsClipsHiddenByFilter() async throws {
        let (store, local) = try make()
        local.save(url: "https://1", title: "보이는 것", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["a"])
        local.save(url: "https://2", title: "숨은 것", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["a"])
        await store.load(loggedIn: false, accessToken: nil)

        store.query = "보이는"
        await store.applyTags(ids: ["https://1", "https://2"], tags: ["z"], mode: .replace)

        let byURL = Dictionary(uniqueKeysWithValues: local.all().map { ($0.url, $0.tags) })
        #expect(byURL["https://1"] == ["z"])
        #expect(byURL["https://2"] == ["a"])
    }

    /// 목록이 바뀌어 사라진 태그는 **안 건 것**으로 본다.
    ///
    /// 빈 상태 문구가 이 값을 읽는다 — `activeTag` 를 그대로 보면 걸리지도 않은 필터를 탓한다.
    @Test func effectiveTagDropsTagMissingFromList() async throws {
        let (store, local) = try make()
        local.save(url: "https://1", title: "T", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["개발"])
        await store.load(loggedIn: false, accessToken: nil)
        store.activeTag = "개발"
        #expect(store.effectiveTag == "개발")

        // 그 태그를 떼면 목록에서 사라진다 — 필터가 걸린 채로 남아선 안 된다.
        await store.saveEdit(store.clips!.first!, title: "T", tags: [])
        #expect(store.effectiveTag == nil)
        #expect(store.filtered.count == 1)
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
