import SwiftUI
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

    /// 마지막 로그인 수단(이 기기 기준) — "최근 로그인" 배지용. 웹 localStorage 대응.
    @AppStorage("clipnote.lastLoginProvider") private var lastProvider = ""
    @State private var agreed = false
    @State private var consentError = false
    @State private var loadingProvider: String?
    @State private var naverAuth: IdentifiedURL?
    @State private var privacy: IdentifiedURL?

    private let privacyURL = URL(string: "https://clipnote.co.kr/privacy")!

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                consentBox
                buttons
                if consentError {
                    Text("개인정보처리방침에 동의하셔야 로그인할 수 있어요.")
                        .font(.system(size: 13)).foregroundStyle(AppColor.danger)
                        .frame(maxWidth: .infinity)
                }
                if let error = auth.lastError {
                    Text(error)
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
            Text("ClipNote").font(.largeTitle.bold()).foregroundStyle(AppColor.fg)
            Text("로그인").font(.system(size: 20, weight: .bold)).foregroundStyle(AppColor.fg)
            Text("Google·카카오 계정으로 간편하게 시작하세요.")
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
                Text("로그인 시 회원 식별을 위해 소셜 계정 정보(고유 식별자, 이메일, 프로필 닉네임·이미지)가 수집되는 데 동의합니다.")
                    .font(.system(size: 13)).foregroundStyle(AppColor.fgMuted)
                Button("개인정보처리방침 확인") { privacy = IdentifiedURL(url: privacyURL) }
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
            brandButton(title: "Google로 계속하기", key: "google",
                        bg: AppColor.bg, fg: AppColor.fg, border: true) {
                start("google") { await auth.signIn(provider: .google) }
            }
            brandButton(title: "카카오로 계속하기", key: "kakao",
                        bg: Color(hex: 0xFEE500), fg: Color(hex: 0x191600), border: false) {
                start("kakao") { await auth.signIn(provider: .kakao) }
            }
            brandButton(title: "네이버로 계속하기", key: "naver",
                        bg: Color(hex: 0x03C75A), fg: AppColor.white, border: false) {
                startNaver()
            }
        }
    }

    private func brandButton(title: String, key: String, bg: Color, fg: Color,
                             border: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(loadingProvider == key ? "이동 중…" : title)
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
        Text("최근 로그인")
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(AppColor.brandStrong)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(AppColor.brandSoft).clipShape(Capsule())
    }

    // MARK: - 게스트 / 구분선

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(AppColor.border).frame(height: 1)
            Text("또는").font(.system(size: 12)).foregroundStyle(AppColor.fgMuted)
            Rectangle().fill(AppColor.border).frame(height: 1)
        }
    }

    private var guestButton: some View {
        Button("게스트로 계속하기") { dismiss() }
            .font(.system(size: 16, weight: .semibold)).foregroundStyle(AppColor.fgMuted)
            .frame(maxWidth: .infinity).frame(height: 48)
    }

    // MARK: - 안내

    private var infoSection: some View {
        VStack(spacing: 12) {
            Text("로그인 / 게스트 모드 안내")
                .font(.system(size: 12, weight: .semibold)).kerning(0.5)
                .foregroundStyle(AppColor.fgMuted)
            infoBox(title: "로그인 하면", accent: true, items: [
                "· 짧은 공유 링크를 만들어 카카오톡·SNS에 보낼 수 있어요.",
                "· 공유한 링크가 제목·이미지가 담긴 미리보기 카드로 떠요.",
                "· 클립이 계정에 쌓여 다른 기기에서도 그대로 보이고, 태그로 정리돼요.",
            ])
            infoBox(title: "로그인 안 해도", accent: false, items: [
                "· URL을 붙여넣어 미리보기 카드를 만들 수 있어요.",
                "· 만든 클립을 이 기기에 저장하고 '내 클립'에서 다시 봐요.",
                "· 단, 저장은 이 기기에만 남고 짧은 공유 링크는 못 만들어요.",
            ])
        }
        .padding(.top, 12)
    }

    private func infoBox(title: String, accent: Bool, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent ? AppColor.brandStrong : AppColor.fg)
            ForEach(items, id: \.self) { item in
                Text(item).font(.system(size: 13)).lineSpacing(2)
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

    private func start(_ key: String, _ action: @escaping () async -> Void) {
        guard agreed else { consentError = true; return }
        consentError = false
        lastProvider = key
        loadingProvider = key
        Task { await action() }
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
