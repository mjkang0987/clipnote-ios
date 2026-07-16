import SwiftUI

/// 선택 클립에 태그 일괄 적용 — 추가(기존∪신규) / 교체(기존 무시). RN `components/TagApplyModal.tsx` 이식.
struct TagApplyModal: View {
    let count: Int
    let onApply: (_ tags: [String], _ mode: TagMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tagInput = ""
    @State private var mode: TagMode = .add

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("태그 적용 (\(count)개)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColor.fg)

            Text("태그 (쉼표로 구분, 최대 6개)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.fg)
            TextField("개발, 디자인", text: $tagInput)
                .textInputAutocapitalization(.never)
                .modalField()

            HStack(spacing: 8) {
                modeChip("추가", .add)
                modeChip("교체", .replace)
            }
            Text(mode == .add ? "기존 태그에 더해요." : "기존 태그를 지우고 이 태그로 바꿔요.")
                .font(.system(size: 12))
                .foregroundStyle(AppColor.fgMuted)

            HStack(spacing: 8) {
                Button("취소") { dismiss() }
                    .buttonStyle(ModalGhostButton())
                Button("적용") { apply() }
                    .buttonStyle(ModalPrimaryButton())
            }
            .padding(.top, 8)
        }
        .padding(20)
        .presentationDetents([.height(300)])
    }

    private func modeChip(_ label: String, _ value: TagMode) -> some View {
        let on = mode == value
        return Button { mode = value } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(on ? AppColor.brandStrong : AppColor.fgMuted)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(on ? AppColor.brandSoft : AppColor.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(on ? AppColor.brand : AppColor.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func apply() {
        let tags = parseTags(tagInput)
        // 교체는 빈 태그(전체 삭제)도 허용, 추가는 태그 있을 때만.
        if mode == .replace || !tags.isEmpty {
            onApply(tags, mode)
        }
        dismiss()
    }
}
