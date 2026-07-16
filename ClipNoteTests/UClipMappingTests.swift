import Testing
import Foundation
import SwiftData
@testable import ClipNote

@Suite struct TagParseTests {
    @Test func splitsTrimsAndDropsBlanks() {
        #expect(parseTags("개발, 디자인 ,  , 읽을거리") == ["개발", "디자인", "읽을거리"])
    }

    @Test func capsAtSix() {
        #expect(parseTags("1,2,3,4,5,6,7,8") == ["1", "2", "3", "4", "5", "6"])
    }

    @Test func emptyInputYieldsEmpty() {
        #expect(parseTags("   ") == [])
        #expect(parseTags("") == [])
    }
}

@Suite struct UClipMappingTests {
    @Test func mapsDbClipUsingSlugAsId() {
        let db = DbClip(
            slug: "abc", url: "https://x.com", title: "T",
            description: "D", image: "https://img", siteName: "X",
            gradient: "grape", tags: ["a"], saved: true, shared: true,
            createdAt: "2026-01-01T00:00:00Z"
        )
        let u = UClip(db)
        #expect(u.id == "abc")
        #expect(u.slug == "abc")
        #expect(u.local == false)
        #expect(u.shared == true)
        #expect(u.description == "D")
        #expect(u.tags == ["a"])
    }

    @MainActor
    @Test func mapsLocalClipUsingUrlAsId() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalClip.self, configurations: config)
        let clip = LocalClip(
            url: "https://x.com", title: "T", clipDescription: "D",
            image: nil, siteName: "X", gradient: "ocean",
            tags: ["a", "b"], savedAt: Date()
        )
        container.mainContext.insert(clip)
        let u = UClip(clip)
        #expect(u.id == "https://x.com")
        #expect(u.slug == nil)
        #expect(u.local == true)
        #expect(u.shared == false)
        #expect(u.description == "D")
        #expect(u.tags == ["a", "b"])
    }
}
