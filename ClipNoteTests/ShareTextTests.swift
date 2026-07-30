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

    // MARK: - 제목 길이 제한

    @Test func keepsShortTitleUntouched() {
        let title = "Swift Concurrency 정리"
        #expect(truncateShareTitle(title) == title)
    }

    @Test func keepsTitleAtExactLimit() {
        let title = String(repeating: "가", count: shareTitleMaxLength)
        let result = truncateShareTitle(title)
        // 상한과 같으면 자르지 않는다(말줄임표도 붙지 않음).
        #expect(result == title)
        #expect(!result.hasSuffix("…"))
    }

    @Test func truncatesTitleOverLimitIncludingEllipsis() {
        let title = String(repeating: "가", count: shareTitleMaxLength + 20)
        let result = truncateShareTitle(title)
        // 말줄임표까지 합쳐 정확히 상한.
        #expect(result.count == shareTitleMaxLength)
        #expect(result.hasSuffix("…"))
    }

    @Test func collapsesNewlinesIntoSingleSpaces() {
        // 인스타 캡션은 개행이 많아 그대로 두면 `제목\nURL` 포맷이 깨진다.
        let result = truncateShareTitle("첫 줄\n\n둘째 줄\t셋째  줄")
        #expect(result == "첫 줄 둘째 줄 셋째 줄")
    }

    @Test func trimsWhitespaceBeforeEllipsis() {
        // 잘린 지점이 공백이면 "…" 앞의 공백을 떼낸다.
        let result = truncateShareTitle("가나다 라마바", max: 5)
        #expect(result == "가나다…")
    }

    @Test func doesNotSplitEmoji() {
        // 그래핌 클러스터 단위로 세므로 이모지가 반쪼가리로 잘리지 않는다.
        let result = truncateShareTitle("☕️🥐🍝🍕🍔", max: 3)
        #expect(result == "☕️🥐…")
    }

    @Test func truncatesLongInstagramCaptionInShareText() {
        let caption = """
        오늘 다녀온 성수동 카페 ☕️ 분위기 미쳤고 사장님도 너무 친절하셨어요

        웨이팅 30분 정도 했는데 충분히 기다릴 만했음 🥐 크로플이 진짜 겉바속촉이라 두 번 시켰습니다

        #성수동카페 #카페추천 #서울카페 #데이트코스
        """
        let url = "https://clipnote.co.kr/aB3xY9"
        let text = buildShareText(title: caption, description: nil, url: url)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        // 캡션 개행이 정리돼 항상 정확히 두 줄(제목/링크).
        #expect(lines.count == 2)
        #expect(lines[0].count == shareTitleMaxLength)
        #expect(lines[0].hasSuffix("…"))
        #expect(lines[1] == url)
    }

    @Test func omitsEmptyTitleLine() {
        // 제목이 없으면 빈 줄을 남기지 않고 링크만.
        let text = buildShareText(title: "   ", description: nil, url: "https://clipnote.co.kr/abc")
        #expect(text == "https://clipnote.co.kr/abc")
    }
}
