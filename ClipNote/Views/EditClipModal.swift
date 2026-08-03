import SwiftUI

/// 단건 편집 시트 — 제목·태그 수정. 저장 방식(로컬/DB)은 호출부가 `onSubmit`에서 결정.
/// RN `components/EditClipModal.tsx` 이식.
struct EditClipModal: View {
    let initialTitle: String
    let initialTags: [String]
    let onSubmit: (String, [String]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var i18n
    @State private var title = ""
    @State private var tagInput = ""
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(i18n.t("clips.editTitle"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColor.fg)

            labeled(i18n.t("clips.editTitleLabel")) {
                TextField(i18n.t("clips.editTitleLabel"), text: $title).modalField()
            }
            // 라벨과 보조 설명은 사전에서 따로 둔다 — 웹도 굵게/흐리게로 나눠 그린다.
            labeled("\(i18n.t("clips.editTagsLabel")) \(i18n.t("clips.editTagsNote"))") {
                TextField(i18n.t("clips.editTagsPlaceholder"), text: $tagInput)
                    .textInputAutocapitalization(.never)
                    .modalField()
            }

            HStack(spacing: 8) {
                Button(i18n.t("common.cancel")) { dismiss() }
                    .buttonStyle(ModalGhostButton())
                Button {
                    Task { await save() }
                } label: {
                    SpinnerLabel(title: i18n.t(saving ? "clips.savingEdit" : "common.save"), loading: saving)
                }
                .buttonStyle(ModalPrimaryButton())
                .disabled(saving)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .onAppear {
            title = initialTitle
            tagInput = initialTags.joined(separator: ", ")
        }
        .sheetHeightFitsContent()
    }

    private func save() async {
        guard !saving else { return }
        saving = true
        let tags = parseTags(tagInput)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmed.isEmpty ? initialTitle : trimmed
        await onSubmit(finalTitle, tags)
        saving = false
        dismiss()
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(AppColor.fg)
            content()
        }
    }
}

// MARK: - 공용 모달 스타일

extension View {
    func modalField() -> some View {
        self
            .font(.system(size: 15))
            .foregroundStyle(AppColor.fg)
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(AppColor.border, lineWidth: 0.5))
    }
}

struct ModalPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColor.white)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(configuration.isPressed ? AppColor.brandStrong : AppColor.brand)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}

struct ModalGhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColor.fg)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(configuration.isPressed ? AppColor.border : AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(AppColor.border, lineWidth: 0.5))
    }
}
