import SwiftUI

/// 링크 정보를 읽는 동안 **입력칸 테두리를 따라 걸어 다니는** 공룡.
///
/// 메타 추출은 원본 사이트를 대신 열어 보는 일이라, 사이트에 따라 몇 초씩 걸린다
/// (어댑터 → 다른 UA 로 재시도 → 이미지 실재 확인이 차례로 붙는다). 그동안 스피너만 돌면
/// 멈춘 것처럼 느껴져서, 기다리는 시간을 견딜 만하게 만드는 쪽을 택했다.
///
/// **안쪽에서 벽을 밟는다.** 테두리 바깥에 세워 봤더니 상자 밖으로 나가는 만큼이 잘려 나갔다
/// — 카드 안쪽 여백보다 공룡이 커서, 좌우 면으로 넘어가는 순간 사라졌다. 안에서 밟으면 잘릴
/// 일이 없다. 대신 천장 면에서는 거꾸로 매달려 걷는다.
///
/// **네 면 중 한 면은 쉬어 간다.** 어느 면을 건너뛸지는 로딩이 시작될 때마다 새로 뽑는다 —
/// 매번 같은 자리를 같은 방향으로 돌면 두 번째부터는 그냥 배경이 된다. 건너뛴 면은 공룡이
/// 잠깐 사라졌다 반대편에서 다시 나타나는 구간이 된다.
///
/// **도트를 직접 그리지 않고 이모지를 쓴다.** 픽셀 맵으로 크롬 공룡을 흉내 내 봤지만 어느 판도
/// 귀엽지 않았다 — 눈이 한 칸이라 검은 덩어리에 구멍이 뚫린 인상이었다. 이모지는 기기가 이미
/// 다듬어 둔 그림이라 어느 크기에서도 무너지지 않고, 시스템이 갱신되면 같이 좋아진다.
///
/// 도는 자리는 **호출부가 준 사각형**이 정한다. 그 안에서만 그려지므로 어디에 얹어도 안전하다.
struct RunningDino: View {
    /// 목표 속도(pt/초)와 한 바퀴 시간의 상·하한(초).
    ///
    /// 둘 중 하나만 고정하면 도는 자리가 바뀔 때 망가진다. 속도만 고정하면 화면 둘레에서
    /// 한 바퀴가 10초씩 걸려 로딩이 끝날 때까지 모서리에서 꿈틀대고, 시간만 고정하면
    /// 큰 상자에서 총알처럼 날아간다. 목표 속도로 시간을 정하되 범위를 벗어나지 않게 자른다.
    private static let targetSpeed = 150.0
    private static let lapRange = 3.0...7.0
    /// 한 걸음의 보폭(pt). 뜀박질을 시간이 아니라 **걸은 거리**에 맞춰야 속도가 달라져도
    /// 보폭이 유지된다 — 시간에 맞추면 빨리 달릴수록 성큼성큼 미끄러진다.
    private static let stride = 34.0
    /// 뜀박질 높이(pt). 밟고 있는 벽에서 **떨어지는 쪽**으로 튄다(천장이면 아래로).
    private static let hopHeight: CGFloat = 5
    private static let size: CGFloat = 32

    /// 시스템 "동작 줄이기" 가 켜져 있으면 움직이지 않는다 — 전정기관 장애가 있는 사용자에게
    /// 화면을 가로지르는 반복 운동은 불편을 준다. 공룡은 그대로 두고 멈춰 세운다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    /// 이번 로딩에 **건너뛸 한 면**(0=위 1=오른쪽 2=아래 3=왼쪽).
    ///
    /// `@State` 라 뷰가 새로 생길 때 한 번만 뽑힌다. 이 뷰는 로딩 중에만 존재하므로
    /// "로딩마다 한 번" 이 그대로 성립하고, 프레임마다 다시 뽑혀 순간이동하는 일도 없다.
    @State private var skipped = Int.random(in: 0..<4)

    var body: some View {
        // `GeometryReader` 가 가장 바깥이다. 안쪽에 두면 크기를 재 줄 사람이 `TimelineView`
        // 인데, 그건 자리를 차지하겠다고 주장하지 않는 컨테이너라 오버레이 안에서 크기가
        // 0 으로 접힐 수 있다 — 공룡이 아예 안 그려지던 게 이 모양이었다.
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                let spot = spot(in: proxy.size, elapsed: timeline.date.timeIntervalSince(start))
                Text(verbatim: "🦖")
                    .font(.system(size: Self.size))
                    // 이 이모지는 **왼쪽을 보고** 그려져 있다. 진행 방향이 오른쪽이라
                    // 그대로 두면 뒷걸음질로 읽힌다.
                    .scaleEffect(x: -1, y: 1)
                    // 회전 **전에** 얹어야 뜀박질이 몸을 따라 돈다 — 옆면에서는 옆으로 튄다.
                    .offset(y: -spot.hop)
                    .rotationEffect(.degrees(spot.angle))
                    .position(spot.center)
                    // 어디에 얹히든 잰 크기를 그대로 쓴다.
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .allowsHitTesting(false)
        // 진행 상황은 옆의 문구가 알린다. 장식이 한 번 더 읽히면 방해만 된다.
        .accessibilityHidden(true)
    }

