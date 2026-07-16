import Testing
import Foundation
@testable import ClipNote

/// 홈 VM 전용 URLProtocol 스텁(APIClientTests와 static 충돌 회피).
final class HomeStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var status = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let resp = HTTPURLResponse(url: request.url!, statusCode: Self.status,
                                   httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
@Suite(.serialized) struct HomeViewModelTests {
    private func makeVM() -> HomeViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HomeStubURLProtocol.self]
        let api = APIClient(baseURL: URL(string: "https://clipnote.co.kr")!,
                            session: URLSession(configuration: config))
        return HomeViewModel(api: api)
    }

    @Test func loadMetaSetsMetaAndAutofillsTitle() async {
        HomeStubURLProtocol.status = 200
        HomeStubURLProtocol.body = #"{"url":"https://x.com","title":"자동제목","description":"D","image":null,"siteName":"X","source":"og"}"#.data(using: .utf8)!
        let vm = makeVM()
        vm.url = "https://example.com/a"
        await vm.loadMeta("https://example.com/a")
        #expect(vm.meta?.title == "자동제목")
        #expect(vm.title == "자동제목")
        #expect(vm.loading == false)
    }

    @Test func loadMetaKeepsUserTitle() async {
        HomeStubURLProtocol.status = 200
        HomeStubURLProtocol.body = #"{"url":"https://x.com","title":"메타제목","description":null,"image":null,"siteName":null,"source":"og"}"#.data(using: .utf8)!
        let vm = makeVM()
        vm.title = "내가쓴제목"
        await vm.loadMeta("https://example.com/a")
        #expect(vm.title == "내가쓴제목")
    }

    @Test func loadMetaFailureSetsError() async {
        HomeStubURLProtocol.status = 500
        HomeStubURLProtocol.body = Data()
        let vm = makeVM()
        await vm.loadMeta("https://example.com/a")
        #expect(vm.meta == nil)
        #expect(vm.errorMessage != nil)
    }

    @Test func tagsParsedFromInput() {
        let vm = makeVM()
        vm.tagInput = "a, b ,c"
        #expect(vm.tags == ["a", "b", "c"])
    }

    @Test func resolvedTitleFallsBackToHost() {
        let vm = makeVM()
        vm.url = "https://www.example.com/post"
        #expect(vm.resolvedTitle == "example.com/post")
    }

    @Test func resolvedTitleEmptyWhenNoInput() {
        let vm = makeVM()
        #expect(vm.resolvedTitle == "")
    }

    @Test func createShareReturnsResultOnSuccess() async {
        HomeStubURLProtocol.status = 200
        HomeStubURLProtocol.body = #"{"slug":"s1","shareUrl":"https://clipnote.co.kr/s1"}"#.data(using: .utf8)!
        let vm = makeVM()
        vm.url = "https://example.com/a"
        vm.title = "제목"
        let res = await vm.createShare(accessToken: "tok")
        #expect(res?.shareUrl == "https://clipnote.co.kr/s1")
    }

    @Test func createShareRequiresTitle() async {
        let vm = makeVM()
        let res = await vm.createShare(accessToken: "tok")
        #expect(res == nil)
        #expect(vm.errorMessage != nil)
    }
}
