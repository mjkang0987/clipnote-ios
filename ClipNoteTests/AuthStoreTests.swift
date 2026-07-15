import Testing
import Foundation
import Supabase
@testable import ClipNote

@MainActor
@Suite struct AuthStoreTests {
    private func makeStore() -> AuthStore {
        // No network occurs: SupabaseClient init is pure config; autoStart disabled.
        let client = SupabaseClient(
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseKey: "anon-key"
        )
        return AuthStore(client: client, autoStart: false)
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
}

extension AuthStore {
    var loading: Bool { state.loading }
}
