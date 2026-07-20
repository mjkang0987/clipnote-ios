import SwiftUI

/// 온보딩 — 실제 홈 UI 위에 스포트라이트 투어로 "어느 영역=어느 기능 / 플로우"를 안내.
/// 슬라이드 이미지 방식 대체(§온보딩 개편). 완료 시 `onDone`(호출부가 onboardingSeen 저장/pop).
struct OnboardingView: View {
    let onDone: () -> Void

    @State private var index = 0
    @State private var anchors: [TourAnchor: CGRect] = [:]
    /// 임베드한 HomeView용 라우터(투어는 비상호작용이라 실제 이동은 발생하지 않음).
    @State private var tourRouter = AppRouter()

    private let steps: [TourStep] = [
        TourStep(anchor: .url,
                 title: "여기에 링크를 붙여넣어요",
                 desc: "공유하고 싶은 페이지 URL만 넣으면 시작돼요.",
                 audience: "누구나", loginOnly: false),
        TourStep(anchor: .options,
                 title: "제목·태그는 선택이에요",
                 desc: "제목을 비우면 링크에서 자동으로 채워요. 태그로 분류할 수 있어요.",
                 audience: "누구나", loginOnly: false),
        TourStep(anchor: .save,
                 title: "내 클립에 저장",
                 desc: "저장하면 목록에 쌓여요. 게스트는 이 기기에, 로그인하면 내 계정에 저장돼요.",
                 audience: "누구나", loginOnly: false),
        TourStep(anchor: .share,
                 title: "짧은 공유 링크 만들기",
                 desc: "로그인하면 예쁜 공유 카드와 짧은 링크를 한 번에 만들 수 있어요.",
                 audience: "로그인 필요", loginOnly: true),
        TourStep(anchor: .myClips,
                 title: "내 클립 목록",
                 desc: "저장한 클립을 여기서 모아 보고 편집·공유해요.",
                 audience: nil, loginOnly: false),
        TourStep(anchor: .menu,
                 title: "메뉴",
                 desc: "로그인·사용법·개인정보 등 다른 화면으로 이동해요.",
                 audience: nil, loginOnly: false),
    ]

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
