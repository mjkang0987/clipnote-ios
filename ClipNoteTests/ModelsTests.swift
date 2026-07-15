import Testing
import Foundation
@testable import ClipNote

@Suite struct ModelsTests {
    @Test func decodesDbClipFromServerJSON() throws {
        let json = """
        {
          "slug": "abc123",
          "url": "https://example.com/a",
          "title": "제목",
          "description": "설명",
          "image": null,
          "siteName": "Example",
          "gradient": "grape",
          "tags": ["개발", "디자인"],
          "saved": true,
          "shared": false,
          "createdAt": "2026-01-02T03:04:05Z"
        }
        """.data(using: .utf8)!
        let clip = try JSONDecoder().decode(DbClip.self, from: json)
        #expect(clip.slug == "abc123")
        #expect(clip.tags == ["개발", "디자인"])
        #expect(clip.saved == true)
        #expect(clip.shared == false)
        #expect(clip.image == nil)
        #expect(clip.id == "abc123")
    }

    @Test func decodesMetadataWithNulls() throws {
        let json = """
        {"url":"https://x.com","title":null,"description":null,
         "image":null,"siteName":null,"source":"none","reason":"no og"}
        """.data(using: .utf8)!
        let meta = try JSONDecoder().decode(ClipMetadata.self, from: json)
        #expect(meta.title == nil)
        #expect(meta.source == "none")
        #expect(meta.reason == "no og")
    }

    @Test func encodesCreateClipInputOmittingNilSave() throws {
        let input = CreateClipInput(
            url: "https://x.com", title: "T",
            description: nil, image: nil, siteName: nil,
            tags: ["a"], gradient: "ocean", save: nil
        )
        let data = try JSONEncoder().encode(input)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["url"] as? String == "https://x.com")
        #expect(obj["gradient"] as? String == "ocean")
        #expect(obj["save"] == nil) // nil save must not be sent
    }

    @Test func decodesCreateClipResult() throws {
        let json = #"{"slug":"s1","shareUrl":"https://clipnote.co.kr/s1"}"#.data(using: .utf8)!
        let res = try JSONDecoder().decode(CreateClipResult.self, from: json)
        #expect(res.shareUrl == "https://clipnote.co.kr/s1")
        #expect(res.error == nil)
    }
}