    /// 지금 이 순간 공룡이 서 있는 자리.
    private struct Spot {
        /// 이모지 프레임의 중심(호출부 사각형 좌표계).
        let center: CGPoint
        /// 밟고 있는 벽을 향해 발이 가도록 돌리는 각도.
        ///
        /// 회전은 몸의 방향과 진행 방향을 함께 돌린다. 바닥에서 오른쪽으로 달리던 것을
        /// 90° 돌리면 오른쪽 벽에서 위로 달리는 게 된다 — 면마다 따로 계산할 게 없다.
        let angle: Double
        let hop: CGFloat
    }

    /// 반시계 방향으로 도는 세 면. 건너뛴 면 **다음**부터 이어진다.
    ///
    /// 안에서 벽을 밟으면 발이 바깥을 향하고, 회전이 진행 방향까지 같이 뒤집는다.
    /// 그래서 도는 방향도 반시계로 맞춘다 — 아니면 다시 뒷걸음질이 된다.
    private var route: [Int] { (1...3).map { (skipped + 4 - $0) % 4 } }

    private func spot(in box: CGSize, elapsed: TimeInterval) -> Spot {
        let lengths = route.map { length(of: $0, in: box) }
        let total = lengths.reduce(0, +)
        guard total > 0 else {
            return Spot(center: CGPoint(x: box.width / 2, y: 0), angle: 0, hop: 0)
        }

        let lap = min(max(Double(total) / Self.targetSpeed, Self.lapRange.lowerBound),
                      Self.lapRange.upperBound)
        let progress = (elapsed / lap).truncatingRemainder(dividingBy: 1)
        // 멈춰 세울 때는 첫 면 한가운데에 세운다 — 모서리에 걸치면 잘린 것처럼 보인다.
        let distance = reduceMotion ? lengths[0] / 2 : total * CGFloat(progress)

        var walked = distance
        var index = 0
        while index < lengths.count - 1, walked >= lengths[index] {
            walked -= lengths[index]
            index += 1
        }

        let side = route[index]
        let edge = point(on: side, at: min(walked, lengths[index]), in: box)
        let into = inward(of: side)
        // 발이 벽에 닿도록 이모지 중심을 안쪽으로 반 칸 민다. 이모지 글리프가 프레임을
        // 꽉 채우지는 않아서 1pt 을 덜 준다.
        let standoff: CGFloat = Self.size / 2 - 1
        return Spot(
            center: CGPoint(x: edge.x + into.dx * standoff, y: edge.y + into.dy * standoff),
            // 180° 를 더해 발이 바깥(벽)을 향하게 한다. 천장 면에서는 거꾸로 매달린다.
            angle: Double(side) * 90 + 180,
            hop: hop(after: distance)
        )
    }

    private func length(of side: Int, in box: CGSize) -> CGFloat {
        side.isMultiple(of: 2) ? box.width : box.height
    }

    /// 면 위 `distance` 지점. **반시계 방향**으로 훑는다(위는 오른쪽에서 왼쪽으로).
    private func point(on side: Int, at distance: CGFloat, in box: CGSize) -> CGPoint {
        switch side {
        case 0: CGPoint(x: box.width - distance, y: 0)
        case 1: CGPoint(x: box.width, y: box.height - distance)
        case 2: CGPoint(x: distance, y: box.height)
        default: CGPoint(x: 0, y: distance)
        }
    }

    /// 그 벽의 안쪽 방향. 공룡은 상자 안에 서서 벽을 밟는다.
    private func inward(of side: Int) -> CGVector {
        switch side {
        case 0: CGVector(dx: 0, dy: 1)
        case 1: CGVector(dx: -1, dy: 0)
        case 2: CGVector(dx: 0, dy: -1)
        default: CGVector(dx: 1, dy: 0)
        }
    }

    /// 살짝 튀는 높이. 사인 곡선의 위쪽 반만 써서 **땅에 닿는 순간**을 만든다 —
    /// 계속 오르내리기만 하면 떠다니는 것처럼 보인다.
    private func hop(after distance: CGFloat) -> CGFloat {
        guard !reduceMotion else { return 0 }
        let phase = Double(distance).truncatingRemainder(dividingBy: Self.stride) / Self.stride
        return CGFloat(sin(phase * .pi)) * Self.hopHeight
    }
}
