import Testing
import Foundation
import SwiftData
@testable import ClipNote

/// 마이그레이션 전용 스텁 — 호출 순서별 응답.
final class MigrateStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [(Int, Data)] = []
    nonisolated(unsafe) static var callCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let idx = min(Self.callCount, Self.responses.count - 1)
        let (status, body) = Self.responses.isEmpty ? (500, Data()) : Self.responses[idx]
        Self.callCount += 1
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
@Suite(.serialized) struct MigrateLocalClipsTests {
    private func make() throws -> (MigrateLocalClips, LocalClipStore) {
        MigrateStubURLProtocol.callCount = 0
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalClip.self, configurations: config)
        let defaults = UserDefaults(suiteName: "m-\(UUID().uuidString)")!
        let local = LocalClipStore(container: container, defaults: defaults)
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MigrateStubURLProtocol.self]
        let api = APIClient(baseURL: URL(string: "https://clipnote.co.kr")!,
                            session: URLSession(configuration: cfg))
        return (MigrateLocalClips(api: api, localStore: local), local)
    }

    @Test func inputMapsFieldsWithSaveTrue() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalClip.self, configurations: config)
        let clip = LocalClip(url: "https://x.com", title: "T", clipDescription: "D",
                             image: "https://img", siteName: "X", gradient: "grape",
                             tags: ["a"], savedAt: Date())
        container.mainContext.insert(clip)
        let input = MigrateLocalClips.input(from: clip)
        #expect(input.url == "https://x.com")
        #expect(input.title == "T")
        #expect(input.description == "D")
        #expect(input.tags == ["a"])
        #expect(input.gradient == "grape")
        #expect(input.save == true)
    }

    @Test func runUploadsAllAndClears() async throws {
        let (mig, local) = try make()
        MigrateStubURLProtocol.responses = [(200, #"{"slug":"s1"}"#.data(using: .utf8)!)]
        local.save(url: "https://a.com", title: "A", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: [])
        local.save(url: "https://b.com", title: "B", description: nil, image: nil,
                   siteName: nil, gradient: "grape", tags: [])
        let (uploaded, allOK) = await mig.run(accessToken: "tok")
        #expect(uploaded == 2)
        #expect(allOK == true)
        #expect(local.all().isEmpty)
    }

    @Test func runPartialFailureKeepsLocal() async throws {
        let (mig, local) = try make()
        // 1번째 성공, 2번째 실패(401).
        MigrateStubURLProtocol.responses = [
            (200, #"{"slug":"s1"}"#.data(using: .utf8)!),
            (401, #"{"error":"unauthorized"}"#.data(using: .utf8)!),
        ]
        local.save(url: "https://a.com", title: "A", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: [])
        local.save(url: "https://b.com", title: "B", description: nil, image: nil,
                   siteName: nil, gradient: "grape", tags: [])
        let (uploaded, allOK) = await mig.run(accessToken: "tok")
        #expect(uploaded == 1)
        #expect(allOK == false)
        #expect(local.all().count == 2) // 부분 실패 → 유지
    }

    @Test func runEmptyReturnsTrue() async throws {
        let (mig, local) = try make()
        let (uploaded, allOK) = await mig.run(accessToken: "tok")
        #expect(uploaded == 0)
        #expect(allOK == true)
        #expect(local.all().isEmpty)
    }
}
