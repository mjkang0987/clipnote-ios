import SwiftUI

/// 온보딩 — 실제 홈 UI 위에 스포트라이트 투어로 "어느 영역=어느 기능 / 플로우"를 안내.
/// 슬라이드 이미지 방식 대체(§온보딩 개편). 완료 시 `onDone`(호출부가 onboardingSeen 저장/pop).
struct OnboardingView: View {
    let onDone: () -> Void

    @State private var index = 0
    @State private var anchors: [TourAnchor: CGRect] = [:]
    /// 임베드한 HomeView용 라우터(투어는 비상호작용이라 실제 이동은 발생하지 않음).
    @State private var tourRouter = AppRouter()

    @Environment(LocalizationStore.self) private var i18n

    /// 투어 단계. `let` 상수가 아니라 계산 프로퍼티다 — 표시 언어가 바뀌면 문구도 따라 바뀌어야
    /// 하는데, 저장 프로퍼티로 두면 뷰가 처음 만들어진 시점의 언어로 굳는다.
    private var steps: [TourStep] {
        [
            TourStep(anchor: .url,
                     title: i18n.t("onboarding.urlTitle"),
                     desc: i18n.t("onboarding.urlDesc"),
                     audience: i18n.t("onboarding.audienceAnyone"), loginOnly: false),
            TourStep(anchor: .options,
                     title: i18n.t("onboarding.optionsTitle"),
                     desc: i18n.t("onboarding.optionsDesc"),
                     audience: i18n.t("onboarding.audienceAnyone"), loginOnly: false),
            TourStep(anchor: .save,
                     title: i18n.t("onboarding.saveTitle"),
                     desc: i18n.t("onboarding.saveDesc"),
                     audience: i18n.t("onboarding.audienceAnyone"), loginOnly: false),
            TourStep(anchor: .share,
                     title: i18n.t("onboarding.shareTitle"),
                     desc: i18n.t("onboarding.shareDesc"),
                     audience: i18n.t("onboarding.audienceLogin"), loginOnly: true),
            TourStep(anchor: nil,
                     title: i18n.t("onboarding.clipsTitle"),
                     desc: i18n.t("onboarding.clipsDesc", args: i18n.t("common.myClips")),
                     audience: nil, loginOnly: false),
        ]
    }

    var body
    var body: some View {
        ZStack {
            NavigationStack {
                HomeView()
                    .environment(tourRouter)
            }
            .allowsHitTesting(false)          // 투어 중 실제 UI 조작 차단
            .coordinateSpace(.named("tour"))
            .onPreferenceChange(TourAnchorKey.self) { anchors = $0 }

            SpotlightOverlay(steps: steps, anchors: anchors, index: $index, onDone: onDone)
        }
        .toolbar(.hidden, for: .navigationBar)  // 메뉴 경유 진입 시 상위 내비바 숨김
    }
}
