import SwiftUI

/// 좌측 헤더 햄버거 메뉴 — 화면 이동 + 로그인/로그아웃/회원탈퇴 + 개인정보.
/// RN `components/HeaderMenu.tsx` 이식(사이드 슬라이드 → iOS 네이티브 Menu). 상위 화면 toolbar에 배치.
struct HeaderMenu: View {
    @Environment(AppRouter.self) private var router
    @Environment(LocalizationStore.self) private var i18n
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        Menu {
            Button(i18n.t("clips.newClip")) { router.home() }
            Button(i18n.t("common.myClips")) { router.go(.clips) }
            Button(i18n.t("menu.tour")) { router.showTour = true }
            Button(i18n.t("menu.about")) { router.go(.about) }
            Button(i18n.t("faq.title")) { router.go(.faq) }

            Divider()

            if auth.loggedIn {
                Button(i18n.t("common.settings")) { router.go(.settings) }
                Button(i18n.t("common.logout")) { Task { await auth.signOut() } }
            } else {
                Button(i18n.t("common.login")) { router.showLogin = true }
            }

            Divider()

            Button(i18n.t("common.privacy")) { router.go(.privacy) }
        } label: {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(AppColor.fg)
        }
        .accessibilityLabel(i18n.t("menu.aria"))
    }
}
