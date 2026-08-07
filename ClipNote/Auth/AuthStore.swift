import Foundation
import AuthenticationServices
import CryptoKit
import Supabase

/// Pure, testable snapshot of auth state. `loggedIn` is derived from token presence.
struct AuthState: Equatable {
    var accessToken: String?
    var loading: Bool
    var loggedIn: Bool { accessToken != nil }
}

/// 설정 화면 표시용 현재 로그인 계정 정보.
struct AccountInfo: Equatable {
    var email: String?
    var provider: String?

    /// 공급자 표시 이름. **라틴 표기로 고정하고 번역하지 않는다** — 언어마다 `카카오`/`カカオ`/
    /// `卡考` 로 갈리면 사용자가 자기가 무엇으로 로그인했는지 못 알아본다(웹과 같은 결정).
    ///
    /// 모르는 공급자는 nil 을 돌려주고, 화면이 `settings.providerUnknown`("소셜")을 쓴다.
    /// 여기서 한국어 대체 문구를 만들면 표시 언어를 바꿔도 그 낱말만 한국어로 남는다.
    var providerName: String? {
        switch provider {
        case "apple": "Apple"
        case "google": "Google"
        case "kakao": "Kakao"
        case "naver": "Naver"
        default: nil
        }
    }
}

/// 로그인 실패 사유. 문자열이 아니라 케이스로 두는 이유는 `HomeError` 와 같다 —
/// 표시 언어를 아는 건 뷰이고, 스토어가 문장을 만들면 그 시점 언어로 굳는다.
enum AuthErrorMessage: Equatable {
    /// 네이버 client_id 가 빌드에 없다(`Secrets.xcconfig` 누락).
    case naverNotConfigured
    /// 애플이 자격증명은 줬는데 identity token 이 없다. 이게 없으면 Supabase 에 넘길 게 없다.
    case appleTokenMissing
    /// Supabase·시스템이 준 설명. 이미 사람이 읽는 문장이라 그대로 보여 준다.
    case system(String)
}

