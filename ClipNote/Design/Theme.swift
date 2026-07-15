import Foundation

// 디자인 토큰 — JS lib/theme.ts 에서 이식.
// pickGradient 는 JS의 charCodeAt(i) (UTF-16 코드 유닛) 를
// Swift seed.utf16 로 정확히 재현해야 같은 시드에서 같은 그라디언트가 나온다.

public enum Theme {

    // MARK: - Color tokens

    public enum Colors {
        public static let brand       = "#7C5CFC"
        public static let brandStrong = "#5B3FE0"
        public static let brandSoft   = "#EFEBFF"

        public static let bg      = "#FFFFFF"
        public static let surface = "#F7F7F9"
        public static let border  = "#E4E4E7"
        public static let fg      = "#18181B"
        public static let fgMuted = "#71717A"

        public static let success = "#16A34A"
        public static let danger  = "#DC2626"
        public static let warning = "#D97706"

        public static let white = "#FFFFFF"
    }

    // MARK: - Radius tokens

    public enum Radius {
        public static let sm:   CGFloat = 8
        public static let md:   CGFloat = 12
        public static let lg:   CGFloat = 16
        public static let full: CGFloat = 9999
    }

    // MARK: - Space function

    public static func space(_ n: CGFloat) -> CGFloat { n * 4 }

    // MARK: - Gradient preset

    public struct Gradient: Sendable {
        public let name: String
        public let from: String
        public let to:   String
    }

    public static let gradients: [Gradient] = [
        Gradient(name: "sunset",   from: "#FF6B6B", to: "#FFA94D"),
        Gradient(name: "ocean",    from: "#4F8DFD", to: "#6FE0C9"),
        Gradient(name: "grape",    from: "#7C5CFC", to: "#E879F9"),
        Gradient(name: "forest",   from: "#0EA5E9", to: "#22C55E"),
        Gradient(name: "peach",    from: "#FB7185", to: "#FDBA74"),
        Gradient(name: "midnight", from: "#4338CA", to: "#7C3AED"),
        Gradient(name: "mint",     from: "#06B6D4", to: "#34D399"),
        Gradient(name: "rose",     from: "#EC4899", to: "#8B5CF6"),
    ]

    // MARK: - pickGradient

    /// 시드 문자열 → 결정적 그라디언트 선택.
    /// JS의 charCodeAt() = UTF-16 코드 유닛과 동일하게 seed.utf16 을 순회해야
    /// 비-ASCII 시드(한글 등)에서도 서버 OG 카드 색상과 일치한다.
    public static func pickGradient(_ seed: String) -> Gradient {
        var hash: Int32 = 0
        for unit in seed.utf16 {
            hash = hash &* 31 &+ Int32(bitPattern: UInt32(unit))
        }
        let idx = Int(abs(hash)) % gradients.count
        return gradients[idx]
    }
}
