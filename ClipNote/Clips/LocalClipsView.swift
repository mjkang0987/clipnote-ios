import SwiftUI
import SwiftData

/// 이 기기에만 남은 클립 — 로그인 상태에서 계정 목록과 **자리를 나눠** 보여 준다.
///
/// **왜 한 목록에 합치지 않나.** 성격이 달라서다. 계정 클립은 다른 기기에서도 보이고 공유 링크를
/// 만들 수 있지만, 이 기기 클립은 둘 다 못 한다(slug 가 없다). 한 줄짜리 배지로 구분하기엔 차이가
/// 커서 — 눌러 보고 나서야 안 되는 걸 알게 된다 — 자리를 따로 두고, 여기서만 할 수 있는 일
/// (옮기기·모두 삭제)을 아래 바에 모은다.
///
/// 진입은 목록 위의 ‘이 기기에 남은 클립 3개’ 줄뿐이다. 로컬 클립이 0이 되면 그 줄이 사라진다.
///
/// **옮기거나 지운 뒤에 자동으로 닫지 않는다.** 옮기기 결과 알림(‘클립 3개를 옮겼어요’)이 이
/// 화면에 붙어 있어서, 곧바로 pop 하면 알림이 뜨기도 전에 같이 사라진다. 대신 빈 화면을 보여
/// 주고 돌아가는 건 사용자에게 맡긴다.
struct LocalClipsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocalizationStore.self) private var i18n
    @EnvironmentObject private var auth: AuthStore

    /// nil = 아직 안 읽음. 로컬 조회는 한 프레임이라 로딩 화면까지는 두지 않는다.
    @State private var clips: [UClip]?
    @State private var safariURL: URL?

    // 개수를 그리는 레이어는 전부 `.sheet(item:)` 으로 값을 실어 보낸다 — `ClipCount` 주석 참고.
    @State private var migrateRequest: ClipCount?
    @State private var deleteAllRequest: ClipCount?

    /// 날짜 그룹 머리글은 선택 언어를 따른다 — 시스템 언어가 아니라(앱 안에서 바꿀 수 있다).
    private var locale: Locale { Locale(identifier: i18n.language.rawValue) }

    private var localStore: LocalClipStore {
        LocalClipStore(container: modelContext.container)
    }

    var body: some View {
        content
            .navigationTitle(i18n.t("localClips.title"))
            .navigationBarTitleDisplayMode(.inline)
            .background(AppColor.bg)
            .safeAreaInset(edge: .bottom) {
                if clips?.isEmpty == false { actionBar }
            }
            .task { reload() }
            .onReceive(NotificationCenter.default.publisher(for: ClipsRefresh.name)) { _ in
                reload()
            }
            // 로그아웃하면 이 클립들이 곧 기본 목록이 된다 — 따로 볼 화면이 아니게 되므로 닫는다.
            .onChange(of: auth.loggedIn) { _, now in if !now { dismiss() } }
            // 전량 성공이면 목록이 비어 빈 화면이 되고, 일부만 옮겨졌으면 남은 것이 그대로 보인다.
            .migrateLocalClipsLayer(request: $migrateRequest) { _ in reload() }
            .sheet(item: $deleteAllRequest) { deleteAllLayer($0.value) }
            .sheet(item: Binding(get: { safariURL.map(LocalSafariItem.init) },
                                 set: { if $0 == nil { safariURL = nil } })) { item in
                SafariView(url: item.url)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let clips, clips.isEmpty {
            emptyState
        } else {
            List {
                Text(i18n.t("localClips.intro"))
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(AppColor.fgMuted)
                    .padding(.vertical, 4)
                    .plainRow()

                // 계정 목록과 같은 구성 — 저장 시각으로 묶어 머리글을 붙인다.
                ForEach(groupClipsByDate(clips ?? [], locale: locale)) { group in
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

    private func row(_ clip: UClip) -> some View {
        Button { safariURL = openableWebURL(clip.url) } label: {
            ClipCardView(
                title: clip.title,
                host: prettyHost(clip.url),
                imageURL: clip.image,
                gradient: GRADIENTS.first { $0.name == clip.gradient }
                    ?? pickGradient(clip.title.isEmpty ? clip.url : clip.title),
                tags: clip.tags
            )
        }
        .buttonStyle(.plain)
        .plainRow()
        .swipeActions(edge: .trailing) {
            Button(i18n.t("common.delete"), role: .destructive) {
                localStore.delete(url: clip.url)
                reload()
                ClipsRefresh.emit()
            }
        }
    }

    /// 옮기기(주)·모두 삭제(부). 계정 목록의 다중선택 바와 같은 자리·같은 높이로 둔다.
    private var actionBar: some View {
        HStack(spacing: 8) {
            Button(i18n.t("localClips.deleteAll")) {
                deleteAllRequest = ClipCount(value: clips?.count ?? 0)
            }
            .buttonStyle(ModalGhostButton())

            Button(i18n.t("localClips.move")) {
                migrateRequest = ClipCount(value: clips?.count ?? 0)
            }
            .buttonStyle(ModalFilledButton(color: AppColor.brand))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var emptyState: some View {
        Text(i18n.t("localClips.empty"))
            .font(.system(size: 15))
            .foregroundStyle(AppColor.fgMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
    }

    private func deleteAllLayer(_ pending: Int) -> some View {
        let count = i18n.t("clips.countUnit", args: pending)
        return ConfirmLayer(
            title: i18n.t("localClips.deleteAllTitle"),
            message: emphasized(i18n.t("localClips.deleteAllBody", args: count), [count]),
            confirmLabel: i18n.t("common.delete"),
            emphasis: .destructive,
            cancelLabel: i18n.t("common.cancel"),
            onConfirm: {
                deleteAllRequest = nil
                localStore.clearLocalClips()
                ClipsRefresh.emit()
                reload()
            },
            onCancel: { deleteAllRequest = nil }
        )
    }

    private func reload() {
        clips = localStore.all().map(UClip.init)
    }
}

/// `.sheet(item:)`용 URL 래퍼.
private struct LocalSafariItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
