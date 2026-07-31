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

    /// 화면마다 대표 키를 하나씩 골라, **네 언어가 서로 다른 값을 주는지** 본다.
    ///
    /// `scripts/check-localizations.py` 는 카탈로그 *파일* 을 본다. 파일이 멀쩡해도 그 카탈로그가
    /// 타깃에 안 들어가거나 `CFBundleLocalizations` 가 어긋나면 런타임에는 전부 폴백한다 —
    /// 파일 검사로는 절대 잡히지 않는다. 그래서 번들에서 실제로 꺼내 본다.
    ///
    /// "키가 그대로 나오지 않는지"만 보면 부족하다. 예컨대 `en.lproj` 가 통째로 빠져도 `t(_:)`
    /// 는 한국어로 폴백해 키가 아닌 값을 돌려주므로 그 검사는 통과한다. 값이 **갈리는지**를 봐야
    /// 언어 번들이 실제로 실렸는지 알 수 있다.
    @Test @MainActor func everyNamespaceResolvesPerLanguage() {
        // 네임스페이스마다 하나씩, 네 언어에서 값이 모두 다른 키로 고른다.
        // 새 화면을 사전화하면 여기에 대표 키를 추가한다.
        let keys = [
            "common.myClips", "home.hero.subtitle", "homeActions.createLink",
            "clips.empty", "login.continueAsGuest", "compare.guestTitle",
            "settings.title", "about.howTitle", "faq.q2", "menu.tour",
            "onboarding.skip", "share.open", "language.koreanOnlyNotice",
        ]
        let store = LocalizationStore(defaults: Self.scratchDefaults("namespaces"))
        for key in keys {
            var values: [String] = []
            for language in AppLanguage.allCases {
                store.select(language)
                let value = store.t(key)
                #expect(value != key, "\(language.rawValue) 에서 \(key) 가 해석되지 않았다")
                values.append(value)
            }
            #expect(Set(values).count == AppLanguage.allCases.count,
                    "\(key) 가 언어별로 갈리지 않는다(번들 누락 → 폴백): \(values)")
        }
    }

    /// 자리표시자가 둘인 문장은 `%1$@`·`%2$@` 위치 지정자를 쓴다. 언어별로 순서가 바뀌어도
    /// 두 인자가 모두 살아 있어야 한다 — 한 언어에서 지시자를 하나 빠뜨리면 그 언어에서만
    /// 낱말이 통째로 사라진다.
    @Test @MainActor func positionalArgumentsKeepTheirMeaning() {
        let store = LocalizationStore(defaults: Self.scratchDefaults("positional"))
        for language in AppLanguage.allCases {
            store.select(language)
            let sentence = store.t("compare.guestItem3", args: "<DEVICE>", "<NOLINK>")
            #expect(sentence.contains("<DEVICE>"), "\(language.rawValue): 첫 인자가 사라졌다")
            #expect(sentence.contains("<NOLINK>"), "\(language.rawValue): 둘째 인자가 사라졌다")
        }
    }

    /// 표시 언어는 `standard` 가 아니라 **App Group** 에 저장한다. 공유 확장은 앱과 다른
    /// `standard` 도메인을 쓰므로, 여기가 standard 로 되돌아가면 앱만 영어이고 공유 시트는
    /// 한국어로 뜬다.
    ///
    /// 시뮬레이터에서는 엔타이틀먼트 없이도 suite 를 열 수 있어 "확장과 정말 공유되는지"까지는
    /// 확인하지 못한다. 이 테스트가 막는 것은 저장 위치가 standard 로 되돌아가는 회귀다.
    @Test @MainActor func selectionIsNotStoredInStandardDefaults() {
        #expect(LocalizationStore.sharedDefaults != UserDefaults.standard,
                "표시 언어가 standard 에 저장된다 — 공유 확장이 읽지 못한다")
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
