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

    /// 애플 시트 취소는 웹 로그인과 **다른 에러 타입**으로 온다. 한쪽만 보면 취소가
    /// 빨간 오류 문구로 뜬다.
    @Test func appleCancellationNotTreatedAsError() {
        #expect(AuthStore.isUserCancellation(
            ASAuthorizationError(.canceled)) == true)
        #expect(AuthStore.isUserCancellation(
            ASAuthorizationError(.failed)) == false)
    }

    // MARK: - Sign in with Apple (Guideline 4.8)

    @Test func nonceHasRequestedLengthAndSafeCharacters() {
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        for length in [1, 16, 32, 64] {
            let nonce = AuthStore.randomNonce(length: length)
            #expect(nonce.count == length)
            #expect(nonce.allSatisfy { allowed.contains($0) })
        }
    }

    /// 1회성이어야 재생 공격을 막는다. 같은 값이 두 번 나오면 그 성질이 깨진다.
    @Test func nonceDiffersBetweenCalls() {
        let nonces = Set((0..<50).map { _ in AuthStore.randomNonce() })
        #expect(nonces.count == 50)
    }

    /// 애플에 넘기는 값은 원본이 아니라 이 해시다. 알려진 벡터로 구현을 못박는다 —
    /// 여기가 어긋나면 로그인은 되는 듯하다 서버 검증만 조용히 떨어진다.
    @Test func sha256HexMatchesKnownVector() {
        #expect(AuthStore.sha256Hex("abc")
            == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(AuthStore.sha256Hex("")
            == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        // 64자 소문자 16진수 — 애플이 nonce 로 받아 주는 형태.
        let digest = AuthStore.sha256Hex(AuthStore.randomNonce())
        #expect(digest.count == 64)
        #expect(digest.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    /// 실패는 보이고 취소는 안 보인다.
    ///
    /// ⚠️ **`.appleTokenMissing` 은 여기서 검증할 수 없다.** 그 분기는 `.success` 안에
    /// 있는데 `ASAuthorization` 은 시스템만 만들 수 있어 테스트에서 구성이 안 된다. 이름으로
    /// 덮은 것처럼 보이게 두면 없는 보호막을 믿게 되므로 범위를 여기 적어 둔다 —
    /// 그 경로는 실기기 확인 대상이다.
    @Test func appleSignInSurfacesFailureButNotCancellation() async {
        let store = makeStore()
        await store.completeAppleSignIn(.failure(ASAuthorizationError(.failed)), nonce: "n")
        #expect(store.lastError != nil)

        // 앞선 실패가 남아 있어도 취소는 조용해야 한다. 다만 이 단언만으로는 약하다 —
        // completeAppleSignIn 이 시작하며 lastError 를 비우기 때문에, isUserCancellation 에서
        // 애플 케이스가 빠져도 통과한다. 그 가드는 appleCancellationNotTreatedAsError 가 본다.
        await store.completeAppleSignIn(.failure(ASAuthorizationError(.canceled)), nonce: "n")
        #expect(store.lastError == nil)
    }

    @Test func appleProviderNameIsLatin() {
        #expect(AccountInfo(email: nil, provider: "apple").providerName == "Apple")
        #expect(AccountInfo(email: nil, provider: "google").providerName == "Google")
        #expect(AccountInfo(email: nil, provider: "unknown").providerName == nil)
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
