import SwiftUI
import Supabase

/// 최소 로그인 화면 — Google/Kakao OAuth 개시(#7). 네이버·게스트·동의체크는 #8/Phase 7에서 확장.
struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        VStack(spacing: 16) {
            Text("ClipNote")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.fg)
            Text("로그인")
                .foregroundStyle(AppColor.fgMuted)

            providerButton("Google로 계속", provider: .google)
            providerButton("카카오로 계속", provider: .kakao)

            if let error = auth.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppColor.danger)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
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
