import SwiftUI
import SwiftData

/// 내 클립 목록 — 로컬(게스트)/DB(로그인) 통합. 필터·편집·삭제·공유·바로가기.
/// RN `app/clips.tsx` 이식. 다중선택은 #C에서 추가.
struct ClipsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
    @State private var showTagModal = false
    @State private var showBulkDeleteConfirm = false

    var body: some View {
        Group {
            if let store {
                content(store)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(selectMode ? "\(selected.count)개 선택" : "내 클립")
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
        .sheet(isPresented: $showTagModal) {
            TagApplyModal(count: selected.count) { tags, mode in
                Task {
                    await store?.applyTags(ids: Array(selected), tags: tags, mode: mode)
                    exitSelect()
                }
            }
        }
        .confirmationDialog("클립 삭제", isPresented: $showBulkDeleteConfirm) {
            Button("삭제", role: .destructive) {
                Task {
                    await store?.bulkDelete(ids: Array(selected))
                    exitSelect()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("선택한 \(selected.count)개 클립을 삭제할까요?")
        }
        .sheet(item: $editing) { clip in
            EditClipModal(initialTitle: clip.title, initialTags: clip.tags) { title, tags in
                await store?.saveEdit(clip, title: title, tags: tags)
            }
        }
        .sheet(item: Binding(get: { safariURL.map(IdURL.init) },
                             set: { if $0 == nil { safariURL = nil } })) { item in
            SafariView(url: item.url)
        }
        .confirmationDialog("클립 삭제", isPresented: deleteBinding, presenting: pendingDelete) { clip in
            Button("삭제", role: .destructive) { Task { await store?.delete(clip) } }
            Button("취소", role: .cancel) {}
        } message: { clip in
            Text("‘\(clip.title)’ 클립을 삭제할까요?")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if selectMode {
                Button("취소") { exitSelect() }
            } else if auth.loggedIn, store?.clips?.isEmpty == false {
                Button("선택") { selectMode = true }
            }
        }
    }

    /// 다중선택 하단 바 — 태그 적용 / 삭제(n).
    private var bulkBar: some View {
        HStack(spacing: 8) {
            Button { showTagModal = true } label: {
                Text("태그 적용")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColor.brandStrong)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(AppColor.brandSoft)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
            Button { showBulkDeleteConfirm = true } label: {
                Text("삭제 (\(selected.count))")
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
            Text("불러오는 중…")
                .font(.system(size: 14))
                .foregroundStyle(AppColor.fgMuted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.clips?.isEmpty == true {
            emptyState
        } else {
            List {
                if !store.allTags.isEmpty {
                    filterRow(store).plainRow()
                }
                if store.filtered.isEmpty {
                    Text("‘\(store.activeTag ?? "")’ 태그의 클립이 없어요.")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColor.fgMuted)
                        .plainRow()
                }
                ForEach(store.filtered) { clip in
                    row(clip)
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
            onOpen: { safariURL = URL(string: clip.url) }
        )
        .plainRow()

        if selectMode {
            base
        } else {
            base.swipeActions(edge: .trailing) {
                Button("삭제", role: .destructive) { pendingDelete = clip }
                Button("편집") { editing = clip }.tint(AppColor.brand)
            }
        }
    }

    private func filterRow(_ store: ClipsStore) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "전체", active: store.activeTag == nil) { store.activeTag = nil }
                ForEach(store.allTags, id: \.self) { tag in
                    FilterChip(label: tag, active: store.activeTag == tag) { store.activeTag = tag }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("아직 저장한 클립이 없어요.")
                .font(.system(size: 15))
                .foregroundStyle(AppColor.fgMuted)
            Button { dismiss() } label: {
                Text("첫 클립 만들기")
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

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
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

private extension View {
    /// 카드형 리스트 행 — 구분선·배경 제거, 좌우 16 여백.
    func plainRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

/// 목록 카드 한 줄 — 썸네일·제목·호스트·태그 + ⋯메뉴 + 액션행(공유/바로가기).
private struct ClipRow: View {
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
                thumbnail
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
                        Button("편집", action: onEdit)
                        Button("삭제", role: .destructive, action: onDelete)
                    } label: {
                        Text("⋯")
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
                    Text(clip.shared
                         ? (copied ? "복사됨 ✓" : "공유 링크 복사")
                         : (makingShared ? "켜는 중…" : "공유 링크 만들기"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.brandStrong)
                        .frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.plain)
                Divider().frame(height: 24).background(AppColor.border)
            }
            Button(action: onOpen) {
                Text("바로가기")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.fg)
                    .frame(maxWidth: .infinity).frame(height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            LinearGradient(colors: [gradient.from, gradient.to],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let s = clip.image, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() } else { Color.clear }
                }
            }
        }
    }
}
