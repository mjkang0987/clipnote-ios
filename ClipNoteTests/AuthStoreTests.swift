import Testing
import Foundation
import AuthenticationServices
import Supabase
@testable import ClipNote

@MainActor
@Suite struct AuthStoreTests {
    /// 테스트마다 격리된 UserDefaults 스위트 — persisted 힌트가 테스트 간 오염되지 않게.
    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AuthStoreTests.\(UUID().uuidString)")!
    }

    private func makeStore(defaults: UserDefaults? = nil) -> AuthStore {
        // No network occurs: SupabaseClient init is pure config; autoStart disabled.
        let client = SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "anon-key"
        )
        return AuthStore(client: client, autoStart: false, defaults: defaults ?? isolatedDefaults())
    }

    @Test func startsLoadingLoggedOut() {
        let store = makeStore()
        #expect(store.loading == true)
        #expect(store.loggedIn == false)
        #expect(store.accessToken == nil)
    }

    @Test func applyTokenLogsIn() {
        let store = makeStore()
        store.apply(accessToken: "tok-123")
        #expect(store.loggedIn == true)
        #expect(store.accessToken == "tok-123")
        #expect(store.loading == false)
    }

    @Test func applyNilLogsOut() {
        let store = makeStore()
        store.apply(accessToken: "tok-123")
        store.apply(accessToken: nil)
        #expect(store.loggedIn == false)
        #expect(store.accessToken == nil)
        #expect(store.loading == false)
    }

    @Test func authStateDerivation() {
        #expect(AuthState(accessToken: nil, loading: true).loggedIn == false)
        #expect(AuthState(accessToken: "x", loading: false).loggedIn == true)
    }

    // MARK: - displayLoggedIn (첫 진입 깜빡임 방지)

    @Test func displayLoggedInUsesPersistedHintWhileLoading() {
        // 지난 실행이 로그인 상태였다면, 세션 복원 전(loading)에도 로그인 UI로 그린다.
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: AuthStore.lastLoggedInKey)
        let store = makeStore(defaults: defaults)
        #expect(store.loading == true)
        #expect(store.loggedIn == false)        // 아직 토큰 없음(진실값)
        #expect(store.displayLoggedIn == true)  // 힌트로 로그인 UI 선렌더 → 깜빡임 없음
    }

    @Test func displayLoggedInDefaultsGuestWithoutHint() {
        // 첫 설치/게스트: 힌트 없음 → 게스트 UI(깜빡임 없음, 게스트로 정착).
        let store = makeStore()
        #expect(store.displayLoggedIn == false)
    }

    @Test func displayLoggedInIsAuthoritativeAfterResolve() {
        // 세션 확정 후에는 힌트를 무시하고 실제 상태를 따른다.
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: AuthStore.lastLoggedInKey)
        let store = makeStore(defaults: defaults)
        store.apply(accessToken: nil)            // 세션 없음으로 확정
        #expect(store.displayLoggedIn == false)  // 힌트(true) 무시
    }

    @Test func applyPersistsLoginHint() {
        let defaults = isolatedDefaults()
        let store = makeStore(defaults: defaults)
        store.apply(accessToken: "tok")
        #expect(defaults.bool(forKey: AuthStore.lastLoggedInKey) == true)
        store.apply(accessToken: nil)
        #expect(defaults.bool(forKey: AuthStore.lastLoggedInKey) == false)
    }

    @Test func naverTokenHashConsumedOnce() {
        let store = makeStore()
        #expect(store.markTokenHashConsumed("hash-1") == true)   // 신규 → verify 진행
        #expect(store.markTokenHashConsumed("hash-1") == false)  // 중복 → 무시
        #expect(store.markTokenHashConsumed("hash-2") == true)   // 다른 값 → 진행
    }

    @Test func oauthRedirectMatchesDeepLinkScheme() {
        #expect(AuthStore.oauthRedirect.scheme == AuthDeepLink.scheme)
        #expect(AuthDeepLink.parse(AuthStore.oauthRedirect.appending(queryItems: [
            URLQueryItem(name: "code", value: "abc")
        ])) == .oauthCallback(code: "abc"))
    }

    @Test func userCancellationNotTreatedAsError() {
        #expect(AuthStore.isUserCancellation(
            ASWebAuthenticationSessionError(.canceledLogin)) == true)
        #expect(AuthStore.isUserCancellation(
            URLError(.timedOut)) == false)
    }

    @Test func naverAuthURLMatchesRNContract() throws {
        let url = try #require(AuthStore.makeNaverAuthURL(clientID: "cid-1", nonce: "abc"))
        let comps = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(comps.host == "nid.naver.com")
        #expect(comps.path == "/oauth2.0/authorize")

        func q(_ n: String) -> String? { comps.queryItems?.first { $0.name == n }?.value }
        #expect(q("response_type") == "code")
        #expect(q("client_id") == "cid-1")
        #expect(q("redirect_uri") == AuthStore.naverCallback)

        let stateJSON = try #require(q("state")).data(using: .utf8)!
        let state = try JSONDecoder().decode(AuthStore.NaverState.self, from: stateJSON)
        #expect(state == AuthStore.NaverState(returnUrl: AuthStore.naverReturnURL, n: "abc"))
    }

    @Test func releaseTokenHashAllowsRetry() {
        let store = makeStore()
        #expect(store.markTokenHashConsumed("h") == true)
        #expect(store.markTokenHashConsumed("h") == false)  // 소비됨
        store.releaseTokenHash("h")                          // 실패 → 롤백
        #expect(store.markTokenHashConsumed("h") == true)    // 재시도 허용
    }
}

extension AuthStore {
    var loading: Bool { state.loading }
}
