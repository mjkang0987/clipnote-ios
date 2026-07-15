import Testing
import Foundation
@testable import ClipNote

/// URLProtocol stub that returns queued (status, body) per request and records requests.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        StubURLProtocol.lastRequest = request
        StubURLProtocol.lastBody = request.httpBody
            ?? request.httpBodyStream.map { s -> Data in
                s.open(); defer { s.close() }
                var data = Data(); var buf = [UInt8](repeating: 0, count: 4096)
                while s.hasBytesAvailable { let n = s.read(&buf, maxLength: buf.count); if n <= 0 { break }; data.append(buf, count: n) }
                return data
            }
        let (status, body) = StubURLProtocol.handler?(request) ?? (500, Data())
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func stubbedClient() -> APIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return APIClient(baseURL: URL(string: "https://clipnote.co.kr")!,
                     session: URLSession(configuration: config))
}

@Suite struct APIClientTests {
    @Test func fetchMetadataParsesResponse() async throws {
        StubURLProtocol.handler = { _ in
            (200, #"{"url":"https://x.com","title":"T","description":"D","image":null,"siteName":"X","source":"og"}"#.data(using: .utf8)!)
        }
        let meta = try await stubbedClient().fetchMetadata(url: "https://x.com")
        #expect(meta.title == "T")
        #expect(meta.source == "og")
        #expect(StubURLProtocol.lastRequest?.url?.absoluteString.contains("/api/metadata?url=") == true)
    }

    @Test func createClipSendsBearerAndBody() async {
        StubURLProtocol.handler = { _ in
            (200, #"{"slug":"s1","shareUrl":"https://clipnote.co.kr/s1"}"#.data(using: .utf8)!)
        }
        let input = CreateClipInput(url: "https://x.com", title: "T",
            description: nil, image: nil, siteName: nil,
            tags: ["a"], gradient: "ocean", save: true)
        let res = await stubbedClient().createClip(input, accessToken: "tok123")
        #expect(res.shareUrl == "https://clipnote.co.kr/s1")
        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer tok123")
        let body = try! JSONSerialization.jsonObject(with: StubURLProtocol.lastBody ?? Data()) as! [String: Any]
        #expect(body["save"] as? Bool == true)
    }

    @Test func createClipReturnsErrorOnNon2xx() async {
        StubURLProtocol.handler = { _ in (401, #"{"error":"unauthorized"}"#.data(using: .utf8)!) }
        let input = CreateClipInput(url: "https://x.com", title: "T",
            description: nil, image: nil, siteName: nil, tags: nil, gradient: "ocean", save: nil)
        let res = await stubbedClient().createClip(input, accessToken: nil)
        #expect(res.error == "unauthorized")
    }

    @Test func getClipsFallsBackToEmptyOnFailure() async {
        StubURLProtocol.handler = { _ in (500, Data()) }
        let out = await stubbedClient().getClips(accessToken: "t")
        #expect(out.loggedIn == false)
        #expect(out.clips.isEmpty)
        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer t")
    }

    @Test func ogImageURLBuildsQuery() async {
        let url = await stubbedClient().ogImageURL(title: "제목 A", description: "설명",
            siteName: "Site", gradient: "grape")
        let s = url.absoluteString
        #expect(s.contains("/api/og?"))
        #expect(s.contains("g=grape"))
        #expect(s.contains("title=")) // percent-encoded
    }

    @Test func updateClipReturnsTrueOn2xx() async {
        StubURLProtocol.handler = { _ in (200, Data()) }
        let ok = await stubbedClient().updateClip(slug: "s1", title: "new",
            tags: ["x"], shared: nil, accessToken: "t")
        #expect(ok == true)
        #expect(StubURLProtocol.lastRequest?.httpMethod == "PATCH")
        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer t")
        let body = try! JSONSerialization.jsonObject(with: StubURLProtocol.lastBody ?? Data()) as! [String: Any]
        #expect(body["title"] as? String == "new")
        #expect(body["tags"] as? [String] == ["x"])
        #expect(body["shared"] == nil)
    }

    @Test func deleteClipUsesDeleteMethod() async {
        StubURLProtocol.handler = { _ in (200, Data()) }
        let ok = await stubbedClient().deleteClip(slug: "s1", accessToken: "t")
        #expect(ok == true)
        #expect(StubURLProtocol.lastRequest?.httpMethod == "DELETE")
        #expect(StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer t")
    }
}
