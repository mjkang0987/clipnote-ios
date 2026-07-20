import SwiftUI

/// 단건 편집 시트 — 제목·태그 수정. 저장 방식(로컬/DB)은 호출부가 `onSubmit`에서 결정.
/// RN `components/EditClipModal.tsx` 이식.
struct EditClipModal: View {
    let initialTitle: String
    let initialTags: [String]
    let onSubmit: (String, [String]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var tagInput = ""
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("클립 편집")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColor.fg)

            labeled("제목") {
                TextField("제목", text: $title).modalField()
            }
            labeled("태그 (쉼표로 구분, 최대 6개)") {
                TextField("개발, 디자인", text: $tagInput)
                    .textInputAutocapitalization(.never)
                    .modalField()
            }

            HStack(spacing: 8) {
                Button("취소") { dismiss() }
                    .buttonStyle(ModalGhostButton())
                Button {
                    Task { await save() }
                } label: {
                    SpinnerLabel(title: saving ? "저장 중…" : "저장", loading: saving)
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
        .presentationDetents([.height(280)])
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