/// Wraps `supabase-swift` auth. Session persistence (Keychain) and token refresh are
/// handled by the Supabase client; this store mirrors the session into observable state.
/// Ports RN `lib/auth.tsx`. OAuth flows (Google/Kakao/네이버) land in later sub-issues.
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var state = AuthState(accessToken: nil, loading: true)
    /// 마지막 로그인 실패 메시지(유저 취소는 제외). LoginView가 표시.
    @Published var lastError: AuthErrorMessage?
    /// 네이버 콜백 딥링크가 도착할 때마다 증가. LoginView가 이 변화에 맞춰 SFSafari 시트를 닫는다.
    /// (scenePhase `.active`는 SFSafari 표시 정착 등으로도 떠서 로그인 완료 전 시트가 닫히는 문제 회피.)
    @Published private(set) var naverCallbackCount = 0
    /// 현재 로그인 계정(이메일·provider). 설정 화면 표시용.
    @Published private(set) var account: AccountInfo?

    var accessToken: String? { state.accessToken }
    var loggedIn: Bool { state.loggedIn }

    /// 첫 프레임 깜빡임 방지용 표시 상태. 세션이 확정되기 전(`loading`)에는 지난 실행에서
    /// 저장해 둔 로그인 여부(persisted hint)를, 확정 후에는 실제 `loggedIn`을 쓴다.
    /// 로그인 상태로 재진입하면 Keychain 세션 복원 전에도 로그인 UI가 바로 떠 깜빡이지 않는다.
    /// 토큰이 필요한 동작은 여전히 진실값 `accessToken`으로 가드(첫 진입은 입력이 없어 버튼 비활성).
    var displayLoggedIn: Bool {
        state.loading ? defaults.bool(forKey: Self.lastLoggedInKey) : state.loggedIn
    }

    /// Supabase OAuth 콜백 리다이렉트. 딥링크 스킴(#6 AuthDeepLink)과 일치.
    static let oauthRedirect = URL(string: "clipnote://auth/callback")!

    /// 지난 실행의 로그인 여부를 담는 UserDefaults 키(`displayLoggedIn` 힌트).
    static let lastLoggedInKey = "clipnote.auth.lastLoggedIn"

    let client: SupabaseClient
    private let defaults: UserDefaults
    private var observeTask: Task<Void, Never>?
    /// token_hash는 1회용. 딥링크 중복 도착 시 재verify 방지(설계 §3.3).
    private var consumedTokenHashes = Set<String>()

    init(client: SupabaseClient, autoStart: Bool = true, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
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
                self.account = Self.accountInfo(from: change.session?.user)
            }
        }
    }

    /// Maps an optional access token into observable state. Extracted for testability.
    /// 확정된 로그인 여부를 저장해 다음 실행 첫 프레임의 `displayLoggedIn` 힌트로 쓴다.
    func apply(accessToken: String?) {
        state = AuthState(accessToken: accessToken, loading: false)
        defaults.set(state.loggedIn, forKey: Self.lastLoggedInKey)
    }

    /// Supabase 세션 유저에서 표시용 계정 정보를 뽑는다. provider는 app_metadata에서.
    static func accountInfo(from user: User?) -> AccountInfo? {
        guard let user else { return nil }
        var provider: String?
        if case let .string(p)? = user.appMetadata["provider"] { provider = p }
        return AccountInfo(email: user.email, provider: provider)
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
                lastError = .system(error.localizedDescription)
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
                lastError = .system(error.localizedDescription)
            }
        }
    }

    /// 유저 취소는 에러로 취급하지 않는다. 웹 로그인(Google/Kakao)과 애플 시트가 각각 다른
    /// 에러 타입으로 취소를 알려 오므로 둘 다 본다 — 한쪽만 보면 취소가 빨간 문구로 뜬다.
    static func isUserCancellation(_ error: Error) -> Bool {
        if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return true }
        if (error as? ASAuthorizationError)?.code == .canceled { return true }
        return false
    }

    // MARK: - Sign in with Apple (Guideline 4.8)

    /// nonce 에 쓰는 문자 집합. 애플이 id token 에 그대로 싣는 값이라 URL·JSON 에서 탈이 없는
    /// 문자만 둔다(RFC 3986 unreserved).
    private static let nonceCharacters = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"
    )

    /// 재생 공격 방지용 1회성 난수. `randomElement()` 는 애플 플랫폼에서 암호학적 난수
    /// (`SystemRandomNumberGenerator`)를 쓴다.
    static func randomNonce(length: Int = 32) -> String {
        String((0..<max(1, length)).compactMap { _ in nonceCharacters.randomElement() })
    }

    /// 애플에 넘길 nonce 해시. **애플에는 이 해시를, Supabase 에는 원본을 준다** —
    /// 원본을 애플에 주면 id token 에 평문으로 남고, 뒤바꿔 넣으면 검증만 조용히 떨어진다.
    static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// `SignInWithAppleButton` 의 결과를 세션으로 바꾼다. `nonce` 는 요청 때 만든 **원본**.
    /// 성공 시 세션은 `authStateChanges` → `apply` 로 반영된다.
    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>, nonce: String) async {
        lastError = nil
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let idToken = String(data: data, encoding: .utf8) else {
                lastError = .appleTokenMissing
                return
            }
            await signInWithApple(idToken: idToken, nonce: nonce)
        case let .failure(error):
            if !Self.isUserCancellation(error) {
                lastError = .system(error.localizedDescription)
            }
        }
    }

    /// 애플 id token 을 Supabase 세션으로 교환한다. 순수 네트워크 단계라 따로 뽑아 둔다.
    /// 여기까지 왔으면 사용자는 이미 시트를 끝낸 뒤라 취소를 가릴 일이 없다 — 실패는 곧 오류다.
    func signInWithApple(idToken: String, nonce: String) async {
        do {
            _ = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple, idToken: idToken, nonce: nonce
                )
            )
        } catch {
            lastError = .system(error.localizedDescription)
        }
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
            lastError = .naverNotConfigured
            return nil
        }
        return Self.makeNaverAuthURL(clientID: clientID, nonce: nonce)
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    deinit { observeTask?.cancel() }
}
