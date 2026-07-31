import Foundation
import Observation

/// 표시 언어 상태 + 문자열 조회. 언어를 바꾸면 **재시작 없이** 화면이 즉시 갱신된다.
///
/// iOS 기본 동작은 시스템 설정에서만 앱 언어를 바꾸는 것이다(`Bundle.main`이 실행 시점의
/// 언어로 고정됨). 앱 안에서 즉시 전환하려면 선택한 언어의 `.lproj` 번들에서 문자열을
/// 직접 읽어야 한다. `@Observable`이라 언어가 바뀌면 `t(_:)`를 쓰는 뷰가 다시 그려진다.
@MainActor
@Observable
final class LocalizationStore {
    /// 선택한 언어를 저장하는 키. 기기에 남아 다음 실행에도 유지된다.
    static let storageKey = "app.language"

    /// 저장 위치는 **App Group** 이다(`UserDefaults.standard` 가 아니라).
    ///
    /// 공유 확장은 앱과 다른 `standard` 도메인을 갖는다. standard 에 두면 확장이 사용자의
    /// 선택을 읽지 못해, 앱은 영어인데 공유 시트만 한국어로 뜬다. App Group 은 두 타깃이
    /// 같은 값을 본다(`SharedURLStore` 와 같은 그룹).
    ///
    /// 그룹을 못 여는 상황(엔타이틀먼트 누락·테스트)에서는 standard 로 떨어진다 —
    /// 언어 선택이 확장과 어긋날 뿐 화면은 정상 동작한다.
    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: SharedURLStore.appGroupID) ?? .standard
    }

    private(set) var language: AppLanguage

    /// 현재 언어의 문자열 번들. 언어 변경 때마다 교체한다(조회마다 경로를 뒤지지 않도록).
    private var bundle: Bundle
    private let defaults: UserDefaults

    init(defaults: UserDefaults = LocalizationStore.sharedDefaults) {
        self.defaults = defaults
        let saved = defaults.string(forKey: Self.storageKey).flatMap(AppLanguage.init(rawValue:))
        let initial = saved ?? AppLanguage.matchingSystem()
        self.language = initial
        self.bundle = Self.bundle(for: initial)
    }

    func select(_ language: AppLanguage) {
        guard language != self.language else { return }
        self.language = language
        self.bundle = Self.bundle(for: language)
        defaults.set(language.rawValue, forKey: Self.storageKey)
    }

    /// 키에 해당하는 번역 문자열.
    ///
    /// 번역이 없으면 `localizedString`은 규약대로 **키 자체**를 돌려준다. 그 경우 한국어로
    /// 폴백한다 — 화면에 `settings.title` 같은 키가 노출되는 것보다 원문이 나은 편이다.
    func t(_ key: String) -> String {
        let value = bundle.localizedString(forKey: key, value: nil, table: nil)
        guard value == key, language != .korean else { return value }
        return Self.bundle(for: .korean).localizedString(forKey: key, value: nil, table: nil)
    }

    /// 포맷 인자가 있는 번역 문자열(예: `"%@ 계정으로 로그인됨"`).
    /// `args:` 레이블을 붙여 인자 없는 `t(_:)` 와 오버로드가 겹치지 않게 한다.
    func t(_ key: String, args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    /// 언어별 `.lproj` 번들. 못 찾으면 `Bundle.main`으로 떨어져 원본 언어가 나온다
    /// (문자열 카탈로그에 해당 언어가 빠졌거나 프로젝트 설정에 등록되지 않은 경우).
    static func bundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }
}
