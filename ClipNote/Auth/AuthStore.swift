import Foundation
import AuthenticationServices
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
    /// 마지막 로그인 실패 메시지(유저 취소는 제외). LoginView가 표시.
    @Published var lastError: String?
    /// 네이버 콜백 딥링크가 도착할 때마다 증가. LoginView가 이 변화에 맞춰 SFSafari 시트를 닫는다.
    /// (scenePhase `.active`는 SFSafari 표시 정착 등으로도 떠서 로그인 완료 전 시트가 닫히는 문제 회피.)
    @Published private(set) var naverCallbackCount = 0

    var accessToken: String? { state.accessToken }
    var loggedIn: Bool { state.loggedIn }

    /// Supabase OAuth 콜백 리다이렉트. 딥링크 스킴(#6 AuthDeepLink)과 일치.
    static let oauthRedirect = URL(string: "clipnote://auth/callback")!

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
            // 콜백이 앱으로 복귀했으니(성공·실패·중복 무관) SFSafari 시트를 닫도록 신호.
            naverCallbackCount &+= 1
            guard markTokenHashConsumed(tokenHash) else { return }
            do {
                try await client.auth.verifyOTP(tokenHash: tokenHash, type: .magiclink)
            } catch {
                releaseTokenHash(tokenHash)  // 실패 시 재시도 허용(RN lib/naver.ts 동작)
                lastError = error.localizedDescription
            }
        case nil:
            break
        }
    }

    /// token_hash를 소비 처리. 신규면 true(verify 진행), 중복이면 false. 가드 로직 분리(테스트용).
    func markTokenHashConsumed(_ tokenHash: String) -> Bool {
        consumedTokenHashes.insert(tokenHash).inserted
    }

    /// verify 실패 시 token_hash 소비를 취소해 재시도를 허용한다.
    func releaseTokenHash(_ tokenHash: String) {
        consumedTokenHashes.remove(tokenHash)
    }

    /// Google/Kakao 등 Supabase OAuth 로그인(ASWebAuthenticationSession PKCE).
    /// 성공 시 세션은 authStateChanges로 반영. 유저 취소는 무시, 그 외 실패만 lastError.
    func signIn(provider: Provider) async {
        lastError = nil
        do {
            try await client.auth.signInWithOAuth(provider: provider, redirectTo: Self.oauthRedirect)
        } catch {
            if !Self.isUserCancellation(error) {
                lastError = error.localizedDescription
            }
        }
    }

    /// ASWebAuthenticationSession 유저 취소는 에러로 취급하지 않는다.
    static func isUserCancellation(_ error: Error) -> Bool {
        (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
    }

    // MARK: - 네이버(커스텀 OAuth)

    /// 네이버 웹 콜백. 서버가 magiclink token_hash를 만들어 `naverReturnURL`로 돌려보낸다.
    static let naverCallback = "https://clipnote.co.kr/api/auth/naver/callback"
    /// 콜백이 앱으로 복귀할 딥링크(#6 `clipnote://auth/naver`).
    static let naverReturnURL = "clipnote://auth/naver"

    /// state에 담기는 값. 서버가 returnUrl로 리다이렉트. RN `lib/naver.ts`와 동일 스키마.
    struct NaverState: Codable, Equatable {
        let returnUrl: String
        let n: String
    }

    /// 네이버 authorize URL 조립(순수·테스트용). RN `lib/naver.ts` 이식.
    static func makeNaverAuthURL(clientID: String, nonce: String) -> URL? {
        let state = NaverState(returnUrl: naverReturnURL, n: nonce)
        guard let data = try? JSONEncoder().encode(state),
              let stateJSON = String(data: data, encoding: .utf8) else { return nil }
        var comps = URLComponents(string: "https://nid.naver.com/oauth2.0/authorize")
        comps?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: naverCallback),
            URLQueryItem(name: "state", value: stateJSON),
        ]
        return comps?.url
    }

    /// 로그인 개시용 authorize URL. 설정된 client_id가 없으면 nil.
    /// 실제 로그인은 SFSafariViewController로 이 URL을 열고, 복귀는 딥링크(#6 `handle`)가 완료한다.
    func naverAuthURL(nonce: String) -> URL? {
        guard let clientID = Config.naverClientID else {
            lastError = "네이버 설정 없음"
            return nil
        }
        return Self.makeNaverAuthURL(clientID: clientID, nonce: nonce)
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    deinit { observeTask?.cancel() }
}
