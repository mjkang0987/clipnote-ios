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
