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
/// **아래쪽 면은 걷지 않는다.** 광고 배너·홈 인디케이터와 겹치는 자리라 거기 붙어 걸으면
/// 지저분하다. 오른쪽 → 위 → 왼쪽 세 면만 돌고, 빠진 아래쪽은 공룡이 잠깐 사라졌다
/// 반대편에서 다시 나타나는 구간이 된다.
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

    /// 코너를 넘는 동안 지나가는 거리(pt). 코너 앞뒤로 절반씩 걸친다.
    private static let turnSpan: CGFloat = 30
    /// 도약 높이(pt). 벽에서 떨어지는 쪽, 즉 상자 안쪽으로 뛴다.
    private static let jumpHeight: CGFloat = 12
    /// 뛰는 동안 고정할 프레임(0부터). 다리가 벌어진 자세라 도약으로 읽힌다.
    private static let leapFrame = 1

    /// 시스템 "동작 줄이기" 가 켜져 있으면 움직이지 않는다 — 전정기관 장애가 있는 사용자에게
    /// 화면을 가로지르는 반복 운동은 불편을 준다. 공룡은 그대로 두고 멈춰 세운다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    /// **건너뛰는 면 — 아래쪽 고정**(0=위 1=오른쪽 2=아래 3=왼쪽).
    ///
    /// 전에는 로딩마다 무작위로 뽑았는데, 아래쪽 면은 광고 배너·홈 인디케이터와 겹치는
    /// 자리라 공룡이 거기 붙어 걸으면 지저분하다. 남는 세 면(오른쪽 → 위 → 왼쪽)만 돈다.
    private static let skipped = 2

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

    /// 반시계로 도는 세 면 — 오른쪽 → 위 → 왼쪽. 건너뛴 아래쪽 면 **다음**부터 이어진다.
    ///
    /// 안에서 벽을 밟으면 발이 바깥을 향하고, 회전이 진행 방향까지 같이 뒤집는다.
    /// 그래서 도는 방향도 반시계로 맞춘다 — 아니면 뒷걸음질이 된다.
    private var route: [Int] { (1...3).map { (Self.skipped + 4 - $0) % 4 } }

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

        let step = Self.stride / Double(Self.frameCount)
        let walking = stand(at: distance, in: box, lengths: lengths)
        let frame = reduceMotion ? 0 : Int(Double(distance) / step) % Self.frameCount

        guard !reduceMotion,
              let turn = turn(at: distance, in: box, lengths: lengths) else {
            return Spot(center: walking.center, angle: walking.angle, frame: frame)
        }
        return turn
    }

    /// 코너를 넘는 동작. 코너 근처가 아니면 nil.
    ///
    /// 전에는 면이 바뀌는 순간 각도가 90° 툭 꺾였다. 걷다가 몸만 홱 돌아가니 벽을 타는
    /// 것보다 순간이동에 가까웠다. 코너 앞뒤 구간을 하나의 도약으로 묶는다 — 벽에서 떨어져
    /// 나오면서 돌고, 다음 벽에 착지한다.
    private func turn(at distance: CGFloat, in box: CGSize, lengths: [CGFloat]) -> Spot? {
        // 짧은 면에서 도약 구간이 면보다 길면 앞뒤 코너가 겹친다.
        let span = min(Self.turnSpan, (lengths.min() ?? 0))
        guard span > 0 else { return nil }

        // 건너뛰는 면 쪽 이음매(경로의 처음·끝)에서는 돌지 않는다 — 거기서는 공룡이
        // 사라졌다 반대편에서 나타난다. 도는 건 경로 안쪽 두 코너뿐이다.
        var corner: CGFloat = 0
        for index in 0..<(lengths.count - 1) {
            corner += lengths[index]
            let entered = distance - (corner - span / 2)
            guard entered >= 0, entered <= span else { continue }

            let progress = Double(entered / span)
            let before = stand(at: corner - span / 2, in: box, lengths: lengths)
            let after = stand(at: corner + span / 2, in: box, lengths: lengths)

            // 두 벽의 안쪽 방향을 합치면 코너에서 상자 안을 향하는 대각선이 된다.
            let a = inward(of: route[index])
            let b = inward(of: route[index + 1])
            let lift = normalized(CGVector(dx: a.dx + b.dx, dy: a.dy + b.dy))
            let height = CGFloat(sin(progress * .pi)) * Self.jumpHeight

            let x = before.center.x + (after.center.x - before.center.x) * CGFloat(progress)
            let y = before.center.y + (after.center.y - before.center.y) * CGFloat(progress)
            return Spot(
                center: CGPoint(x: x + lift.dx * height, y: y + lift.dy * height),
                // 반시계로 도니 각도는 항상 90° 줄어든다. 사이를 이어서 몸이 따라 돌게 한다.
                angle: before.angle - 90 * progress,
                frame: Self.leapFrame
            )
        }
        return nil
    }

    /// 그 거리에서 **걸어가고 있을 때**의 자리와 각도.
    private func stand(at distance: CGFloat, in box: CGSize, lengths: [CGFloat]) -> Spot {
        var walked = max(0, distance)
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
        return Spot(
            center: CGPoint(x: edge.x + into.dx * standoff, y: edge.y + into.dy * standoff),
            // 180° 를 더해 발이 바깥(벽)을 향하게 한다. 천장 면에서는 거꾸로 매달린다.
            angle: Double(side) * 90 + 180,
            frame: 0
        )
    }

    private func normalized(_ v: CGVector) -> CGVector {
        let length = (v.dx * v.dx + v.dy * v.dy).squareRoot()
        guard length > 0 else { return v }
        return CGVector(dx: v.dx / length, dy: v.dy / length)
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
