import Foundation
import Supabase

/// Pure, testable snapshot of auth state. `loggedIn` is derived from token presence.
struct AuthState: Equatable {
    var accessToken: String?
    var loading: Bool
    var loggedIn: Bool { accessToken != nil }
}

/// Wraps `supabase-swift` auth. Session persistence (Keychain) and token refresh are
/// handled by the Supabase client; this store mirrors the session into observable state.
/// Ports RN `lib/auth.tsx`. OAuth flows (Google/Kakao/네이버) land in later sub-issues.
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var state = AuthState(accessToken: nil, loading: true)

    var accessToken: String? { state.accessToken }
    var loggedIn: Bool { state.loggedIn }

    let client: SupabaseClient
    private var observeTask: Task<Void, Never>?

    init(client: SupabaseClient, autoStart: Bool = true) {
        self.client = client
        if autoStart { start() }
    }

    /// Builds from `Secrets.xcconfig`-injected config. Nil if Supabase keys are absent.
    convenience init?() {
        guard let url = Config.supabaseURL, let key = Config.supabaseAnonKey else { return nil }
        self.init(client: SupabaseClient(supabaseURL: url, supabaseKey: key))
    }

    /// Subscribes to auth state changes and mirrors each session into `state`.
    func start() {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await change in self.client.auth.authStateChanges {
                self.apply(accessToken: change.session?.accessToken)
            }
        }
    }

    /// Maps an optional access token into observable state. Extracted for testability.
    func apply(accessToken: String?) {
        state = AuthState(accessToken: accessToken, loading: false)
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    deinit { observeTask?.cancel() }
}
