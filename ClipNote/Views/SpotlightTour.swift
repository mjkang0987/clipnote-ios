import SwiftUI

/// 온보딩 스포트라이트 투어 — 실제 화면 위에 dim + 구멍(cutout)으로 한 영역씩 강조하고
/// 말풍선으로 "이 영역=이 기능 / 대상 / 플로우"를 설명. 슬라이드 이미지 대체(§온보딩 개편).

/// 강조 대상 영역 식별자. 실제 UI 요소에 `.tourAnchor(_:)`로 부착한다.
enum TourAnchor: String, CaseIterable {
    case url, options, save, share, myClips, menu
}

/// 각 영역의 프레임을 named coordinate space "tour"에서 수집.
struct TourAnchorKey: PreferenceKey {
    static let defaultValue: [TourAnchor: CGRect] = [:]
    static func reduce(value: inout [TourAnchor: CGRect], nextValue: () -> [TourAnchor: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// 이 뷰의 프레임을 투어 앵커로 발행. 투어 미표시 시 무해(소비자 없으면 무시됨).
    func tourAnchor(_ anchor: TourAnchor) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: TourAnchorKey.self,
                    value: [anchor: geo.frame(in: .named("tour"))]
                )
            }
        )
    }

    /// destinationOut 블렌드로 지정 영역을 뚫는 역마스크.
    fileprivate func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(mask().blendMode(.destinationOut))
        }
    }
}

/// 투어 한 단계.
struct TourStep {
    let anchor: TourAnchor
    let title: String
    let desc: String
    /// 사용 대상 배지(예: "누구나", "로그인 필요"). nil이면 배지 없음.
    let audience: String?
    let loginOnly: Bool
}

/// dim + 구멍 + 말풍선 오버레이. 실제 화면 위에 얹는다.
struct SpotlightOverlay: View {
    let steps: [TourStep]
    let anchors: [TourAnchor: CGRect]
    @Binding var index: Int
    let onDone: () -> Void

    private var step: TourStep { steps[index] }
    private var isLast: Bool { index == steps.count - 1 }
    private var rect: CGRect? {
        guard let r = anchors[step.anchor], r != .zero, r.width > 0 else { return nil }
        return r.insetBy(dx: -8, dy: -8)
    }

    var body: some View {
        GeometryReader { geo in
            let calloutAtTop = (rect?.midY ?? .infinity) > geo.size.height * 0.5

            ZStack {
                Color.black.opacity(0.62)
                    .reverseMask {
                        if let r = rect {
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .frame(width: r.width, height: r.height)
                                .position(x: r.midX, y: r.midY)
                        }
                    }
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { advance() }   // 아무 곳이나 탭 → 다음

                if let r = rect {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .stroke(AppColor.brand, lineWidth: 2)
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                        .allowsHitTesting(false)
                }

                VStack {
                    if !calloutAtTop { Spacer() }
                    callout
                    if calloutAtTop { Spacer() }
                }
                .padding(16)
            }
        }
    }

    private var callout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("\(index + 1) / \(steps.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColor.brand)
                if let audience = step.audience {
                    Text(audience)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(step.loginOnly ? AppColor.white : AppColor.brandStrong)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(step.loginOnly ? AppColor.brand : AppColor.brandSoft)
                        .clipShape(Capsule())
                }
                Spacer()
                Button("건너뛰기") { onDone() }
                    .font(.system(size: 13))
                    .foregroundStyle(AppColor.fgMuted)
            }

            Text(step.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColor.fg)
            Text(step.desc)
                .font(.system(size: 14)).lineSpacing(3)
                .foregroundStyle(AppColor.fgMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if index > 0 {
                    Button { withAnimation { index -= 1 } } label: {
                        Text("이전")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.brandStrong)
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .background(AppColor.brandSoft)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                    }
                }
                Button { advance() } label: {
                    Text(isLast ? "시작하기" : "다음")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.white)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(AppColor.brand)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(AppColor.border, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }

    private func advance() {
        if isLast { onDone() }
        else { withAnimation { index += 1 } }
    }
}
