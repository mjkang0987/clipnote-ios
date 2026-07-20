import Testing
@testable import ClipNote

@Suite struct ShareTextTests {
    @Test func joinsTitleAndURLOnly() {
        let text = buildShareText(
            title: "좋은 글",
            description: "요약입니다",
            url: "https://clipnote.co.kr/abc"
        )
        // 설명은 제외하고 제목·링크만 복사.
        #expect(text == "좋은 글\nhttps://clipnote.co.kr/abc")
    }

    @Test func ignoresDescriptionWhenNil() {
        let text = buildShareText(
            title: "제목만",
            description: nil,
            url: "https://clipnote.co.kr/xyz"
        )
        #expect(text == "제목만\nhttps://clipnote.co.kr/xyz")
    }

    @Test func ignoresDescriptionWhenPresent() {
        let text = buildShareText(
            title: "제목",
            description: "긴 설명 텍스트",
            url: "https://clipnote.co.kr/xyz"
        )
        #expect(text == "제목\nhttps://clipnote.co.kr/xyz")
    }
}
