import Foundation
import Testing
@testable import ClipNote

/// 다국어 배선이 조용히 깨지는 걸 막는 게 이 스위트의 목적이다.
///
/// `LocalizationStore`는 선택 언어의 `.lproj` 번들을 직접 열고, 못 찾으면 `Bundle.main`으로
/// 폴백한다(화면이 안 깨지도록). 그래서 `CFBundleLocalizations`가 빠지거나 문자열 카탈로그에
/// 언어가 누락되면 **앱은 정상 동작하면서 전부 한국어로만 나온다.** 눈으로 보지 않으면 모른다.
@Suite struct LocalizationStoreTests {

    // MARK: - 번들·프로젝트 설정

    @Test func everySupportedLanguageShipsALprojBundle() {
        for language in AppLanguage.allCases {
            let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj")
            #expect(path != nil, "\(language.rawValue).lproj 가 번들에 없다 — project.yml 의 CFBundleLocalizations 확인")
        }
    }

    @Test func bundleLocalizationsMatchSupportedLanguages() throws {
        let declared = try #require(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String]
        )
        // 지원 언어를 enum 에만 추가하고 project.yml 을 안 고치는 드리프트를 잡는다.
        #expect(Set(declared) == Set(AppLanguage.allCases.map(\.rawValue)))
    }

    // MARK: - 문자열 조회

    @Test @MainActor func sameKeyDiffersAcrossLanguages() {
        let values = AppLanguage.allCases.map { language -> String in
            let store = LocalizationStore(defaults: Self.scratchDefaults("differs"))
            store.select(language)
            return store.t("common.settings")
        }
        // 4개 언어가 서로 다른 값이어야 한다 — 하나라도 겹치면 폴백이 일어난 것.
        #expect(Set(values).count == AppLanguage.allCases.count, "번역이 겹친다: \(values)")
    }

    @Test @MainActor func translatesKnownKeyPerLanguage() {
        let store = LocalizationStore(defaults: Self.scratchDefaults("known"))
        store.select(.korean)
        #expect(store.t("common.settings") == "설정")
        store.select(.english)
        #expect(store.t("common.settings") == "Settings")
        store.select(.japanese)
        #expect(store.t("common.settings") == "設定")
        store.select(.chineseSimplified)
        #expect(store.t("common.settings") == "设置")
    }

    @Test @MainActor func formatsArguments() {
        let store = LocalizationStore(defaults: Self.scratchDefaults("format"))
        store.select(.english)
        #expect(store.t("settings.signedInWith", args: "Google") == "Signed in with Google")
    }

    @Test @MainActor func unknownKeyReturnsKeyItself() {
        // 번역도 한국어 폴백도 없으면 키가 그대로 나온다(빈 화면보다 낫다는 판단).
        let store = LocalizationStore(defaults: Self.scratchDefaults("unknown"))
        store.select(.english)
        #expect(store.t("no.such.key") == "no.such.key")
    }

    // MARK: - 선택 유지

    @Test @MainActor func persistsSelectionAcrossInstances() {
        let suite = "LocalizationStoreTests.persist"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        LocalizationStore(defaults: defaults).select(.japanese)
        #expect(defaults.string(forKey: LocalizationStore.storageKey) == "ja")
        // 다음 실행에 해당 — 저장된 언어로 시작해야 한다.
        #expect(LocalizationStore(defaults: defaults).language == .japanese)
    }

    // MARK: - 시스템 언어 매칭

    @Test(arguments: [
        (["en-US"], AppLanguage.english),
        (["ja-JP"], AppLanguage.japanese),
        (["ko-KR"], AppLanguage.korean),
        // 번체·홍콩도 현재는 간체 하나로 받는다(지원이 간체뿐).
        (["zh-Hant-TW"], AppLanguage.chineseSimplified),
        (["zh-HK"], AppLanguage.chineseSimplified),
        // 지원하지 않는 언어는 원본 언어(한국어)로.
        (["fr-FR"], AppLanguage.korean),
        // 앞쪽이 미지원이면 뒤쪽에서 첫 매칭을 찾는다.
        (["fr-FR", "ja-JP"], AppLanguage.japanese),
        ([], AppLanguage.korean),
    ])
    func matchesSystemPreferredLanguage(preferred: [String], expected: AppLanguage) {
        #expect(AppLanguage.matchingSystem(preferred: preferred) == expected)
    }

    @Test func labelsAreSelfDescribing() {
        // 각 언어를 그 언어로 표기 — 영어만 아는 사용자가 자기 언어를 찾을 수 있어야 한다.
        #expect(AppLanguage.english.label == "English")
        #expect(AppLanguage.japanese.label == "日本語")
        #expect(AppLanguage.chineseSimplified.label == "简体中文")
        #expect(AppLanguage.korean.label == "한국어")
    }

    // MARK: - Helpers

    /// 테스트끼리 저장된 언어가 섞이지 않도록 매번 빈 도메인을 쓴다.
    private static func scratchDefaults(_ name: String) -> UserDefaults {
        let suite = "LocalizationStoreTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
