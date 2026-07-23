import SwiftUI
import SwiftData

/// 홈 — URL 붙여넣기 → 메타 추출 → 미리보기 → 저장(게스트 로컬 / 로그인 공유·DB).
/// RN `app/index.tsx` 이식. 헤더 메뉴·배너·온보딩 게이트는 후속 페이즈.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @EnvironmentObject private var auth: AuthStore
    @State private var vm = HomeViewModel()

    @State private var savedLocal = false
    @State private var creating = false
    @State private var savingDirect = false
    @State private var directSaved = false
    @State private var shareURL: String?
    @State private var kbVisible = false
    @State private var copiedShare = false

    private enum FocusField { case url, title, tag }
    @FocusState private var focus: FocusField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                formCard
                if vm.loading { metaLoadingRow }
                if let e = vm.errorMessage { errorBox(e) }
                if vm.noMeta, let reason = vm.metaReason { warnBox(reason) }
                if vm.hasInput { previews }
            }
            .padding(16)
            // 빈 영역(backdrop) 탭 시 포커스 해제 → 키보드 내림.
            // 버튼·입력칸은 자체 탭을 소비하므로 영향 없음.
            .contentShape(Rectangle())
            .onTapGesture { focus = nil }
        }
        // 스크롤 드래그로도 키보드 내림.
        .scrollDismissesKeyboard(.interactively)
        .background(AppColor.bg)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { HeaderMenu() }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("내 클립", value: AppRoute.clips)
            }
        }
        // 키보드가 뜨면 하단 배너 숨김(겹침 방지, RN 동작).
        .safeAreaInset(edge: .bottom) { if !kbVisible { AdBannerView() } }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            kbVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            kbVisible = false
        }
        .onChange(of: vm.url) { vm.urlChanged() }
        // 공유 확장이 넘긴 URL을 입력칸에 채운다(setter가 메타 추출을 트리거).
        .onChange(of: router.pendingSharedURL) { _, s in consumeSharedURL(s) }
        .onAppear { consumeSharedURL(router.pendingSharedURL) }
        .sheet(item: Binding(get: { shareURL.map(ShareURLItem.init) },
                             set: { if $0 == nil { shareURL = nil } })) { item in
            ShareResultModal(title: vm.resolvedTitle,
                             description: vm.previewDescription, url: item.url,
                             onSave: { await vm.saveToClips(accessToken: auth.accessToken) })
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 8) {
            Text("밋밋한 링크를 카드 한 장으로")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColor.fg)
                .multilineTextAlignment(.center)
            Text("제목·대표 이미지가 담긴 카드와 짧은 링크를 한 번에. 카카오톡·SNS에서 깔끔하게 보여요.")
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
                // 플레이스홀더를 시스템 기본색에 맡기면 URL 필드가 시스템 tint(파랑)로 링크처럼 보임.
                // 회색 오버레이로 직접 그려 다른 필드와 동일한 회색으로 고정(#73은 타이핑 글자만 처리했음).
                ZStack(alignment: .leading) {
                    if vm.url.isEmpty {
                        Text("공유할 링크 붙여넣기")
                            .foregroundStyle(AppColor.fgMuted)
                    }
                    HStack(spacing: 8) {
                        TextField("", text: $vm.url)
                            .focused($focus, equals: .url)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(AppColor.fg)   // 타이핑 글자 검정
                            .tint(AppColor.fg)               // 커서도 검정
                        if !vm.url.isEmpty {
                            Button {
                                vm.url = ""
                                focus = .url
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(AppColor.fgMuted)
                            }
                            .accessibilityLabel("입력 지우기")
                        }
                    }
                }
            }
            .tourAnchor(.url)
            VStack(alignment: .leading, spacing: 12) {
                field(label: "제목", muted: "(안 쓰면 자동으로 채워져요)") {
                    TextField("공유 카드에 보일 제목", text: $vm.title)
                        .focused($focus, equals: .title)
                }
                field(label: "태그", muted: "(선택 · 쉼표로 구분)") {
                    TextField("개발, 디자인, 읽을거리", text: $vm.tagInput)
                        .focused($focus, equals: .tag)
                        .textInputAutocapitalization(.never)
                }
            }
            .tourAnchor(.options)
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
        // 세션 복원 전 첫 프레임은 지난 실행 값(displayLoggedIn)으로 그려 깜빡임을 막는다.
        if auth.displayLoggedIn {
            HStack(spacing: 8) {
                primaryButton(creating ? "만드는 중…" : "공유 링크 만들기",
                              disabled: !vm.hasInput || creating, loading: creating) { await createShare() }
                    .tourAnchor(.share)
                secondaryButton(directSaved ? "저장됨 ✓" : (savingDirect ? "저장 중…" : "내 클립에 저장"),
                                disabled: !vm.hasInput || savingDirect, loading: savingDirect) { await saveToClips() }
                    .tourAnchor(.save)
            }
            .padding(.top, 4)
        } else {
            primaryButton(savedLocal ? "저장됨 ✓" : "이 기기에 저장",
                          disabled: !vm.hasInput) { saveLocal() }
                .tourAnchor(.save)
                .padding(.top, 4)
            HStack(spacing: 8) {
                ShareLink(item: guestShareText) {
                    Text("공유하기")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.brandStrong)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(AppColor.brandSoft)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(AppColor.brand, lineWidth: 0.5))
                }
                .disabled(!vm.hasInput)
                .opacity(vm.hasInput ? 1 : 0.5)

                Button { copyGuestShare() } label: {
                    Text(copiedShare ? "복사됨 ✓" : "복사하기")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.brandStrong)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(AppColor.brandSoft)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(AppColor.brand, lineWidth: 0.5))
                }
                .disabled(!vm.hasInput)
                .opacity(vm.hasInput ? 1 : 0.5)
            }
            HStack(spacing: 0) {
                Text("공유 카드·짧은 링크는 ")
                Text("로그인").foregroundStyle(AppColor.brandStrong).fontWeight(.semibold)
                    .onTapGesture { router.showLogin = true }
                Text(" 하면 만들어져요.")
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
                                 siteName: vm.previewSiteName, gradient: vm.gradient,
                                 imageURL: vm.previewImage)
                Text("실제 공유 시 뜨는 이미지예요. 원본 대표 이미지가 있으면 배경으로 쓰고, 없으면 제목에 맞춰 만든 그라디언트로 채워져요.")
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

    private func primaryButton(_ label: String, disabled: Bool, loading: Bool = false,
                               action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            SpinnerLabel(title: label, loading: loading, tint: AppColor.white)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.white)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(AppColor.brand)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private func secondaryButton(_ label: String, disabled: Bool, loading: Bool = false,
                                 action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            SpinnerLabel(title: label, loading: loading, tint: AppColor.brandStrong)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.brandStrong)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(AppColor.brandSoft)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(AppColor.brand, lineWidth: 0.5))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private var metaLoadingRow: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text("링크 정보를 읽는 중…")
                .font(.system(size: 14)).foregroundStyle(AppColor.fgMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm)).padding(.top, 12)
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

    /// 게스트 공유/복사 텍스트 — 카드 생성 없이 스크랩된 제목 + 원본 URL.
    private var guestShareText: String {
        buildShareText(title: vm.effectiveTitle, description: nil, url: vm.url)
    }

    private func copyGuestShare() {
        UIPasteboard.general.string = guestShareText
        copiedShare = true
        Task { try? await Task.sleep(for: .milliseconds(1500)); copiedShare = false }
    }

    private func consumeSharedURL(_ shared: String?) {
        guard let shared, !shared.isEmpty else { return }
        vm.url = shared
        router.pendingSharedURL = nil
    }

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

