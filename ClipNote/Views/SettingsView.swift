import SwiftUI

/// 설정 — 표시 언어·계정 정보·로그아웃·개인정보처리방침·문의·회원 탈퇴.
/// 웹 `app/settings/page.tsx` 이식. 계정 관련 항목은 로그인 사용자 전용(비로그인은 가드).
/// 표시 언어는 로그인과 무관하게 항상 바꿀 수 있다 — 게스트가 언어를 못 고르면 안 되므로
/// 가드 화면에도 같은 행을 노출한다.
struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(LocalizationStore.self) private var i18n
    @EnvironmentObject private var auth: AuthStore

    /// 문의 메일 주소 — 본문 안내와 mailto 링크가 같은 값을 쓰도록 한 곳에 둔다.
    private let contactEmail = "pikaworks.help@gmail.com"

    var body: some View {
        Group {
            if auth.loggedIn { content } else { guardView }
        }
        .background(AppColor.bg)
        .navigationTitle(i18n.t("common.settings"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(i18n.t("settings.title"))
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(AppColor.fg)
                Text(i18n.t("settings.subtitle"))
                    .font(.system(size: 14)).foregroundStyle(AppColor.fgMuted)
                    .padding(.top, 4)

                accountSection.padding(.top, 24)
                languageRow
                linkRow(i18n.t("common.privacy")) { router.go(.privacy) }
                contactRow
                dangerSection.padding(.top, 16)
            }
            .padding(20)
        }
    }

    // MARK: - 계정 정보 + 로그아웃

    private var accountSection: some View {
        VStack(spacing: 0) {
            Divider().overlay(AppColor.border)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.fg).lineLimit(1)
                    Text(i18n.t("settings.signedInWith", args: providerName))
                        .font(.system(size: 13)).foregroundStyle(AppColor.fgMuted).lineLimit(1)
                }
                Spacer(minLength: 12)
                Button(i18n.t("common.logout")) { Task { await auth.signOut() } }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.fgMuted)
            }
            .padding(.vertical, 20)
        }
    }

    /// 계정 표시 이름 — 이메일이 있으면 그것, 없으면 공급자 이름(네이버는 이메일을 주지 않는다).
    /// 둘 다 없을 때만 사전의 대체 문구를 쓴다. 여기에 `providerName` 의 폴백("소셜")이 오면
    /// 이름 자리에 분류명이 들어가 어색해진다.
    private var accountLabel: String {
        auth.account?.email ?? auth.account?.providerName ?? i18n.t("settings.accountFallback")
    }

    /// 공급자 이름. 라틴 표기 고정이라 번역하지 않고, 모르는 공급자일 때만 사전을 쓴다.
    private var providerName: String {
        auth.account?.providerName ?? i18n.t("settings.providerUnknown")
    }

    // MARK: - 표시 언어

    /// 언어 선택. 고르면 재시작 없이 즉시 화면 문자열이 바뀐다(`LocalizationStore`).
    /// 각 언어는 그 언어로 표기한다(`AppLanguage.label`).
    private var languageRow: some View {
        VStack(spacing: 0) {
            Divider().overlay(AppColor.border)
            HStack {
                Text(i18n.t("settings.language"))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColor.fg)
                Spacer()
                // Picker 를 그대로 쓰면 기본 본문 크기(17pt)로 그려져 다른 행보다 커진다.
                // Menu 라벨을 직접 만들어 linkRow·contactRow 의 보조 텍스트와 같은 모양으로 맞춘다.
                Menu {
                    Picker(
                        i18n.t("settings.language"),
                        selection: Binding(get: { i18n.language }, set: { i18n.select($0) })
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.label).tag(language)
                        }
                    }
                } label: {
                    Text("\(i18n.language.label) ›")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColor.fgMuted)
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - 링크 행(개인정보처리방침)

    private func linkRow(_ title: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(AppColor.border)
            Button(action: action) {
                HStack {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColor.fg)
                    Spacer()
                    Text(i18n.t("settings.viewLink")).font(.system(size: 14)).foregroundStyle(AppColor.fgMuted)
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - 문의

    private var contactRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().overlay(AppColor.border)
            Link(destination: URL(string: "mailto:\(contactEmail)")!) {
                HStack {
                    Text(i18n.t("settings.contact")).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColor.fg)
                    Spacer()
                    Text(i18n.t("settings.contactAction")).font(.system(size: 14)).foregroundStyle(AppColor.fgMuted)
                }
                .padding(.vertical, 16)
            }
            Text(i18n.t("settings.contactNote", args: contactEmail))
                .font(.system(size: 12)).foregroundStyle(AppColor.fgMuted)
                .padding(.bottom, 4)
        }
    }

    // MARK: - 위험 구역(회원 탈퇴)

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(i18n.t("settings.dangerTitle"))
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColor.danger)
            Text(i18n.t("settings.dangerBody"))
                .font(.system(size: 14)).lineSpacing(3).foregroundStyle(AppColor.fgMuted)
            Button(i18n.t("settings.withdraw")) { router.go(.accountDelete) }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColor.danger)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.danger.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppColor.danger.opacity(0.3), lineWidth: 0.5))
    }

    // MARK: - 비로그인 가드

    private var guardView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // 언어는 로그인 없이도 바꿀 수 있어야 한다.
                languageRow
                Text(i18n.t("settings.guardBody"))
                    .font(.system(size: 15)).foregroundStyle(AppColor.fgMuted)
                    .padding(.top, 24)
                Button(i18n.t("settings.guardHome")) { router.home() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.brandStrong)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
    }
}
