import SwiftUI
import SwiftData

/// 홈 — URL 붙여넣기 → 메타 추출 → 미리보기 → 저장(게스트 로컬 / 로그인 공유·DB).
/// RN `app/index.tsx` 이식. 헤더 메뉴·배너·온보딩 게이트는 후속 페이즈.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(LocalizationStore.self) private var i18n
    @EnvironmentObject private var auth: AuthStore
    @State private var vm = HomeViewModel()

    @State private var savedLocal = false
    @State private var creating = false
    @State private var savingDirect = false
    @State private var directSaved = false
    @State private var shareURL: String?
    /// 결과 시트 표시 여부. `shareURL` 과 분리해 두어 시트를 닫아도 링크가 남는다.
    @State private var shareSheetOpen = false
    @State private var copiedLink = false
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
                if let e = vm.error { errorBox(message(for: e)) }
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
                NavigationLink(i18n.t("common.myClips"), value: AppRoute.clips)
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
        // URL 이 바뀌면 이전 링크는 이 입력과 맞지 않으므로 버린다 → 1차 버튼이 `createLink` 로 복귀.
        .onChange(of: vm.url) {
            vm.urlChanged()
            shareURL = nil
            shareSheetOpen = false
        }
        // 공유 확장이 넘긴 URL을 입력칸에 채운다(setter가 메타 추출을 트리거).
        .onChange(of: router.pendingSharedURL) { _, s in consumeSharedURL(s) }
        .onAppear { consumeSharedURL(router.pendingSharedURL) }
        // 시트 표시 여부를 shareURL 과 분리한다 — `.sheet(item:)` 은 닫힐 때 바인딩을 nil 로
        // 되돌려 링크를 잃는다. 링크는 남아 있어야 1차 버튼이 `copyLink` 로 바뀔 수 있다.
        .sheet(isPresented: $shareSheetOpen) {
            if let url = shareURL {
                ShareResultModal(title: vm.resolvedTitle,
                                 description: vm.previewDescription, url: url,
                                 onSave: { await vm.saveToClips(accessToken: auth.accessToken) })
            }
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 8) {
            // 강조 낱말을 분리해 둔 건 웹과 같은 이유다 — 언어마다 위치가 달라서
            // 앞/뒤로 쪼개면 문장이 깨진다. 앱은 아직 색을 다르게 주지 않는다.
            Text(i18n.t("home.hero.title", args: i18n.t("home.hero.titleAccent")))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColor.fg)
                .multilineTextAlignment(.center)
            Text(i18n.t("home.hero.subtitle"))
                .font(.system(size: 14))
                .foregroundStyle(AppColor.fgMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            field(label: i18n.t("home.form.urlLabel"), required: true) {
                // 플레이스홀더를 시스템 기본색에 맡기면 URL 필드가 시스템 tint(파랑)로 링크처럼 보임.
                // 회색 오버레이로 직접 그려 다른 필드와 동일한 회색으로 고정(#73은 타이핑 글자만 처리했음).
                ZStack(alignment: .leading) {
                    if vm.url.isEmpty {
                        Text(i18n.t("home.form.urlPlaceholder"))
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
                            .accessibilityLabel(i18n.t("home.clearInputAria"))
                        }
                    }
                }
            }
            .tourAnchor(.url)
            VStack(alignment: .leading, spacing: 12) {
                field(label: i18n.t("home.form.titleLabel"), muted: i18n.t("home.form.titleNote")) {
                    TextField(i18n.t("home.form.titlePlaceholder"), text: $vm.title)
                        .focused($focus, equals: .title)
                }
                field(label: i18n.t("home.form.tagsLabel"), muted: i18n.t("home.form.tagsNote")) {
                    TextField(i18n.t("home.form.tagsPlaceholder"), text: $vm.tagInput)
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
            // 버튼 3개 → 링크·복사를 한 줄에 묶고, 저장은 자기 줄을 전부 쓴다(웹과 동일 배치).
            // 1차: 링크가 없으면 `createLink`, 있으면 `copyLink`(짧은 주소).
            // `copyOriginal`(제목+원본 URL)은 링크 유무와 무관하게 항상 노출.
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    if shareURL != nil {
                        primaryButton(i18n.t(copiedLink ? "homeActions.copied" : "homeActions.copyLink"),
                                      disabled: false) { copyShareLink() }
                    } else {
                        primaryButton(i18n.t(creating ? "homeActions.creating" : "homeActions.createLink"),
                                      disabled: !vm.hasInput || creating, loading: creating) { await createShare() }
                            .tourAnchor(.share)
                    }
                    secondaryButton(i18n.t(copiedShare ? "homeActions.copied" : "homeActions.copyOriginal"),
                                    disabled: !vm.hasInput) { copyGuestShare() }
                }
                secondaryButton(i18n.t(directSaved ? "homeActions.saved" : (savingDirect ? "homeActions.saving" : "homeActions.saveToClips")),
                                disabled: !vm.hasInput || savingDirect, loading: savingDirect) { await saveToClips() }
                    .tourAnchor(.save)
            }
            .padding(.top, 4)
        } else {
            primaryButton(i18n.t(savedLocal ? "homeActions.saved" : "homeActions.saveHere"),
                          disabled: !vm.hasInput) { saveLocal() }
                .tourAnchor(.save)
                .padding(.top, 4)
            HStack(spacing: 8) {
                ShareLink(item: guestShareText) {
                    Text(i18n.t("homeActions.share"))
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
                    Text(i18n.t(copiedShare ? "homeActions.copied" : "homeActions.copyOriginal"))
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
            guestHint
        }
    }

    /// 게스트 안내 — `로그인` 낱말을 브랜드 색으로 강조하고, 누르면 로그인 시트를 연다.
    ///
    /// 문장을 앞/뒤로 쪼개 사전에 넣으면 어순이 다른 언어에서 깨진다(영어는 `Sign in` 이 문장
    /// 맨 앞이다). 그래서 사전에는 `%@` 가 든 온전한 문장 하나만 두고, 여기서 끼워 넣은
    /// 낱말을 기준으로 다시 쪼갠다 — 웹 `interpolateNode` 와 같은 방식.
    ///
    /// 탭 영역은 낱말이 아니라 **안내문 전체**다. 강조 낱말만 누르게 하면 12pt 글자 폭이라
    /// 손가락으로 맞히기 어렵다.
    private var guestHint: some View {
        let login = i18n.t("common.login")
        let full = i18n.t("homeActions.guestHint", args: login)
        let parts = full.components(separatedBy: login)
        return HStack(spacing: 0) {
            Text(parts.first ?? full)
            if parts.count > 1 {
                Text(login).foregroundStyle(AppColor.brandStrong).fontWeight(.semibold)
                Text(parts.dropFirst().joined(separator: login))
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(AppColor.fgMuted)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { router.showLogin = true }
    }

    /// 미리보기 카드에 그릴 제목. 아직 아무것도 없으면 자리표시자를 보여 준다.
    private var previewTitle: String {
        let resolved = vm.resolvedTitle
        return resolved.isEmpty ? i18n.t("home.preview.titlePlaceholder") : resolved
    }

    /// 모델이 든 오류 케이스를 현재 언어의 문장으로 바꾼다.
    /// 서버가 준 문장은 그대로 쓴다 — 이미 사람이 읽는 말이고, 앱이 알 수 없는 사유를 담는다.
    private func message(for error: HomeError) -> String {
        switch error {
        case .metaFailed: i18n.t("home.errors.metaFailed")
        case .titleRequiredForLink: i18n.t("home.errors.titleRequiredForLink")
        case .titleRequiredForClip: i18n.t("home.errors.titleRequiredForClip")
        case .linkCreateFailed(let server): server ?? i18n.t("home.errors.linkCreateFailed")
        case .server(let message): message
        }
    }

    private var previews: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(i18n.t("home.cardPreview.title")).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColor.fg)
                    if vm.loading { ProgressView().controlSize(.small) }
                }
                Text(i18n.t("home.cardPreview.note")).font(.system(size: 12)).foregroundStyle(AppColor.fgMuted)
                SharePreviewCard(title: previewTitle, description: vm.previewDescription,
                                 siteName: vm.previewSiteName, gradient: vm.gradient,
                                 imageURL: vm.previewImage)
                Text(i18n.t("home.cardPreview.caption"))
                    .font(.system(size: 12)).foregroundStyle(AppColor.fgMuted)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("home.clipPreview.title")).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColor.fg)
                Text(i18n.t("home.clipPreview.note")).font(.system(size: 12)).foregroundStyle(AppColor.fgMuted)
                ClipCardView(title: previewTitle,
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
            Text(i18n.t("home.metaLoading"))
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
        buildShareText(title: vm.resolvedTitle, description: nil, url: vm.url)
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
            shareSheetOpen = true
        }
    }

    /// 생성된 짧은 링크를 복사(`원본 복사` 와 달리 공유 링크만 담는다).
    private func copyShareLink() {
        guard let shareURL else { return }
        UIPasteboard.general.string = shareURL
        copiedLink = true
        Task { try? await Task.sleep(for: .milliseconds(1500)); copiedLink = false }
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

