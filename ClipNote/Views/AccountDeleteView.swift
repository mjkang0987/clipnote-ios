import SwiftUI

/// 회원 탈퇴 — 계정과 저장된 모든 클립을 영구 삭제. RN `app/account/delete.tsx` 이식.
/// 삭제는 서버(DELETE /api/account)가 처리하고, 성공 시 로컬 세션·로컬 클립을 비운다.
struct AccountDeleteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var i18n
    @EnvironmentObject private var auth: AuthStore

    @State private var agreed = false
    @State private var busy = false
    @State private var error: String?
    @State private var showConfirm = false
    @State private var showDone = false

    var body: some View {
        Group {
            if auth.loggedIn { form } else { guardView }
        }
        .background(AppColor.bg)
        .navigationTitle(i18n.t("settings.withdraw"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(i18n.t("settings.withdrawTitle"), isPresented: $showConfirm,
                            titleVisibility: .visible) {
            Button(i18n.t("settings.withdraw"), role: .destructive) { Task { await runDelete() } }
            Button(i18n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(i18n.t("settings.dangerBody"))
        }
        .alert(i18n.t("settings.withdrawDoneTitle"), isPresented: $showDone) {
            Button(i18n.t("common.confirm")) { dismiss() }
        } message: {
            Text(i18n.t("settings.withdrawDoneBody"))
        }
    }

    private var guardView: some View {
        VStack(spacing: 12) {
            Text(i18n.t("settings.guardBody"))
                .font(.system(size: 15)).foregroundStyle(AppColor.fgMuted)
            Button(i18n.t("settings.guardHome")) { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.brandStrong)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(i18n.t("settings.withdraw"))
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(AppColor.fg)
                Text(i18n.t("settings.withdrawBody"))
                    .font(.system(size: 14)).lineSpacing(3)
                    .foregroundStyle(AppColor.fgMuted).padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    // 글머리표는 목록 표시라 사전에 넣지 않는다.
                    Text("• \(i18n.t("settings.withdrawItemAccount"))")
                    Text("• \(i18n.t("settings.withdrawItemClips"))")
                    Text("• \(i18n.t("settings.withdrawItemLocal"))")
                }
                .font(.system(size: 14)).foregroundStyle(AppColor.fgMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppColor.border, lineWidth: 0.5))
                .padding(.top, 16)

                Button { agreed.toggle() } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(agreed ? AppColor.danger : AppColor.border, lineWidth: 1.5)
                                .background(RoundedRectangle(cornerRadius: 5).fill(agreed ? AppColor.danger : Color.clear))
                            if agreed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold)).foregroundStyle(AppColor.white)
                            }
                        }
                        .frame(width: 22, height: 22)
                        Text(i18n.t("settings.withdrawAgree"))
                            .font(.system(size: 14)).foregroundStyle(AppColor.fg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 16)

                if let error {
                    Text(error).font(.system(size: 14)).foregroundStyle(AppColor.danger).padding(.top, 12)
                }

                Button { showConfirm = true } label: {
                    Group {
                        if busy { ProgressView().tint(AppColor.white) }
                        else { Text(i18n.t("settings.withdraw")).font(.system(size: 15, weight: .semibold)) }
                    }
                    .foregroundStyle(AppColor.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(AppColor.danger)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
                .disabled(!agreed || busy)
                .opacity(!agreed || busy ? 0.5 : 1)
                .padding(.top, 20)

                Button(i18n.t("common.cancel")) { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.fgMuted)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .disabled(busy)
                    .padding(.top, 8)
            }
            .padding(20)
        }
    }

    private func runDelete() async {
        busy = true
        error = nil
        let res = await APIClient.shared.deleteAccount(accessToken: auth.accessToken)
        guard res.ok else {
            busy = false
            error = i18n.t(res.error == "network"
                           ? "settings.withdrawNetworkFailed"
                           : "settings.withdrawFailed")
            return
        }
        // 서버 삭제 완료 → 로컬 세션·로컬 클립 정리.
        LocalClipStore(container: modelContext.container).clearLocalClips()
        await auth.signOut()
        ClipsRefresh.emit()
        busy = false
        showDone = true
    }
}
