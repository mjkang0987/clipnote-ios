import SwiftUI

/// 좌측 헤더 햄버거 메뉴 — 화면 이동 + 로그인/로그아웃/회원탈퇴 + 개인정보.
/// RN `components/HeaderMenu.tsx` 이식(사이드 슬라이드 → iOS 네이티브 Menu). 상위 화면 toolbar에 배치.
struct HeaderMenu: View {
    @Environment(AppRouter.self) private var router
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        Menu {
            Button("+ 새 클립") { router.home() }
            Button("내 클립") { router.go(.clips) }
            Button("사용법") { router.go(.onboarding) }
            Button("소개") { router.go(.about) }
            Button("자주 묻는 질문") { router.go(.faq) }

            Divider()

            if auth.loggedIn {
                Button("로그아웃") { Task { await auth.signOut() } }
                Button("회원 탈퇴", role: .destructive) { router.go(.accountDelete) }
            } else {
                Button("로그인") { router.showLogin = true }
            }

            Divider()

            Button("개인정보 처리방침") { router.openPrivacy() }
        } label: {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(AppColor.fg)
        }
        .accessibilityLabel("메뉴 열기")
    }
}
