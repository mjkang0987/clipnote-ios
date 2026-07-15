import Testing
@testable import ClipNote

@Suite struct ShareTextTests {
    @Test func joinsTitleDescriptionURLWithNewlines() {
        let text = buildShareText(
            title: "좋은 글",
            description: "요약입니다",
            url: "https://clipnote.co.kr/abc"
        )
        #expect(text == "좋은 글\n요약입니다\nhttps://clipnote.co.kr/abc")
    }

    @Test func omitsDescriptionLineWhenNil() {
        let text = buildShareText(
            title: "제목만",
            description: nil,
            url: "https://clipnote.co.kr/xyz"
        )
        #expect(text == "제목만\nhttps://clipnote.co.kr/xyz")
    }

    @Test func omitsDescriptionLineWhenBlank() {
        let text = buildShareText(
            title: "제목",
            description: "   ",
            url: "https://clipnote.co.kr/xyz"
        )
        #expect(text == "제목\nhttps://clipnote.co.kr/xyz")
    }
}
