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
    /// token_hash는 1회용. 딥링크 중복 도착 시 재verify 방지(설계 §3.3).
    private var consumedTokenHashes = Set<String>()

    init(client: SupabaseClient, autoStart: Bool = true) {
        self.client = client
        if autoStart { start() }
    }

    /// Builds from `Secrets.xcconfig`-injected config. Nil if Supabase keys are absent.
    convenience init?() {
        guard let url = Config.supabaseURL, let key = Config.supabaseAnonKey else { return nil }
        self.init(client: SupabaseClient(supabaseURL: url, supabaseKey: key))
    }

    /// Non-observing fallback when Supabase config is missing (misconfigured build).
    /// Auth actions no-op/throw silently; the app still launches.
    static func disabled() -> AuthStore {
        AuthStore(
            client: SupabaseClient(
                supabaseURL: URL(string: "https://placeholder.supabase.co")!,
                supabaseKey: "anon"
            ),
            autoStart: false
        )
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

    /// `.onOpenURL` 진입점. auth 딥링크면 라우팅해 세션을 만든다.
    /// 세션 갱신은 Supabase가 내부 처리 → `authStateChanges` → `apply`로 상태 반영.
    /// 실패는 현재 조용히 무시 — 유저 피드백(에러 토스트/재시도)은 LoginView와 함께 #7/#8에서 배선.
    func handle(url: URL) async {
        switch AuthDeepLink.parse(url) {
        case .oauthCallback:
            // session(from:)이 URL에서 code를 추출·교환한다.
            try? await client.auth.session(from: url)
        case let .naver(tokenHash):
            guard markTokenHashConsumed(tokenHash) else { return }
            try? await client.auth.verifyOTP(tokenHash: tokenHash, type: .magiclink)
        case nil:
            break
        }
    }

    /// token_hash를 소비 처리. 신규면 true(verify 진행), 중복이면 false. 가드 로직 분리(테스트용).
    func markTokenHashConsumed(_ tokenHash: String) -> Bool {
        consumedTokenHashes.insert(tokenHash).inserted
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    deinit { observeTask?.cancel() }
}
