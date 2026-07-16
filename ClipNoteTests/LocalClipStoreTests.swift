import Testing
import Foundation
import SwiftData
@testable import ClipNote

@MainActor
@Suite struct LocalClipStoreTests {
    private func makeStore(maxClips: Int = 300) throws -> LocalClipStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalClip.self, configurations: config)
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return LocalClipStore(container: container, defaults: defaults, maxClips: maxClips)
    }

    @Test func savesAndListsNewestFirst() throws {
        let store = try makeStore()
        store.save(url: "https://a.com", title: "A", description: nil,
                   image: nil, siteName: nil, gradient: "ocean", tags: [])
        store.save(url: "https://b.com", title: "B", description: nil,
                   image: nil, siteName: nil, gradient: "grape", tags: [])
        #expect(store.all().map(\.url) == ["https://b.com", "https://a.com"])
    }

    @Test func upsertsSameUrlAsNewest() throws {
        let store = try makeStore()
        store.save(url: "https://a.com", title: "A1", description: nil,
                   image: nil, siteName: nil, gradient: "ocean", tags: [])
        store.save(url: "https://b.com", title: "B", description: nil,
                   image: nil, siteName: nil, gradient: "grape", tags: [])
        store.save(url: "https://a.com", title: "A2", description: "d",
                   image: nil, siteName: nil, gradient: "mint", tags: [])
        let all = store.all()
        #expect(all.count == 2)
        #expect(all.first?.url == "https://a.com")
        #expect(all.first?.title == "A2")
        #expect(all.first?.clipDescription == "d")
    }

    @Test func capsAtMax() throws {
        let store = try makeStore(maxClips: 3)
        for i in 0..<5 {
            store.save(url: "https://x.com/\(i)", title: "T\(i)", description: nil,
                       image: nil, siteName: nil, gradient: "ocean", tags: [])
        }
        let all = store.all()
        #expect(all.count == 3)
        // newest kept, oldest dropped
        #expect(all.map(\.url) == ["https://x.com/4", "https://x.com/3", "https://x.com/2"])
    }

    @Test func defaultCapIs300() throws {
        let store = try makeStore()
        for i in 0..<301 {
            store.save(url: "https://x.com/\(i)", title: "T\(i)", description: nil,
                       image: nil, siteName: nil, gradient: "ocean", tags: [])
        }
        #expect(store.all().count == 300)
    }

    @Test func deletesByUrl() throws {
        let store = try makeStore()
        store.save(url: "https://a.com", title: "A", description: nil,
                   image: nil, siteName: nil, gradient: "ocean", tags: [])
        store.save(url: "https://b.com", title: "B", description: nil,
                   image: nil, siteName: nil, gradient: "grape", tags: [])
        store.delete(url: "https://a.com")
        #expect(store.all().map(\.url) == ["https://b.com"])
    }

    @Test func clearRemovesAll() throws {
        let store = try makeStore()
        store.save(url: "https://a.com", title: "A", description: nil,
                   image: nil, siteName: nil, gradient: "ocean", tags: ["x"])
        store.clearLocalClips()
        #expect(store.all().isEmpty)
    }

    @Test func knownTagsSortedByFrequencyDesc() throws {
        let store = try makeStore()
        // "swift" x3, "ios" x2, "ui" x1
        store.save(url: "https://1", title: "1", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["swift", "ios", "ui"])
        store.save(url: "https://2", title: "2", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["swift", "ios"])
        store.save(url: "https://3", title: "3", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["swift"])
        #expect(store.knownTags() == ["swift", "ios", "ui"])
    }

    @Test func knownTagsTrimsAndIgnoresBlank() throws {
        let store = try makeStore()
        store.save(url: "https://1", title: "1", description: nil, image: nil,
                   siteName: nil, gradient: "ocean", tags: ["  swift  ", "", "   "])
        #expect(store.knownTags() == ["swift"])
    }
}
