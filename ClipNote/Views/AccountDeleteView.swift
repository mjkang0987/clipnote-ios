import SwiftUI

/// 회원 탈퇴 — 계정과 저장된 모든 클립을 영구 삭제. RN `app/account/delete.tsx` 이식.
/// 삭제는 서버(DELETE /api/account)가 처리하고, 성공 시 로컬 세션·로컬 클립을 비운다.
struct AccountDeleteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
        .navigationTitle("회원 탈퇴")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("정말 탈퇴할까요?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("탈퇴하기", role: .destructive) { Task { await runDelete() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("계정과 저장된 모든 클립이 영구적으로 삭제되며 복구할 수 없어요.")
        }
        .alert("탈퇴 완료", isPresented: $showDone) {
            Button("확인") { dismiss() }
        } message: {
            Text("계정과 저장된 클립이 모두 삭제되었어요.")
        }
    }

    private var guardView: some View {
        VStack(spacing: 12) {
            Text("로그인 후 이용할 수 있어요.")
                .font(.system(size: 15)).foregroundStyle(AppColor.fgMuted)
            Button("홈으로") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.brandStrong)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("회원 탈퇴")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(AppColor.fg)
                Text("탈퇴하면 아래 정보가 영구적으로 삭제되며 복구할 수 없어요.")
                    .font(.system(size: 14)).lineSpacing(3)
                    .foregroundStyle(AppColor.fgMuted).padding(.top, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text("• 계정 정보(소셜 로그인 식별자·이메일·프로필)")
                    Text("• 저장한 모든 클립과 공유 링크")
                    Text("• 이 기기에 보관된 클립")
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
                        Text("위 내용을 확인했으며, 모든 데이터가 삭제되는 것에 동의합니다.")
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
                        else { Text("회원 탈퇴").font(.system(size: 15, weight: .semibold)) }
                    }
                    .foregroundStyle(AppColor.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(AppColor.danger)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
                .disabled(!agreed || busy)
                .opacity(!agreed || busy ? 0.5 : 1)
                .padding(.top, 20)

                Button("취소") { dismiss() }
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
            error = res.error == "network"
                ? "네트워크 문제로 탈퇴하지 못했어요. 잠시 후 다시 시도해 주세요."
                : "탈퇴 처리에 실패했어요. 잠시 후 다시 시도해 주세요."
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
