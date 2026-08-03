import SwiftUI

/// 선택 클립에 태그 일괄 적용 — 추가(기존∪신규) / 교체(기존 무시). RN `components/TagApplyModal.tsx` 이식.
struct TagApplyModal: View {
    let count: Int
    let onApply: (_ tags: [String], _ mode: TagMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var i18n
    @State private var tagInput = ""
    @State private var mode: TagMode = .add

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(i18n.t("clips.bulkTagTitle"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColor.fg)
            // 대상 수는 제목에 괄호로 붙이지 않고 별도 줄에 둔다 — 웹과 같은 구성이고,
            // 수량 표기(`3개`/`3 clips`)는 언어마다 단위 위치가 달라 문장에서 떼어 만든다.
            Text(i18n.t("clips.bulkTagBody", args: i18n.t("clips.countUnit", args: count)))
                .font(.system(size: 13))
                .foregroundStyle(AppColor.fgMuted)

            Text(verbatim: "\(i18n.t("clips.editTagsLabel")) \(i18n.t("clips.editTagsNote"))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColor.fg)
            TextField(i18n.t("clips.editTagsPlaceholder"), text: $tagInput)
                .textInputAutocapitalization(.never)
                .modalField()

            HStack(spacing: 8) {
                modeChip(i18n.t("clips.bulkTagModeAddEmphasis"), .add)
                modeChip(i18n.t("clips.bulkTagModeReplaceEmphasis"), .replace)
            }
            // 칩 라벨(강조 낱말)을 문장에 끼워 설명을 만든다. 낱말 위치가 언어마다 달라
            // 앞/뒤로 쪼개 적을 수 없다 — ko `기존 태그에 {추가}` vs en `{Add} to existing tags`.
            Text(mode == .add
                 ? i18n.t("clips.bulkTagModeAdd", args: i18n.t("clips.bulkTagModeAddEmphasis"))
                 : i18n.t("clips.bulkTagModeReplace", args: i18n.t("clips.bulkTagModeReplaceEmphasis")))
                .font(.system(size: 12))
                .foregroundStyle(AppColor.fgMuted)

            HStack(spacing: 8) {
                Button(i18n.t("common.cancel")) { dismiss() }
                    .buttonStyle(ModalGhostButton())
                Button(i18n.t("clips.bulkTagApply")) { apply() }
                    .buttonStyle(ModalPrimaryButton())
            }
            .padding(.top, 8)
        }
        .padding(20)
        .sheetHeightFitsContent()
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
