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

    var body: some View {
        Group {
            if let store {
                content(store)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("내 클립")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppColor.bg)
        .task { await setup() }
        .onChange(of: auth.loggedIn) { Task { await reloadWithAuth() } }
        .onReceive(NotificationCenter.default.publisher(for: ClipsRefresh.name)) { _ in
            Task { await reloadWithAuth() }
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
                    ClipRow(
                        clip: clip,
                        copied: copiedID == clip.id,
                        makingShared: makingSharedID == clip.id,
                        onEdit: { editing = clip },
                        onDelete: { pendingDelete = clip },
                        onCopyShare: { copyShare(clip) },
                        onMakeShared: { Task { await makeShared(clip) } },
                        onOpen: { safariURL = URL(string: clip.url) }
                    )
                    .plainRow()
                    .swipeActions(edge: .trailing) {
                        Button("삭제", role: .destructive) { pendingDelete = clip }
                        Button("편집") { editing = clip }.tint(AppColor.brand)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
    let copied: Bool
    let makingShared: Bool
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
            .padding(12)

            actionRow
        }
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppColor.border, lineWidth: 0.5))
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
