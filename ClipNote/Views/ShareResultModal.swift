import SwiftUI

/// 공유 링크 생성 결과 시트 — 복사(§4.3)·열기·내 클립에 저장·닫기.
/// RN `components/ShareResultModal.tsx` 이식. 복사는 제목+설명+링크(§4.3 buildShareText).
struct ShareResultModal: View {
    let title: String
    let description: String?
    let url: String
    /// "내 클립에 저장" — 성공 시 true 반환.
    let onSave: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var saving = false
    @State private var saved = false
    @State private var showSafari = false

    private var safariURL: URL? { URL(string: url) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("공유 링크가 만들어졌어요 🎉")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColor.fg)
            Text("링크를 복사해 공유하세요. 열면 공유 카드가 먼저 보인 뒤 원본으로 이동해요.")
                .font(.system(size: 13))
                .foregroundStyle(AppColor.fgMuted)

            Text(url)
                .font(.system(size: 13))
                .foregroundStyle(AppColor.fg)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(AppColor.border, lineWidth: 0.5))
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button { copy() } label: {
                    Text(copied ? "복사됨 ✓" : "링크 복사")
                }
                .buttonStyle(ModalPrimaryButton())

                Button { showSafari = true } label: {
                    Text("열기")
                }
                .buttonStyle(ModalGhostButton())
                .disabled(safariURL == nil)
            }

            Button {
                Task { await save() }
            } label: {
                SpinnerLabel(title: saved ? "내 클립에 저장됨 ✓" : (saving ? "저장 중…" : "내 클립에 저장"),
                             loading: saving, tint: AppColor.brandStrong)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.brandStrong)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(AppColor.brandSoft)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(AppColor.brand, lineWidth: 0.5))
            }
            .disabled(saving || saved)
            .opacity(saving || saved ? 0.6 : 1)

            Button("닫기") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColor.fgMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(20)
        .presentationDetents([.height(320)])
        .sheet(isPresented: $showSafari) {
            if let safariURL { SafariView(url: safariURL) }
        }
    }

    private func copy() {
        UIPasteboard.general.string = buildShareText(title: title, description: description, url: url)
        copied = true
        Task { try? await Task.sleep(for: .milliseconds(1500)); copied = false }
    }

    private func save() async {
        guard !saving, !saved else { return }
        saving = true
        let ok = await onSave()
        saving = false
        if ok { saved = true }
    }
}
