import SwiftUI

enum AppColor {
    static let brand       = Color(hex: 0x7C5CFC)
    static let brandStrong = Color(hex: 0x5B3FE0)
    static let brandSoft   = Color(hex: 0xEFEBFF)
    static let bg          = Color(hex: 0xFFFFFF)
    static let surface     = Color(hex: 0xF7F7F9)
    static let border      = Color(hex: 0xE4E4E7)
    static let fg          = Color(hex: 0x18181B)
    static let fgMuted     = Color(hex: 0x71717A)
    static let success     = Color(hex: 0x16A34A)
    static let danger      = Color(hex: 0xDC2626)
    static let warning     = Color(hex: 0xD97706)
    static let white       = Color(hex: 0xFFFFFF)
}

enum Radius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let full: CGFloat = 9999
}

struct ClipGradient: Equatable {
    let name: String
    let from: Color
    let to:   Color
}

let GRADIENTS: [ClipGradient] = [
    ClipGradient(name: "sunset",   from: Color(hex: 0xFF6B6B), to: Color(hex: 0xFFA94D)),
    ClipGradient(name: "ocean",    from: Color(hex: 0x4F8DFD), to: Color(hex: 0x6FE0C9)),
    ClipGradient(name: "grape",    from: Color(hex: 0x7C5CFC), to: Color(hex: 0xE879F9)),
    ClipGradient(name: "forest",   from: Color(hex: 0x0EA5E9), to: Color(hex: 0x22C55E)),
    ClipGradient(name: "peach",    from: Color(hex: 0xFB7185), to: Color(hex: 0xFDBA74)),
    ClipGradient(name: "midnight", from: Color(hex: 0x4338CA), to: Color(hex: 0x7C3AED)),
    ClipGradient(name: "mint",     from: Color(hex: 0x06B6D4), to: Color(hex: 0x34D399)),
    ClipGradient(name: "rose",     from: Color(hex: 0xEC4899), to: Color(hex: 0x8B5CF6)),
]

/// 결정적 그라디언트 선택. JS의 `(hash * 31 + charCodeAt) | 0` 을 UTF-16 코드 유닛으로 재현.
/// `abs(Int(hash))` — Int32를 64비트로 확장한 뒤 abs를 적용해 Int32.min 크래시 방지.
func pickGradient(_ seed: String) -> ClipGradient {
    var hash: Int32 = 0
    for unit in seed.utf16 {
        hash = hash &* 31 &+ Int32(unit)
    }
    let idx = Int(abs(Int(hash))) % GRADIENTS.count
    return GRADIENTS[idx]
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double(hex & 0xFF)          / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
