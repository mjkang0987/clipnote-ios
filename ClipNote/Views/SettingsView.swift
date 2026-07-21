import SwiftUI

/// 설정 — 계정 정보·로그아웃·개인정보처리방침·문의·회원 탈퇴.
/// 웹 `app/settings/page.tsx` 이식. 로그인 사용자 전용(비로그인은 가드).
struct SettingsView: View {
    @Environment(AppRouter.self) private var router
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        Group {
            if auth.loggedIn { content } else { guardView }
        }
        .background(AppColor.bg)
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("계정 설정")
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(AppColor.fg)
                Text("로그인 정보와 계정을 관리합니다.")
                    .font(.system(size: 14)).foregroundStyle(AppColor.fgMuted)
                    .padding(.top, 4)

                accountSection.padding(.top, 24)
                linkRow("개인정보 처리방침") { router.go(.privacy) }
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
                    Text(auth.account?.label ?? "로그인됨")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.fg).lineLimit(1)
                    Text("\(auth.account?.providerLabel ?? "소셜") 계정으로 로그인됨")
                        .font(.system(size: 13)).foregroundStyle(AppColor.fgMuted).lineLimit(1)
                }
                Spacer(minLength: 12)
                Button("로그아웃") { Task { await auth.signOut() } }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.fgMuted)
            }
            .padding(.vertical, 20)
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
                    Text("보기 ›").font(.system(size: 14)).foregroundStyle(AppColor.fgMuted)
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - 문의

    private var contactRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().overlay(AppColor.border)
            Link(destination: URL(string: "mailto:pikaworks.help@gmail.com")!) {
                HStack {
                    Text("문의하기").font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColor.fg)
                    Spacer()
                    Text("메일 보내기 ›").font(.system(size: 14)).foregroundStyle(AppColor.fgMuted)
                }
                .padding(.vertical, 16)
            }
            Text("오류 제보·기능 요청은 pikaworks.help@gmail.com 로 보내 주세요.")
                .font(.system(size: 12)).foregroundStyle(AppColor.fgMuted)
                .padding(.bottom, 4)
        }
    }

    // MARK: - 위험 구역(회원 탈퇴)

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("계정 삭제")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColor.danger)
            Text("탈퇴하면 계정과 저장된 모든 클립·공유 링크가 영구 삭제되며 복구할 수 없어요.")
                .font(.system(size: 14)).lineSpacing(3).foregroundStyle(AppColor.fgMuted)
            Button("회원 탈퇴") { router.go(.accountDelete) }
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
        VStack(spacing: 12) {
            Text("로그인 후 이용할 수 있어요.")
                .font(.system(size: 15)).foregroundStyle(AppColor.fgMuted)
            Button("홈으로") { router.home() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.brandStrong)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
