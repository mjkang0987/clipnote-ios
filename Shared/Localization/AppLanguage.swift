import Foundation

/// 앱 내에서 고를 수 있는 표시 언어.
/// 웹(`clipnote`)의 지원 목록과 **같은 코드·같은 순서**를 유지한다. 한쪽만 늘리지 않는다.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"
    case chineseSimplified = "zh-Hans"

    var id: String { rawValue }

    /// 각 언어를 그 언어로 표기 — 설정 목록에서 자기 언어로 보이는 게 관례다
    /// (영어만 아는 사용자가 "영어"를 못 찾는 일을 막는다).
    var label: String {
        switch self {
        case .korean: "한국어"
        case .english: "English"
        case .japanese: "日本語"
        case .chineseSimplified: "简体中文"
        }
    }

    /// 시스템 선호 언어 중 가장 먼저 매칭되는 지원 언어. 없으면 한국어(원본 언어).
    ///
    /// 중국어는 `zh-Hant`(번체)·`zh-HK` 등 변형이 많은데 현재 지원은 간체 하나뿐이라
    /// `zh` 로 시작하면 모두 간체로 본다. 번체를 추가하면 이 분기를 세분화해야 한다.
    static func matchingSystem(preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferred {
            if identifier.hasPrefix("zh") { return .chineseSimplified }
            if let code = Locale(identifier: identifier).language.languageCode?.identifier,
               let match = AppLanguage(rawValue: code) {
                return match
            }
        }
        return .korean
    }
}
