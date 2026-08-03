import Testing
@testable import ClipNote

@Suite struct URLHelpersTests {
    @Test func fetchableRequiresDottedHost() {
        #expect(isFetchableUrl("https://example.com"))
        #expect(isFetchableUrl("example.com/a"))
        #expect(!isFetchableUrl("localhost"))
        #expect(!isFetchableUrl(""))
        #expect(!isFetchableUrl("   "))
    }

    @Test func prettyHostStripsWwwAndRootPath() {
        #expect(prettyHost("https://www.example.com") == "example.com")
        #expect(prettyHost("https://example.com/") == "example.com")
        #expect(prettyHost("https://example.com/article") == "example.com/article")
        #expect(prettyHost("example.com/x") == "example.com/x")
    }

    /// 중복 판정용 정규화가 **웹과 같은 결과**를 내는지.
    ///
    /// 기대값은 웹 `lib/metadata.ts` 의 `canonicalizeUrl` 을 실제로 돌려 받은 것이다. 규칙이
    /// 갈리면 로그인 목록에서 서버 사본과 이 기기 사본이 걸러지지 않아 같은 링크가 두 줄로
    /// 남는다 — 눈으로 보기 전에는 모르는 종류라 여기에 못을 박는다.
    @Test(arguments: [
        ("https://example.com/a/", "https://example.com/a"),          // 끝 슬래시 제거
        ("http://Example.COM:80/a", "http://example.com/a"),          // 호스트 소문자·기본 포트
        ("https://example.com:443/a", "https://example.com/a"),
        ("https://example.com/a?utm_source=x&b=1", "https://example.com/a?b=1"),
        ("https://example.com/?fbclid=z", "https://example.com/"),    // 루트 슬래시는 남긴다
        ("example.com/a", "https://example.com/a"),                   // 스킴 보정
        ("https://example.com/", "https://example.com/"),
        ("https://example.com/a?b=1&gclid=q", "https://example.com/a?b=1"),
    ])
    func canonicalKeyMatchesWeb(input: String, expected: String) {
        #expect(canonicalURLKey(input) == expected)
    }
}
