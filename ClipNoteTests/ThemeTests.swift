import Testing
@testable import ClipNote

@Suite struct ThemeTests {

    // MARK: - Color tokens

    @Test func brandColorHex() {
        #expect(Theme.Colors.brand == "#7C5CFC")
    }

    @Test func brandStrongColorHex() {
        #expect(Theme.Colors.brandStrong == "#5B3FE0")
    }

    @Test func brandSoftColorHex() {
        #expect(Theme.Colors.brandSoft == "#EFEBFF")
    }

    @Test func bgColorHex() {
        #expect(Theme.Colors.bg == "#FFFFFF")
    }

    @Test func surfaceColorHex() {
        #expect(Theme.Colors.surface == "#F7F7F9")
    }

    @Test func borderColorHex() {
        #expect(Theme.Colors.border == "#E4E4E7")
    }

    @Test func fgColorHex() {
        #expect(Theme.Colors.fg == "#18181B")
    }

    @Test func fgMutedColorHex() {
        #expect(Theme.Colors.fgMuted == "#71717A")
    }

    @Test func successColorHex() {
        #expect(Theme.Colors.success == "#16A34A")
    }

    @Test func dangerColorHex() {
        #expect(Theme.Colors.danger == "#DC2626")
    }

    @Test func warningColorHex() {
        #expect(Theme.Colors.warning == "#D97706")
    }

    @Test func whiteColorHex() {
        #expect(Theme.Colors.white == "#FFFFFF")
    }

    // MARK: - Radius tokens

    @Test func radiusSm() {
        #expect(Theme.Radius.sm == 8)
    }

    @Test func radiusMd() {
        #expect(Theme.Radius.md == 12)
    }

    @Test func radiusLg() {
        #expect(Theme.Radius.lg == 16)
    }

    @Test func radiusFull() {
        #expect(Theme.Radius.full == 9999)
    }

    // MARK: - Space function

    @Test func spaceFunction() {
        #expect(Theme.space(1) == 4)
        #expect(Theme.space(4) == 16)
        #expect(Theme.space(0) == 0)
    }

    // MARK: - Gradients preset

    @Test func gradientsCount() {
        #expect(Theme.gradients.count == 8)
    }

    @Test func gradientsNames() {
        let names = Theme.gradients.map(\.name)
        #expect(names == ["sunset", "ocean", "grape", "forest", "peach", "midnight", "mint", "rose"])
    }

    @Test func sunsetGradient() {
        let g = Theme.gradients[0]
        #expect(g.from == "#FF6B6B")
        #expect(g.to == "#FFA94D")
    }

    @Test func oceanGradient() {
        let g = Theme.gradients[1]
        #expect(g.from == "#4F8DFD")
        #expect(g.to == "#6FE0C9")
    }

    // MARK: - pickGradient determinism (must match JS for same seed)

    @Test func pickGradientHello() {
        // JS: hash=99162322, idx=2 → grape
        let g = Theme.pickGradient("hello")
        #expect(g.name == "grape")
        #expect(g.from == "#7C5CFC")
        #expect(g.to == "#E879F9")
    }

    @Test func pickGradientWorld() {
        // JS: → grape
        let g = Theme.pickGradient("world")
        #expect(g.name == "grape")
    }

    @Test func pickGradientKorean() {
        // 네이버: UTF-16 codes 45348, 51060, 48260 → hash=45210548, idx=4 → peach
        let g = Theme.pickGradient("네이버")
        #expect(g.name == "peach")
        #expect(g.from == "#FB7185")
        #expect(g.to == "#FDBA74")
    }

    @Test func pickGradientAbc() {
        // JS: → grape
        let g = Theme.pickGradient("abc")
        #expect(g.name == "grape")
    }

    @Test func pickGradientEmpty() {
        // empty seed: hash=0, idx=0 → sunset
        let g = Theme.pickGradient("")
        #expect(g.name == "sunset")
        #expect(g.from == "#FF6B6B")
    }

    @Test func pickGradientClipNote() {
        // JS: → grape
        let g = Theme.pickGradient("ClipNote")
        #expect(g.name == "grape")
    }

    @Test func pickGradientKorean2() {
        // 가나다라: → sunset
        let g = Theme.pickGradient("가나다라")
        #expect(g.name == "sunset")
    }

    @Test func pickGradientSingleChar() {
        // "a": code=97, hash=97, idx=97%8=1 → ocean
        let g = Theme.pickGradient("a")
        #expect(g.name == "ocean")
    }

    @Test func pickGradientAlphanumeric() {
        // "test123": → sunset
        let g = Theme.pickGradient("test123")
        #expect(g.name == "sunset")
    }
}
