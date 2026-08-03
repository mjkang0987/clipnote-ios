import SwiftUI
import SwiftData

/// 로컬 클립을 계정으로 옮기는 흐름 — 확인 레이어·진행 표시·결과 알림을 한 벌로 묶는다.
///
/// **왜 따로 두나.** 부르는 곳이 둘이다 — 로그인 직후 한 번 권하는 자리(`RootView`)와
/// ‘이 기기에 남은 클립’ 화면의 옮기기 버튼. 같은 문구·같은 결과 처리를 두 벌 두면
/// 한쪽만 고쳐지는 일이 생긴다(웹에서 실제로 그랬다).
///
/// 붙이는 쪽은 `request` 에 옮길 개수를 넣기만 하면 된다. 닫기·되돌리기는 여기서 한다.
struct MigrateLocalClipsLayer: ViewModifier {
    /// 옮길 클립 수. nil 이면 아무것도 띄우지 않는다.
    ///
    /// 개수를 그리는 레이어는 전부 `.sheet(item:)` 으로 값을 실어 보낸다 — `ClipCount` 주석 참고.
    @Binding var request: ClipCount?

    /// 옮기기가 끝난 뒤. 인자는 전량 성공 여부.
    ///
    /// 뒤처리가 화면마다 다르다 — 로그인 자리는 할 일이 없고, 로컬 화면은 비었으니 닫는다.
    var onFinished: (Bool) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(LocalizationStore.self) private var i18n
    @EnvironmentObject private var auth: AuthStore

    @State private var migrating = false
    @State private var resultMessage: String?

    func body(content: Content) -> some View {
        content
            .sheet(item: $request) { layer($0.value) }
            // 옮기기 결과는 결정이 아니라 알림이라 레이어로 만들지 않는다.
            // (웹은 페이지가 그 자리에서 갱신돼 알림이 없지만, 앱은 네트워크 작업이라 결과를 알린다.)
            .alert(i18n.t("clips.migrateResultTitle"), isPresented: resultBinding) {
                Button(i18n.t("common.confirm"), role: .cancel) { resultMessage = nil }
            } message: {
                Text(resultMessage ?? "")
            }
    }

    private func layer(_ pending: Int) -> some View {
        let count = countUnit(pending)
        return ConfirmLayer(
            title: i18n.t("clips.migrateTitle"),
            message: emphasized(i18n.t("clips.migrateBody", args: count), [count]),
            confirmLabel: i18n.t("clips.migrateConfirm", args: count),
            busy: migrating,
            busyLabel: i18n.t("clips.migrating"),
            cancelLabel: i18n.t("common.cancel"),
            // 옮기는 동안 레이어를 열어 둔 채 스피너를 보여 준다(웹과 동일). 끝나면 닫는다.
            onConfirm: { migrate() },
            onCancel: { request = nil }
        )
        // 진행 중에는 스와이프로 닫지 못하게 막는다 — 중간에 닫히면 무엇이 옮겨졌는지 알 수 없다.
        .interactiveDismissDisabled(migrating)
    }

    private var resultBinding: Binding<Bool> {
        Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })
    }

    /// 수량 표기(`3개`·`3 clips`)는 언어마다 단위 위치가 달라 문장에서 떼어 둔다.
    /// 이걸 만들어 `%@` 자리에 끼워 넣는다 — 웹 `clips.countUnit` 과 같은 방식.
    private func countUnit(_ count: Int) -> String {
        i18n.t("clips.countUnit", args: count)
    }

    private func migrate() {
        let store = LocalClipStore(container: modelContext.container)
        let token = auth.accessToken
        migrating = true
        Task {
            let (uploaded, allOK) = await MigrateLocalClips(localStore: store).run(accessToken: token)
            migrating = false
            request = nil
            resultMessage = allOK
                ? i18n.t("clips.migrateDone", args: countUnit(uploaded))
                : i18n.t("clips.migratePartial")
            ClipsRefresh.emit()
            onFinished(allOK)
        }
    }
}

extension View {
    /// 로컬 클립 옮기기 흐름을 붙인다 — `MigrateLocalClipsLayer` 참고.
    func migrateLocalClipsLayer(
        request: Binding<ClipCount?>,
        onFinished: @escaping (Bool) -> Void = { _ in }
    ) -> some View {
        modifier(MigrateLocalClipsLayer(request: request, onFinished: onFinished))
    }
}
