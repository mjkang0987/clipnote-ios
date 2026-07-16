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
}
