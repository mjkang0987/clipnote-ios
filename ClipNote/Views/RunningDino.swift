import SwiftUI

/// 링크 정보를 읽는 동안 **테두리를 따라 걸어 다니는** 공룡.
///
/// 메타 추출은 원본 사이트를 대신 열어 보는 일이라, 사이트에 따라 몇 초씩 걸린다
/// (어댑터 → 다른 UA 로 재시도 → 이미지 실재 확인이 차례로 붙는다). 그동안 스피너만 돌면
/// 멈춘 것처럼 느껴져서, 기다리는 시간을 견딜 만하게 만드는 쪽을 택했다.
///
/// **안쪽에서 벽을 밟는다.** 테두리 바깥에 세워 봤더니 상자 밖으로 나가는 만큼이 잘려 나갔다
/// — 안쪽 여백보다 공룡이 커서, 좌우 면으로 넘어가는 순간 사라졌다. 안에서 밟으면 잘릴
/// 일이 없다. 대신 천장 면에서는 거꾸로 매달려 걷는다.
///
/// **네 면 중 한 면은 쉬어 간다.** 어느 면을 건너뛸지는 로딩이 시작될 때마다 새로 뽑는다 —
/// 매번 같은 자리를 같은 방향으로 돌면 두 번째부터는 그냥 배경이 된다. 건너뛴 면은 공룡이
/// 잠깐 사라졌다 반대편에서 다시 나타나는 구간이 된다.
///
/// 도는 자리는 **호출부가 준 사각형**이 정한다. 그 안에서만 그려지므로 어디에 얹어도 안전하다.
struct RunningDino: View {
    /// 걷기 프레임 수. 자산 이름이 `DinoRun1`…`DinoRun4`.
    private static let frameCount = 4

    /// 목표 속도(pt/초)와 한 바퀴 시간의 상·하한(초).
    ///
    /// 둘 중 하나만 고정하면 도는 자리가 바뀔 때 망가진다. 속도만 고정하면 화면 둘레에서
    /// 한 바퀴가 10초씩 걸려 로딩이 끝날 때까지 모서리에서 꿈틀대고, 시간만 고정하면
    /// 큰 상자에서 총알처럼 날아간다. 목표 속도로 시간을 정하되 범위를 벗어나지 않게 자른다.
    private static let targetSpeed = 150.0
    private static let lapRange = 3.0...7.0

    /// 네 프레임을 한 번 도는 데 걷는 거리(pt).
    ///
    /// 프레임을 시간이 아니라 **걸은 거리**에 맞춘다. 시간에 맞추면 빨리 달릴수록 다리가
    /// 제자리에서 헛돌아 미끄러지는 것처럼 보인다.
    private static let stride = 36.0

    /// 그려질 높이(pt)와 원본 도트의 가로세로비(47×45).
    private static let height: CGFloat = 34
    private static let width: CGFloat = 34 * 47 / 45

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
        // **`Canvas` 로 그린다. `GeometryReader` 를 쓰지 않는다.**
        //
        // 둘 다 준 자리를 꽉 채우지만 성격이 다르다. `GeometryReader` 는 잰 크기를 자식에게
        // 흘려보내는 측정 도구라, 그 자식이 다시 크기에 관여하면 레이아웃이 한 바퀴 돌 수
        // 있다. 장식 하나 때문에 화면 레이아웃이 흔들릴 여지를 남길 이유가 없다.
        // `Canvas` 는 제안받은 크기를 그대로 받아 그리기만 하는 잎이라 되먹임이 없다.
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let spot = spot(in: size, elapsed: timeline.date.timeIntervalSince(start))
                // 좌표계를 공룡 쪽으로 옮겨 놓고 그린다.
                context.translateBy(x: spot.center.x, y: spot.center.y)
                context.rotate(by: .degrees(spot.angle))
                context.draw(
                    // `.interpolation(.none)` 이 없으면 47×45 도트를 34pt 로 늘릴 때
                    // 시스템이 부드럽게 섞어 버려 픽셀 아트가 뭉갠 그림이 된다.
                    context.resolve(Image("DinoRun\(spot.frame + 1)")
                        .resizable()
                        .interpolation(.none)),
                    in: CGRect(x: -Self.width / 2, y: -Self.height / 2,
                               width: Self.width, height: Self.height)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        // 진행 상황은 옆의 문구가 알린다. 장식이 한 번 더 읽히면 방해만 된다.
        .accessibilityHidden(true)
    }

    /// 지금 이 순간 공룡이 서 있는 자리와 걷기 프레임.
    private struct Spot {
        /// 그림의 중심(호출부 사각형 좌표계).
        let center: CGPoint
        /// 밟고 있는 벽을 향해 발이 가도록 돌리는 각도.
        ///
        /// 회전은 몸의 방향과 진행 방향을 함께 돌린다. 바닥에서 오른쪽으로 걷던 것을
        /// 90° 돌리면 오른쪽 벽에서 위로 걷는 게 된다 — 면마다 따로 계산할 게 없다.
        /// 스프라이트가 이미 오른쪽을 보고 있어 좌우를 뒤집을 일은 없다.
        let angle: Double
        /// 0부터 `frameCount - 1`.
        let frame: Int
    }

    /// 반시계 방향으로 도는 세 면. 건너뛴 면 **다음**부터 이어진다.
    ///
    /// 안에서 벽을 밟으면 발이 바깥을 향하고, 회전이 진행 방향까지 같이 뒤집는다.
    /// 그래서 도는 방향도 반시계로 맞춘다 — 아니면 뒷걸음질이 된다.
    private var route: [Int] { (1...3).map { (skipped + 4 - $0) % 4 } }

    private func spot(in box: CGSize, elapsed: TimeInterval) -> Spot {
        let lengths = route.map { length(of: $0, in: box) }
        let total = lengths.reduce(0, +)
        guard total > 0 else {
            return Spot(center: CGPoint(x: box.width / 2, y: 0), angle: 0, frame: 0)
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
        // 발이 벽에 닿도록 그림의 중심을 안쪽으로 반 칸 민다. 스프라이트는 아랫변이 곧 발바닥이다.
        let standoff = Self.height / 2
        let step = Self.stride / Double(Self.frameCount)
        return Spot(
            center: CGPoint(x: edge.x + into.dx * standoff, y: edge.y + into.dy * standoff),
            // 180° 를 더해 발이 바깥(벽)을 향하게 한다. 천장 면에서는 거꾸로 매달린다.
            angle: Double(side) * 90 + 180,
            frame: reduceMotion ? 0 : Int(Double(distance) / step) % Self.frameCount
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
}
