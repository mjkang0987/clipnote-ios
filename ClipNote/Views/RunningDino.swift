import SwiftUI

/// 링크 정보를 읽는 동안 달리는 공룡.
///
/// 메타 추출은 원본 사이트를 대신 열어 보는 일이라, 사이트에 따라 몇 초씩 걸린다
/// (어댑터 → 다른 UA 로 재시도 → 이미지 실재 확인이 차례로 붙는다). 그동안 스피너만 돌면
/// 멈춘 것처럼 느껴져서, 기다리는 시간을 견딜 만하게 만드는 쪽을 택했다.
///
/// **도트를 직접 그리지 않고 이모지를 쓴다.** 픽셀 맵으로 크롬 공룡을 흉내 내 봤지만 어느 판도
/// 귀엽지 않았다 — 눈이 한 칸이라 검은 덩어리에 구멍이 뚫린 인상이었다. 이모지는 기기가 이미
/// 다듬어 둔 그림이라 어느 크기에서도 무너지지 않고, 시스템이 갱신되면 같이 좋아진다.
struct RunningDino: View {
    /// 가로 이동 속도(pt/초).
    private static let speed = 96.0
    /// 뜀박질 한 번에 걸리는 시간(초). 짧을수록 종종거린다.
    private static let hopPeriod = 0.44
    /// 뜀박질 높이(pt).
    private static let hopHeight = 7.0
    private static let size = 30.0

    /// 시스템 "동작 줄이기" 가 켜져 있으면 움직이지 않는다 — 전정기관 장애가 있는 사용자에게
    /// 화면을 가로지르는 반복 운동은 불편을 준다. 공룡은 그대로 두고 멈춰 세운다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                let elapsed = timeline.date.timeIntervalSince(start)
                Text(verbatim: "🦖")
                    .font(.system(size: Self.size))
                    .offset(x: x(in: proxy.size.width, elapsed: elapsed),
                            y: -hop(elapsed: elapsed))
            }
        }
        .frame(height: Self.size + Self.hopHeight + 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColor.fgMuted.opacity(0.3))
                .frame(height: 1.5)
        }
        // 진행 상황은 옆의 문구가 알린다. 장식이 한 번 더 읽히면 방해만 된다.
        .accessibilityHidden(true)
    }

    /// 왼쪽 밖에서 들어와 오른쪽 밖으로 빠지고 다시 돈다.
    private func x(in width: CGFloat, elapsed: TimeInterval) -> CGFloat {
        guard !reduceMotion else { return (width - Self.size) / 2 }
        let travel = width + Self.size
        return CGFloat((elapsed * Self.speed).truncatingRemainder(dividingBy: travel)) - Self.size
    }

    /// 위로 살짝 튀는 높이. 사인 곡선의 위쪽 반만 써서 **땅에 닿는 순간**을 만든다 —
    /// 계속 오르내리기만 하면 떠다니는 것처럼 보인다.
    private func hop(elapsed: TimeInterval) -> CGFloat {
        guard !reduceMotion else { return 0 }
        let phase = elapsed.truncatingRemainder(dividingBy: Self.hopPeriod) / Self.hopPeriod
        return CGFloat(sin(phase * .pi)) * Self.hopHeight
    }
}
