import Testing
import Foundation
@testable import ClipNote

@Suite struct AuthDeepLinkTests {
    private func url(_ s: String) -> URL { URL(string: s)! }

    @Test func parsesOAuthCallback() {
        #expect(AuthDeepLink.parse(url("clipnote://auth/callback?code=abc123"))
                == .oauthCallback(code: "abc123"))
    }

    @Test func parsesNaver() {
        #expect(AuthDeepLink.parse(url("clipnote://auth/naver?token_hash=xyz"))
                == .naver(tokenHash: "xyz"))
    }

    @Test func naverIgnoresExtraQuery() {
        #expect(AuthDeepLink.parse(url("clipnote://auth/naver?token_hash=xyz&state=home"))
                == .naver(tokenHash: "xyz"))
    }

    @Test func nilOnWrongScheme() {
        #expect(AuthDeepLink.parse(url("https://auth/callback?code=abc")) == nil)
    }

    @Test func nilOnWrongHost() {
        #expect(AuthDeepLink.parse(url("clipnote://other/callback?code=abc")) == nil)
    }

    @Test func nilOnUnknownPath() {
        #expect(AuthDeepLink.parse(url("clipnote://auth/unknown?code=abc")) == nil)
    }

    @Test func nilWhenCodeMissing() {
        #expect(AuthDeepLink.parse(url("clipnote://auth/callback")) == nil)
    }

    @Test func nilWhenTokenHashEmpty() {
        #expect(AuthDeepLink.parse(url("clipnote://auth/naver?token_hash=")) == nil)
    }
}
