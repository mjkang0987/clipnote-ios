import SwiftUI
import Supabase

/// sheet(item:) 표시용 URL 래퍼.
private struct IdentifiedURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// 최소 로그인 화면 — Google/Kakao OAuth(#7) + 네이버 커스텀 OAuth(#8). 게스트·동의체크는 Phase 7.
struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var naverAuth: IdentifiedURL?

    var body: some View {
        VStack(spacing: 16) {
            Text("ClipNote")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.fg)
            Text("로그인")
                .foregroundStyle(AppColor.fgMuted)

            providerButton("Google로 계속", provider: .google)
            providerButton("카카오로 계속", provider: .kakao)
            naverButton

            if let error = auth.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppColor.danger)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .sheet(item: $naverAuth) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
        // 네이버 콜백 딥링크가 실제로 도착했을 때만 SFSafari 시트를 닫는다(성공·실패 무관).
        // scenePhase `.active`는 SFSafari 표시 정착 등으로도 떠서, 로그인(2단계 인증) 완료 전에
        // 시트가 저절로 닫히던 문제가 있어 콜백 신호 기반으로 바꿈.
        .onChange(of: auth.naverCallbackCount) { _, _ in
            naverAuth = nil
        }
        // 로그인 성공 시 시트(로그인 화면)를 닫는다.
        .onChange(of: auth.loggedIn) { _, now in
            if now { dismiss() }
        }
    }

    private var naverButton: some View {
        Button {
            let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)
            if let url = auth.naverAuthURL(nonce: String(nonce)) {
                naverAuth = IdentifiedURL(url: url)
            }
        } label: {
            Text("네이버로 계속")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColor.brandStrong)
                .foregroundStyle(AppColor.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    private func providerButton(_ title: String, provider: Provider) -> some View {
        Button {
            Task { await auth.signIn(provider: provider) }
        } label: {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColor.brand)
                .foregroundStyle(AppColor.white)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }
}
