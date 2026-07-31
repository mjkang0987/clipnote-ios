import SwiftUI

/// 링크 정보를 읽는 동안 달리는 도트 공룡 — 크롬 오프라인 화면 느낌.
///
/// 메타 추출은 원본 사이트를 대신 열어 보는 일이라, 사이트에 따라 몇 초씩 걸린다
/// (어댑터 → 다른 UA 로 재시도 → 이미지 실재 확인이 차례로 붙는다). 그동안 스피너만 돌면
/// 멈춘 것처럼 느껴져서, 기다리는 시간을 견딜 만하게 만드는 쪽을 택했다.
///
/// 에셋을 쓰지 않고 픽셀 맵을 그린다 — 4배수 해상도마다 이미지를 따로 넣을 필요가 없고,
/// 색을 테마에 맞춰 바꿀 수 있다.
struct RunningDino: View {
    /// 다리 교대 속도(초당). 크롬과 비슷하게 빠르게 젓는다.
    private static let stepsPerSecond = 10.0
    /// 가로 이동 속도(pt/초).
    private static let speed = 96.0
    /// 픽셀 한 칸의 크기. 공룡은 24×26칸이라 높이가 약 47pt 가 된다.
    private static let cell = 1.8

    var color: Color = AppColor.fgMuted

    /// 시스템 "동작 줄이기" 가 켜져 있으면 움직이지 않는다 — 전정기관 장애가 있는 사용자에게
    /// 화면을 가로지르는 반복 운동은 불편을 준다. 공룡은 그대로 두고 멈춰 세운다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                draw(in: context, size: size, elapsed: timeline.date.timeIntervalSince(start))
            }
        }
        .frame(height: CGFloat(DinoSprite.height) * Self.cell + 6)
        // 진행 상황은 옆의 문구가 알린다. 장식이 한 번 더 읽히면 방해만 된다.
        .accessibilityHidden(true)
    }

    private func draw(in context: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let dinoWidth = CGFloat(DinoSprite.width) * Self.cell
        let dinoHeight = CGFloat(DinoSprite.height) * Self.cell
        let groundY = dinoHeight + 3

        // 왼쪽 밖에서 들어와 오른쪽 밖으로 빠지고 다시 돈다.
        let travel = size.width + dinoWidth
        let x = reduceMotion
            ? (size.width - dinoWidth) / 2
            : (elapsed * Self.speed).truncatingRemainder(dividingBy: travel) - dinoWidth

        drawGround(in: context, size: size, y: groundY, elapsed: elapsed)

        let step = reduceMotion ? 0 : Int(elapsed * Self.stepsPerSecond) % 2
        var pixels = Path()
        for (row, line) in DinoSprite.frame(step).enumerated() {
            for (column, mark) in line.enumerated() where mark == "#" {
                pixels.addRect(CGRect(
                    x: x + CGFloat(column) * Self.cell,
                    y: CGFloat(row) * Self.cell,
                    width: Self.cell, height: Self.cell
                ))
            }
        }
        context.fill(pixels, with: .color(color))
    }

    /// 바닥선 — 공룡과 **반대 방향**으로 흐르는 짧은 자국들을 얹어 달리는 느낌을 만든다.
    private func drawGround(in context: GraphicsContext, size: CGSize, y: CGFloat, elapsed: TimeInterval) {
        var line = Path()
        line.addRect(CGRect(x: 0, y: y, width: size.width, height: Self.cell))
        context.fill(line, with: .color(color.opacity(0.35)))

        guard !reduceMotion else { return }
        let spacing: CGFloat = 34
        let drift = CGFloat((elapsed * Self.speed).truncatingRemainder(dividingBy: Double(spacing)))
        var marks = Path()
        var x = -spacing + drift
        while x < size.width {
            marks.addRect(CGRect(x: x, y: y - Self.cell, width: Self.cell * 3, height: Self.cell))
            x += spacing
        }
        context.fill(marks, with: .color(color.opacity(0.35)))
    }
}

/// 공룡 픽셀 맵. `#` 이 칠하는 칸이다.
///
/// 몸통은 고정이고 다리 네 줄만 갈아 끼워 달리는 동작을 만든다 — 크롬 공룡과 같은 방식이다.
private enum DinoSprite {
    static let width = 24
    static var height: Int { body.count + legs[0].count }

    static func frame(_ step: Int) -> [String] {
        body + legs[step % legs.count]
    }

    private static let body = [
        "..............##########",
        "..............##########",
        "..............##.#######",   // 눈 = 비워 둔 칸
        "..............##########",
        "..............##########",
        "..............######....",
        "..............#########.",   // 아래턱이 앞으로 튀어나온 주둥이
        "..............######....",
        ".#............######....",   // 목은 머리보다 좁다
        ".##...........######....",
        ".###..........######....",   // 꼬리는 왼쪽 위로 뻗는다
        ".####.........######....",
        ".#####........######....",
        ".######......#######....",
        ".####################...",
        ".####################...",
        "..###################...",
        "..##################....",
        "...################.....",
        "....##############......",
        ".....############.......",
    ]

    private static let legs = [
        [   // 왼발 딛고 오른발 듦
            ".....####....####.......",
            ".....####....####.......",
            ".....###.....####.......",
            ".....###......###.......",
            "....#####...............",
        ],
        [   // 오른발 딛고 왼발 듦
            ".....####....####.......",
            ".....####....####.......",
            ".....####....###........",
            "......###....###........",
            "............#####.......",
        ],
    ]
}
