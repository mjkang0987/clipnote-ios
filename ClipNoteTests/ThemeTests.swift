import Testing
@testable import ClipNote

@Suite struct ThemeTests {
    // Ground truth generated from the original JS pickGradient.
    @Test(arguments: [
        ("clipnote", "grape"),
        ("", "sunset"),
        ("a", "ocean"),
        ("hello world", "peach"),
        ("네이버", "peach"),
        ("https://example.com/article", "midnight"),
        ("ClipNote", "grape"),
        ("z", "grape"),
    ])
    func pickGradientMatchesJS(seed: String, expected: String) {
        #expect(pickGradient(seed).name == expected)
    }

    @Test func gradientOrderIsFixed() {
        #expect(GRADIENTS.map(\.name) == [
            "sunset", "ocean", "grape", "forest",
            "peach", "midnight", "mint", "rose",
        ])
    }

    @Test func pickGradientIsDeterministic() {
        #expect(pickGradient("stable").name == pickGradient("stable").name)
    }
}
