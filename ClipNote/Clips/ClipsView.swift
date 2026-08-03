import SwiftUI
import SwiftData

/// 저장된 URL을 SFSafariViewController로 열 수 있는 형태로 정규화.
/// SFSafari는 http/https만 허용하므로 스킴이 없으면 https를 붙이고, 그대로 파싱 실패 시
/// 퍼센트 인코딩으로 재시도한다. 열 수 없으면 nil.
func openableWebURL(_ raw: String) -> URL? {
    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }
    let withScheme = s.hasPrefix("http://") || s.hasPrefix("https://") ? s : "https://\(s)"
    if let u = URL(string: withScheme), (u.scheme == "http" || u.scheme == "https") {
        return u
    }
    if let encoded = withScheme.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
       let u = URL(string: encoded), (u.scheme == "http" || u.scheme == "https") {
        return u
    }
    return nil
}

/// 내 클립 목록 — 로컬(게스트)/DB(로그인) 통합. 필터·편집·삭제·공유·바로가기.
/// RN `app/clips.tsx` 이식. 다중선택은 #C에서 추가.
struct ClipsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var i18n
    @Environment(AppRouter.self) private var router
    @EnvironmentObject private var auth: AuthStore

    @State private var store: ClipsStore?
    @State private var editing: UClip?
    @State private var pendingDelete: UClip?
    @State private var copiedID: String?
    @State private var makingSharedID: String?
    @State private var safariURL: URL?

    // 다중선택(로그인 전용)
    @State private var selectMode = false
    @State private var selected: Set<String> = []
    // 개수를 그리는 레이어는 전부 `.sheet(item:)` 으로 값을 실어 보낸다 — `ClipCount` 주석 참고.
    @State private var tagApplyRequest: ClipCount?
    @State private var bulkDeleteRequest: ClipCount?
    @State private var bulkBusy = false

    /// 날짜 그룹 머리글은 선택 언어를 따른다 — 시스템 언어가 아니라(앱 안에서 바꿀 수 있다).
    private var locale: Locale { Locale(identifier: i18n.language.rawValue) }

    var body: some View {
        Group {
            if let store {
                content(store)
            } else {
                loadingState
            }
        }
        .overlay { if bulkBusy { blockingOverlay } }
        .navigationTitle(selectMode
                         ? i18n.t("clips.selectedCount", args: selected.count)
                         : i18n.t("common.myClips"))
        .navigationBarTitleDisplayMode(.inline)
        .background(AppColor.bg)
        .toolbar {
            if !selectMode {
                ToolbarItem(placement: .topBarLeading) { HeaderMenu() }
            }
            toolbarContent
        }
        .safeAreaInset(edge: .bottom) {
            if selectMode { bulkBar } else { AdBannerView() }
        }
        .task { await setup() }
        .onChange(of: auth.loggedIn) {
            exitSelect()
            Task { await reloadWithAuth() }
        }
        .onReceive(NotificationCenter.default.publisher(for: ClipsRefresh.name)) { _ in
            Task { await reloadWithAuth() }
        }
        .sheet(item: $tagApplyRequest) { request in
            TagApplyModal(count: request.value) { tags, mode in
                Task {
                    bulkBusy = true
                    await store?.applyTags(ids: Array(selected), tags: tags, mode: mode)
                    bulkBusy = false
                    exitSelect()
                }
            }
        }
        // 확인 계열은 전부 레이어로 띄운다(웹과 동일) — `ConfirmLayer` 주석 참고.
        .sheet(item: $bulkDeleteRequest) { bulkDeleteLayer($0.value) }
        .sheet(item: $editing) { clip in
            EditClipModal(initialTitle: clip.title, initialTags: clip.tags) { title, tags in
                await store?.saveEdit(clip, title: title, tags: tags)
            }
        }
        .sheet(item: Binding(get: { safariURL.map(IdURL.init) },
                             set: { if $0 == nil { safariURL = nil } })) { item in
            SafariView(url: item.url)
        }
        .sheet(item: $pendingDelete) { clip in deleteLayer(clip) }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if selectMode {
                Button(i18n.t("common.cancel")) { exitSelect() }
            } else if auth.loggedIn, store?.clips?.isEmpty == false {
                Button(i18n.t("clips.select")) { selectMode = true }
            }
        }
    }

    /// 다중선택 하단 바 — 태그 적용 / 삭제(n).
    private var bulkBar: some View {
        HStack(spacing: 8) {
            Button { tagApplyRequest = ClipCount(value: selected.count) } label: {
                Text(i18n.t("clips.applyTags"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.brandStrong)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(AppColor.brandSoft)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
            Button { bulkDeleteRequest = ClipCount(value: selected.count) } label: {
                Text(i18n.t("clips.bulkDeleteButton", args: selected.count))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.white)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(AppColor.danger)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
            .disabled(selected.isEmpty)
            .opacity(selected.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ store: ClipsStore) -> some View {
        if store.clips == nil {
            loadingState
        } else if store.loadFailed {
            // 빈 목록보다 **먼저** 본다. 실패했는데 "저장한 클립이 없어요" 가 뜨면
            // 사용자는 클립이 날아간 줄 안다.
            loadFailedState
        } else if store.clips?.isEmpty == true {
            // 계정 목록이 비어도 이 기기 클립은 남아 있을 수 있다(옮기기를 거절한 경우).
            // 진입 줄을 여기에도 두지 않으면 그 클립에 닿을 길이 아예 없어진다.
            VStack(spacing: 0) {
                localEntryRow(store)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                emptyState
            }
        } else {
            List {
                localEntryRow(store).plainRow()
                if !store.allTags.isEmpty {
                    filterRow(store).plainRow()
                }
                if store.filtered.isEmpty {
                    Text(i18n.t("clips.emptyForTag", args: store.activeTag ?? ""))
                        .font(.system(size: 14))
                        .foregroundStyle(AppColor.fgMuted)
                        .plainRow()
                }
                // 저장 시각으로 묶어 머리글을 붙인다(웹과 같은 구성).
                // 목록이 이미 최신순이라 그룹도 최신순으로 나온다.
                ForEach(groupClipsByDate(store.filtered, locale: locale)) { group in
                    Text(group.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.fgMuted)
                        .padding(.top, 8)
                        .plainRow()
                    ForEach(group.clips) { clip in
                        row(clip)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func row(_ clip: UClip) -> some View {
        let base = ClipRow(
            clip: clip,
            selectMode: selectMode,
            isSelected: selected.contains(clip.id),
            copied: copiedID == clip.id,
            makingShared: makingSharedID == clip.id,
            onToggle: { toggle(clip.id) },
            onLongPress: { if auth.loggedIn { enterSelect(clip.id) } },
            onEdit: { editing = clip },
            onDelete: { pendingDelete = clip },
            onCopyShare: { copyShare(clip) },
            onMakeShared: { Task { await makeShared(clip) } },
            onOpen: { safariURL = openableWebURL(clip.url) }
        )
        .plainRow()

        if selectMode {
            base
        } else {
            base.swipeActions(edge: .trailing) {
                Button(i18n.t("common.delete"), role: .destructive) { pendingDelete = clip }
                Button(i18n.t("clips.edit")) { editing = clip }.tint(AppColor.brand)
            }
        }
    }

    /// ‘이 기기에 남은 클립 3개 ›’ — 옮기기를 거절했을 때 그 클립으로 가는 **유일한 길**이다.
    ///
    /// 계정 목록에 섞지 않는 이유는 `LocalClipsView` 주석 참고. 다중선택 중에는 감춘다 —
    /// 선택 대상이 아닌 줄이 목록에 섞이면 무엇이 선택되는지 흐려진다.
    @ViewBuilder
    private func localEntryRow(_ store: ClipsStore) -> some View {
        if store.localOnlyCount > 0, !selectMode {
            Button { router.go(.localClips) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "iphone")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.fgMuted)
                    Text(i18n.t("clips.localEntry", args: countUnit(store.localOnlyCount)))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColor.fg)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.fgMuted)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(AppColor.border, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    private func filterRow(_ store: ClipsStore) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: i18n.t("clips.allTags"), active: store.activeTag == nil) { store.activeTag = nil }
                ForEach(store.allTags, id: \.self) { tag in
                    FilterChip(label: tag, active: store.activeTag == tag) { store.activeTag = tag }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(i18n.t("clips.empty"))
                .font(.system(size: 15))
                .foregroundStyle(AppColor.fgMuted)
            Button { dismiss() } label: {
                Text(i18n.t("clips.emptyCta"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.white)
                    .padding(.horizontal, 20).frame(height: 46)
                    .background(AppColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    /// 목록 조회가 실패했을 때. 빈 목록과 **다른 화면**이어야 한다.
    ///
    /// 문구가 "사라진 건 아니에요" 까지 말하는 이유는, 이 화면에서 사용자가 가장 먼저
    /// 떠올리는 게 "내 클립이 날아갔나" 이기 때문이다(웹 `a6a4984` 와 같은 문구).
    private var loadFailedState: some View {
        VStack(spacing: 16) {
            Text(i18n.t("clips.loadFailed"))
                .font(.system(size: 15))
                .foregroundStyle(AppColor.fgMuted)
                .multilineTextAlignment(.center)
            Button { Task { await reloadWithAuth() } } label: {
                Text(i18n.t("clips.retry"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.white)
                    .padding(.horizontal, 20).frame(height: 46)
                    .background(AppColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: - Helpers

    /// 목록을 기다리는 동안 보이는 화면.
    ///
    /// 기다리는 구간이 둘이라 한 곳으로 모은다 — 스토어를 만드는 동안(`store == nil`)과
    /// 목록을 받아오는 동안(`store.clips == nil`). 전자는 `.task` 한 프레임이라 눈에 띄지
    /// 않고, **실제로 기다리는 건 후자**다. 공룡을 앞엣것에만 달아 두면 사실상 안 나온다.
    ///
    /// 공룡은 홈과 같은 자리 — 화면 가장자리를 돈다. 무슨 일이 벌어지는지 알리는 건 글이고,
    /// 공룡은 기다리는 시간을 견딜 만하게 만드는 장식이라 둘 다 둔다.
    private var loadingState: some View {
        Text(i18n.t("clips.loading"))
            .font(.system(size: 14))
            .foregroundStyle(AppColor.fgMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                RunningDino()
                    // 도는 사각형을 **배너 위로** 올린다. 아래쪽 면은 이미 걷지 않지만,
                    // 양옆 벽이 바닥까지 내려와 공룡이 배너 위에 걸친 채 나타났다 사라졌다.
                    .padding(.bottom, AdConfig.bannerHeight)
            }
    }

    private var blockingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .padding(24)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    /// 수량 표기(`3개`·`3 clips`) — 언어마다 단위 위치가 달라 문장에서 떼어 만든다.
    private func countUnit(_ count: Int) -> String {
        i18n.t("clips.countUnit", args: count)
    }

    // MARK: - 확인 레이어

    private func deleteLayer(_ clip: UClip) -> some View {
        ConfirmLayer(
            title: i18n.t("clips.deleteTitle"),
            message: emphasized(i18n.t("clips.deleteBody", args: clip.title), [clip.title]),
            confirmLabel: i18n.t("common.delete"),
            emphasis: .destructive,
            cancelLabel: i18n.t("common.cancel"),
            onConfirm: {
                pendingDelete = nil
                Task { await store?.delete(clip) }
            },
            onCancel: { pendingDelete = nil }
        )
    }

    private func bulkDeleteLayer(_ pending: Int) -> some View {
        let count = countUnit(pending)
        return ConfirmLayer(
            title: i18n.t("clips.bulkDeleteTitle", args: count),
            message: Text(i18n.t("clips.irreversible")),
            confirmLabel: i18n.t("common.delete"),
            emphasis: .destructive,
            cancelLabel: i18n.t("common.cancel"),
            onConfirm: {
                bulkDeleteRequest = nil
                Task {
                    bulkBusy = true
                    await store?.bulkDelete(ids: Array(selected))
                    bulkBusy = false
                    exitSelect()
                }
            },
            onCancel: { bulkDeleteRequest = nil }
        )
    }

    private func setup() async {
        if store == nil {
            store = ClipsStore(localStore: LocalClipStore(container: modelContext.container))
        }
        await reloadWithAuth()
    }

    /// 항상 현재 auth로 로드(캐시 ctx의 stale 방지 — 로그인 전환·마이그레이션 후).
    private func reloadWithAuth() async {
        await store?.load(loggedIn: auth.loggedIn, accessToken: auth.accessToken)
    }

    private func enterSelect(_ id: String) {
        selectMode = true
        selected = [id]
    }

    private func exitSelect() {
        selectMode = false
        selected = []
    }

    private func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func copyShare(_ c: UClip) {
        guard let text = store?.shareText(c) else { return }
        UIPasteboard.general.string = text
        copiedID = c.id
        Task { try? await Task.sleep(for: .milliseconds(1500)); if copiedID == c.id { copiedID = nil } }
    }

    private func makeShared(_ c: UClip) async {
        makingSharedID = c.id
        _ = await store?.makeShared(c)
        makingSharedID = nil
    }
}

/// `.sheet(item:)`용 URL 래퍼.
private struct IdURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

extension View {
    /// 카드형 리스트 행 — 구분선·배경 제거, 좌우 16 여백.
    /// 계정 목록과 `LocalClipsView` 가 같은 여백을 써야 화면을 오갈 때 줄이 어긋나 보이지 않는다.
    func plainRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

/// 목록 카드 한 줄 — 썸네일·제목·호스트·태그 + ⋯메뉴 + 액션행(공유/바로가기).
private struct ClipRow: View {
    @Environment(LocalizationStore.self) private var i18n

    let clip: UClip
    let selectMode: Bool
    let isSelected: Bool
    let copied: Bool
    let makingShared: Bool
    let onToggle: () -> Void
    let onLongPress: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onCopyShare: () -> Void
    let onMakeShared: () -> Void
    let onOpen: () -> Void

    private var gradient: ClipGradient {
        GRADIENTS.first { $0.name == clip.gradient } ?? pickGradient(clip.title.isEmpty ? clip.url : clip.title)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if selectMode { checkbox }
                ClipThumbnail(imageURL: clip.image, gradient: gradient)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                VStack(alignment: .leading, spacing: 2) {
                    Text(clip.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.fg)
                        .lineLimit(2)
                    Text(prettyHost(clip.url))
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.fgMuted)
                        .lineLimit(1)
                    if !clip.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(clip.tags, id: \.self) { TagChip(text: $0, small: true) }
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
                if !selectMode {
                    Menu {
                        Button(i18n.t("clips.edit"), action: onEdit)
                        Button(i18n.t("common.delete"), role: .destructive, action: onDelete)
                    } label: {
                        Text(verbatim: "⋯")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColor.fgMuted)
                            .frame(width: 32, height: 32)
                    }
                }
            }
            .padding(12)

            if !selectMode { actionRow }
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md)
            .stroke(isSelected ? AppColor.brand : AppColor.border, lineWidth: isSelected ? 1.5 : 0.5))
        .contentShape(Rectangle())
        .onTapGesture { if selectMode { onToggle() } }
        .onLongPressGesture { if !selectMode { onLongPress() } }
    }

    private var checkbox: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? AppColor.brand : AppColor.border, lineWidth: 1.5)
                .background(Circle().fill(isSelected ? AppColor.brand : Color.clear))
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColor.white)
            }
        }
        .frame(width: 24, height: 24)
    }

    @ViewBuilder
    private var actionRow: some View {
        Divider().background(AppColor.border)
        HStack(spacing: 0) {
            if !clip.local {
                Button(action: clip.shared ? onCopyShare : onMakeShared) {
                    SpinnerLabel(title: i18n.t(clip.shared
                                 ? (copied ? "clips.copied" : "clips.copyShareLink")
                                 : (makingShared ? "clips.creatingShareLink" : "clips.createShareLink")),
                                 loading: makingShared, tint: AppColor.brandStrong)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.brandStrong)
                        .frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.plain)
                Divider().frame(height: 24).background(AppColor.border)
            }
            Button(action: onOpen) {
                Text(i18n.t("clips.openOriginal"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.fg)
                    .frame(maxWidth: .infinity).frame(height: 44)
            }
            .buttonStyle(.plain)
        }
    }

}
