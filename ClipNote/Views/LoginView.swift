import SwiftUI
import AuthenticationServices
import Supabase

/// sheet(item:) 표시용 URL 래퍼.
private struct IdentifiedURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// 로그인 화면 — 웹 `app/login/page.tsx` 이식.
/// 브랜드색 SNS 버튼 + 개인정보 동의 + 게스트 계속 + 최근 로그인 배지 + 안내.
struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var i18n

    /// 마지막 로그인 수단(이 기기 기준) — "최근 로그인" 배지용. 웹 localStorage 대응.
    @AppStorage("clipnote.lastLoginProvider") private var lastProvider = ""
    @State private var agreed = false
    @State private var consentError = false
    @State private var loadingProvider: String?
    @State private var naverAuth: IdentifiedURL?
    @State private var privacy: IdentifiedURL?
    /// 애플 요청 때 만든 **원본** nonce. 애플에는 해시를 주고 검증에는 이 값을 쓴다.
    @State private var appleNonce = ""

    private let privacyURL = URL(string: "https://clipnote.co.kr/privacy")!

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                consentBox
                buttons
                if consentError {
                    Text(i18n.t("login.errorConsent"))
                        .font(.system(size: 13)).foregroundStyle(AppColor.danger)
                        .frame(maxWidth: .infinity)
                }
                if let error = auth.lastError {
                    Text(message(for: error))
                        .font(.system(size: 13)).foregroundStyle(AppColor.danger)
                        .multilineTextAlignment(.center)
                }
                divider
                guestButton
                infoSection.padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
        }
        .background(AppColor.bg)
        .sheet(item: $naverAuth) { item in SafariView(url: item.url).ignoresSafeArea() }
        .sheet(item: $privacy) { item in SafariView(url: item.url).ignoresSafeArea() }
        .onChange(of: auth.naverCallbackCount) { _, _ in naverAuth = nil; loadingProvider = nil }
        .onChange(of: auth.lastError) { _, _ in loadingProvider = nil }
        .onChange(of: auth.loggedIn) { _, now in if now { dismiss() } }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image("BrandIcon")
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(verbatim: "ClipNote").font(.largeTitle.bold()).foregroundStyle(AppColor.fg)
            }
            Text(i18n.t("common.login")).font(.system(size: 20, weight: .bold)).foregroundStyle(AppColor.fg)
            Text(i18n.t("login.subtitleWithKakao"))
                .font(.system(size: 14)).foregroundStyle(AppColor.fgMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    // MARK: - 동의

    private var consentBox: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                agreed.toggle()
                if agreed { consentError = false }
            } label: {
                Image(systemName: agreed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(agreed ? AppColor.brand : AppColor.fgMuted)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t("login.consent"))
                    .font(.system(size: 13)).foregroundStyle(AppColor.fgMuted)
                    .contentShape(Rectangle())
                    .onTapGesture { agreed.toggle(); if agreed { consentError = false } }
                Button(i18n.t("login.privacyCheck")) { privacy = IdentifiedURL(url: privacyURL) }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(AppColor.brandStrong)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppColor.border, lineWidth: 1))
    }

    // MARK: - SNS 버튼

    private var buttons: some View {
        VStack(spacing: 12) {
            // 맨 위에 둔다. Guideline 4.8 은 서드파티 로그인과 **동등한 노출**을 요구한다.
            appleButton
            // 공급자 이름은 라틴 표기로 고정한다 — 번역하면 사용자가 자기 계정을 못 알아본다.
            brandButton(provider: "Google", key: "google",
                        bg: AppColor.bg, fg: AppColor.fg, border: true) {
                start("google") { await auth.signIn(provider: .google) }
            }
            brandButton(provider: "Kakao", key: "kakao",
                        bg: Color(hex: 0xFEE500), fg: Color(hex: 0x191600), border: false) {
                start("kakao") { await auth.signIn(provider: .kakao) }
            }
            brandButton(provider: "Naver", key: "naver",
                        bg: Color(hex: 0x03C75A), fg: AppColor.white, border: false) {
                startNaver()
            }
        }
    }

    /// Sign in with Apple. **시스템 버튼을 쓴다** — 로고·모서리·문구에 브랜딩 규정이 있어
    /// 직접 그리면 그 자체가 지적 사유가 된다. `brandButton` 을 재사용하지 않는 유일한 예외다.
    ///
    /// 대신 문구는 **기기 언어**를 따른다(시스템이 그리는 버튼이라 `LocalizationStore` 가 닿지
    /// 않는다). 앱 표시 언어와 갈릴 수 있는데, 규정 준수를 택했다.
    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            let nonce = AuthStore.randomNonce()
            appleNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = AuthStore.sha256Hex(nonce)
        } onCompletion: { result in
            lastProvider = "apple"
            loadingProvider = "apple"
            let nonce = appleNonce
            // 성공하면 `auth.loggedIn` 변화가 화면을 닫는다. 실패·취소는 여기서 직접 푼다 —
            // `lastError` 변화를 기다리면 취소(에러 없음)에서 버튼이 잠긴 채 남는다.
            Task {
                await auth.completeAppleSignIn(result, nonce: nonce)
                loadingProvider = nil
            }
        }
        .signInWithAppleButtonStyle(.black)
        // 다른 버튼과 **같은 크기**로 못박는다. 4.8 은 동등한 노출을 요구하고, 시스템 버튼의
        // 기본 크기에 맡기면 폭이 갈릴 수 있다.
        .frame(maxWidth: .infinity).frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(alignment: .trailing) {
            if lastProvider == "apple" && loadingProvider == nil {
                recentBadge.padding(.trailing, 12).allowsHitTesting(false)
            }
        }
        // 동의 전에는 시스템 시트가 뜨기 전에 막아야 한다. 이 버튼은 탭을 가로챌 자리가 없어
        // (`onRequest` 는 이미 요청이 시작된 뒤다) 투명 버튼을 덮어 다른 버튼과 동작을 맞춘다.
        .overlay {
            if !agreed {
                Button { consentError = true } label: {
                    Color.clear.contentShape(Rectangle())
                }
            }
        }
        .disabled(loadingProvider != nil)
        .opacity(loadingProvider != nil && loadingProvider != "apple" ? 0.5 : 1)
    }

    private func brandButton(provider: String, key: String, bg: Color, fg: Color,
                             border: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(loadingProvider == key
                     ? i18n.t("login.redirecting")
                     : i18n.t("login.continueWith", args: provider))
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(fg)
                    .frame(maxWidth: .infinity).frame(height: 48)
                if lastProvider == key && loadingProvider == nil {
                    HStack { Spacer(); recentBadge.padding(.trailing, 12) }
                }
            }
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md)
                .stroke(border ? AppColor.border : Color.clear, lineWidth: 1))
        }
        .disabled(loadingProvider != nil)
        .opacity(loadingProvider != nil && loadingProvider != key ? 0.5 : 1)
    }

    private var recentBadge: some View {
        Text(i18n.t("login.recent"))
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(AppColor.brandStrong)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(AppColor.brandSoft).clipShape(Capsule())
    }

    // MARK: - 게스트 / 구분선

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(AppColor.border).frame(height: 1)
            Text(i18n.t("login.or")).font(.system(size: 12)).foregroundStyle(AppColor.fgMuted)
            Rectangle().fill(AppColor.border).frame(height: 1)
        }
    }

    private var guestButton: some View {
        Button(i18n.t("login.continueAsGuest")) { dismiss() }
            .font(.system(size: 16, weight: .semibold)).foregroundStyle(AppColor.fgMuted)
            .frame(maxWidth: .infinity).frame(height: 48)
    }

    // MARK: - 안내

    private var infoSection: some View {
        VStack(spacing: 12) {
            Text(i18n.t("login.compareTitle"))
                .font(.system(size: 12, weight: .semibold)).kerning(0.5)
                .foregroundStyle(AppColor.fgMuted)
            // 강조 낱말은 문장 안에 자리표시자로 두고 여기서 끼워 넣는다. 앞/뒤로 쪼개 적으면
            // 어순이 다른 언어에서 깨진다 — 웹 CompareBoxes 와 같은 한 벌·같은 순서다.
            infoBox(title: i18n.t("compare.signedInTitle"), accent: true, items: [
                i18n.t("compare.signedInItem1", args: i18n.t("compare.signedInItem1Emphasis")),
                i18n.t("compare.signedInItem2"),
                i18n.t("compare.signedInItem3", args: i18n.t("compare.signedInItem3Emphasis")),
            ])
            infoBox(title: i18n.t("compare.guestTitle"), accent: false, items: [
                i18n.t("compare.guestItem1"),
                i18n.t("compare.guestItem2", args: i18n.t("common.myClips")),
                i18n.t("compare.guestItem3",
                       args: i18n.t("compare.guestItem3Device"),
                       i18n.t("compare.guestItem3NoLink")),
            ])
        }
        .padding(.top, 12)
    }

    private func infoBox(title: String, accent: Bool, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent ? AppColor.brandStrong : AppColor.fg)
            ForEach(items, id: \.self) { item in
                // 글머리표는 문구가 아니라 목록 표시라 사전에 넣지 않는다(번역 대상이 아니다).
                Text(verbatim: "· \(item)").font(.system(size: 13)).lineSpacing(2)
                    .foregroundStyle(AppColor.fgMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(accent ? AppColor.brandSoft : AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md)
            .stroke(accent ? AppColor.brand.opacity(0.3) : AppColor.border, lineWidth: 0.5))
    }

    // MARK: - 액션

    /// 로그인 실패 사유를 현재 언어의 문장으로. 시스템/Supabase 문장은 그대로 쓴다.
    private func message(for error: AuthErrorMessage) -> String {
        switch error {
        case .naverNotConfigured: i18n.t("login.errorNaverNotConfigured")
        case .appleTokenMissing: i18n.t("login.errorAppleTokenMissing")
        case .system(let text): text
        }
    }

    private func start(_ key: String, _ action: @escaping () async -> Void) {
        guard agreed else { consentError = true; return }
        consentError = false
        lastProvider = key
        loadingProvider = key
        // 끝나면 여기서 직접 푼다. `lastError` 변화만 보고 풀면 **취소가 새지 않는다** —
        // 취소는 에러로 치지 않아 `lastError` 가 nil 그대로고, nil→nil 은 onChange 가 뜨지
        // 않아 로그인 버튼 전체가 비활성으로 굳는다.
        Task { await action(); loadingProvider = nil }
    }

    private func startNaver() {
        guard agreed else { consentError = true; return }
        consentError = false
        lastProvider = "naver"
        loadingProvider = "naver"
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)
        if let url = auth.naverAuthURL(nonce: String(nonce)) {
            naverAuth = IdentifiedURL(url: url)
        } else {
            loadingProvider = nil
        }
    }
}
