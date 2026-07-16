import SwiftUI
import SwiftData

/// 홈 — URL 붙여넣기 → 메타 추출 → 미리보기 → 저장(게스트 로컬 / 로그인 공유·DB).
/// RN `app/index.tsx` 이식. 헤더 메뉴·배너·온보딩 게이트는 후속 페이즈.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthStore
    @State private var vm = HomeViewModel()

    @State private var savedLocal = false
    @State private var creating = false
    @State private var savingDirect = false
    @State private var directSaved = false
    @State private var shareURL: String?
    @State private var showLogin = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                formCard
                if let e = vm.errorMessage { errorBox(e) }
                if vm.noMeta, let reason = vm.metaReason { warnBox(reason) }
                if vm.hasInput { previews }
            }
            .padding(16)
        }
        .background(AppColor.bg)
        .navigationTitle("ClipNote")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: vm.url) { vm.urlChanged() }
        .sheet(isPresented: $showLogin) { LoginView() }
        .sheet(item: Binding(get: { shareURL.map(ShareURLItem.init) },
                             set: { if $0 == nil { shareURL = nil } })) { item in
            ShareResultSheet(title: vm.resolvedTitle,
                             description: vm.previewDescription, url: item.url)
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 8) {
            Text("붙여넣으면 끝, 예쁜 공유 카드")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColor.fg)
                .multilineTextAlignment(.center)
            Text("링크만 넣으면 미리보기 카드와 짧은 공유 링크가 한 번에 만들어져요.")
                .font(.system(size: 14))
                .foregroundStyle(AppColor.fgMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            field(label: "URL", required: true) {
                TextField("https://example.com/article", text: $vm.url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            field(label: "제목", muted: "(안 쓰면 자동으로 채워져요)") {
                TextField("공유 카드에 보일 제목", text: $vm.title)
            }
            field(label: "태그", muted: "(선택 · 쉼표로 구분)") {
                TextField("개발, 디자인, 읽을거리", text: $vm.tagInput)
                    .textInputAutocapitalization(.never)
            }
            if !vm.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(vm.tags, id: \.self) { TagChip(text: $0) }
                }
            }
            actions
        }
        .padding(14)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppColor.border, lineWidth: 0.5))
        .padding(.top, 8)
    }

    @ViewBuilder
    private var actions: some View {
        if auth.loggedIn {
            HStack(spacing: 8) {
                primaryButton(creating ? "만드는 중…" : "공유 링크 만들기",
                              disabled: !vm.hasInput || creating) { await createShare() }
                secondaryButton(directSaved ? "저장됨 ✓" : (savingDirect ? "저장 중…" : "내 클립에 저장"),
                                disabled: !vm.hasInput || savingDirect) { await saveToClips() }
            }
            .padding(.top, 4)
        } else {
            primaryButton(savedLocal ? "저장됨 ✓" : "이 기기에 저장",
                          disabled: !vm.hasInput) { saveLocal() }
                .padding(.top, 4)
            HStack(spacing: 0) {
                Text("짧은 공유 링크는 ")
                Text("로그인").foregroundStyle(AppColor.brandStrong).fontWeight(.semibold)
                    .onTapGesture { showLogin = true }
                Text(" 후 만들 수 있어요.")
            }
            .font(.system(size: 12))
            .foregroundStyle(AppColor.fgMuted)
            .frame(maxWidth: .infinity)
        }
    }

    private var previews: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("공유 카드").font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColor.fg)
                    if vm.loading { ProgressView().controlSize(.small) }
                }
                Text("링크를 공유하면 이렇게 보여요").font(.system(size: 12)).foregroundStyle(AppColor.fgMuted)
                SharePreviewCard(title: vm.effectiveTitle, description: vm.previewDescription,
                                 siteName: vm.previewSiteName, gradient: vm.gradient)
                Text("실제 공유 시 뜨는 이미지예요. 배경색은 제목에 따라 자동으로 정해져요.")
                    .font(.system(size: 12)).foregroundStyle(AppColor.fgMuted)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("내 클립에 저장하면").font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColor.fg)
                Text("목록에서 이렇게 보여요").font(.system(size: 12)).foregroundStyle(AppColor.fgMuted)
                ClipCardView(title: vm.effectiveTitle,
                             host: vm.hasInput ? prettyHost(vm.url) : nil,
                             imageURL: vm.previewImage, gradient: vm.gradient, tags: vm.tags)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func field<Content: View>(label: String, required: Bool = false,
                                      muted: String? = nil,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(AppColor.fg)
                if required { Text("*").foregroundStyle(AppColor.danger) }
                if let m = muted { Text(m).font(.system(size: 13)).foregroundStyle(AppColor.fgMuted) }
            }
            content()
                .font(.system(size: 15))
                .foregroundStyle(AppColor.fg)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(AppColor.bg)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(AppColor.border, lineWidth: 0.5))
        }
    }

    private func primaryButton(_ label: String, disabled: Bool,
                               action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(label).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.white)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(AppColor.brand)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private func secondaryButton(_ label: String, disabled: Bool,
                                 action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(label).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.brandStrong)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(AppColor.brandSoft)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(AppColor.brand, lineWidth: 0.5))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private func errorBox(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).foregroundStyle(AppColor.danger)
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(AppColor.danger.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm)).padding(.top, 16)
    }

    private func warnBox(_ text: String) -> some View {
        Text("⚠️ \(text)").font(.system(size: 14)).foregroundStyle(AppColor.fg)
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(AppColor.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm)).padding(.top, 16)
    }

    // MARK: - Actions

    private func saveLocal() {
        let store = LocalClipStore(container: modelContext.container)
        guard vm.saveToDevice(store) else { return }
        savedLocal = true
        Task { try? await Task.sleep(for: .milliseconds(1800)); savedLocal = false }
    }

    private func createShare() async {
        creating = true
        defer { creating = false }
        if let res = await vm.createShare(accessToken: auth.accessToken) {
            shareURL = res.shareUrl
        }
    }

    private func saveToClips() async {
        savingDirect = true
        defer { savingDirect = false }
        if await vm.saveToClips(accessToken: auth.accessToken) {
            directSaved = true
            Task { try? await Task.sleep(for: .milliseconds(1800)); directSaved = false }
        }
    }
}

/// `.sheet(item:)`용 Identifiable 래퍼.
private struct ShareURLItem: Identifiable {
    let url: String
    var id: String { url }
}

/// 공유 링크 결과 최소 시트 — 링크 표시 + 복사(§4.3 규칙). 전체 ShareResultModal(열기·DB저장)은 Phase 4.
private struct ShareResultSheet: View {
    let title: String
    let description: String?
    let url: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            Text("공유 링크가 만들어졌어요")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColor.fg)
            Text(url)
                .font(.system(size: 14))
                .foregroundStyle(AppColor.brandStrong)
                .textSelection(.enabled)
                .multilineTextAlignment(.center)
            Button {
                UIPasteboard.general.string = buildShareText(title: title, description: description, url: url)
                copied = true
                Task { try? await Task.sleep(for: .milliseconds(1500)); copied = false }
            } label: {
                Text(copied ? "복사됨 ✓" : "링크 복사")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(AppColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
            Button("닫기") { dismiss() }
                .font(.system(size: 15))
                .foregroundStyle(AppColor.fgMuted)
        }
        .padding(24)
        .presentationDetents([.height(240)])
    }
}
