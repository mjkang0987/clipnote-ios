import SwiftUI

/// 확인 레이어 — 제목·본문·버튼 두 개. 웹 `ClipsClient.ModalShell` 에 대응한다.
///
/// **왜 `confirmationDialog`(액션 시트)를 쓰지 않나**
///
/// 웹은 네이티브 `confirm()` 을 걷어내고 레이어로 바꿨다(`c6c1d54` 이후). 앱도 맞춘다.
/// 모양 때문만이 아니라 **동작 때문이다** — `confirmationDialog` 는 바깥을 눌러 닫은 것과
/// 취소 버튼을 누른 것을 구분할 수 없다. 옮기기 흐름은 그 둘이 달라야 한다(닫기=보류,
/// 취소=옮기지 않겠다는 의사 표시 → 삭제 확인). 버튼을 직접 그리면 구분이 선다.
///
/// **높이를 재서 detent 로 쓴다.** 고정 높이(`.height(320)`)로 두면 번역문이 한국어보다 긴
/// 언어에서 잘린다(영어가 특히 길다). 내용 높이를 재어 그만큼만 띄운다.
struct ConfirmLayer: View {
    /// 두 버튼 중 어느 쪽을 시각적으로 무겁게 둘지. 웹이 레이어마다 다르게 준 강조를 그대로 옮긴다.
    enum Emphasis {
        /// 확인이 기본 동작 — 확인을 브랜드색으로 채운다(옮기기).
        case normal
        /// 되돌릴 수 없다 — 확인을 위험색으로 채운다(클립 삭제).
        case destructive
        /// 되돌릴 수 없고 **서버 사본도 없다** — 취소를 채워 기본 동작으로 만들고,
        /// 확인은 테두리만 남긴다. 손이 미끄러져 눌리는 쪽이 안전해야 한다(로컬 클립 삭제).
        case cautious
    }

    let title: String
    let message: Text
    /// 확인 버튼 라벨.
    let confirmLabel: String
    var emphasis: Emphasis = .normal
    /// 진행 중이면 버튼을 잠그고 스피너를 보여 준다.
    var busy: Bool = false
    var busyLabel: String?
    let cancelLabel: String
    let onConfirm: () -> Void
    /// **취소 버튼**을 누른 경우. 스와이프로 닫은 것과 구분된다 —
    /// 후자는 호출부의 `.sheet(onDismiss:)` 가 받는다.
    let onCancel: () -> Void

    @State private var contentHeight: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColor.fg)
            message
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(AppColor.fgMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                cancelButton
                confirmButton
            }
            .padding(.top, 12)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heightReader)
        .presentationDetents([.height(contentHeight)])
    }

    @ViewBuilder
    private var cancelButton: some View {
        let button = Button(cancelLabel, action: onCancel).disabled(busy)
        // 가장 위험한 경우에만 취소를 채운다 — 나머지는 확인 쪽이 기본 동작이다.
        if emphasis == .cautious {
            button.buttonStyle(ModalFilledButton(color: AppColor.brand))
        } else {
            button.buttonStyle(ModalGhostButton())
        }
    }

    @ViewBuilder
    private var confirmButton: some View {
        let label = SpinnerLabel(
            title: busy ? (busyLabel ?? confirmLabel) : confirmLabel,
            loading: busy,
            tint: emphasis == .cautious ? AppColor.danger : AppColor.white
        )
        switch emphasis {
        case .normal:
            Button(action: onConfirm) { label }
                .buttonStyle(ModalFilledButton(color: AppColor.brand)).disabled(busy)
        case .destructive:
            Button(action: onConfirm) { label }
                .buttonStyle(ModalFilledButton(color: AppColor.danger)).disabled(busy)
        case .cautious:
            Button(action: onConfirm) { label }
                .buttonStyle(ModalOutlinedDangerButton()).disabled(busy)
        }
    }

    /// 내용 높이를 재서 detent 에 넘긴다. 시트 폭은 detent 와 무관하게 고정이라
    /// 줄바꿈이 다시 바뀌지 않고 한 번에 수렴한다.
    private var heightReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { contentHeight = proxy.size.height }
                .onChange(of: proxy.size.height) { _, height in contentHeight = height }
        }
    }
}

/// 레이어에 개수를 **값으로 실어 보내기 위한 래퍼.**
///
/// `.sheet(isPresented:)` 의 콘텐츠 클로저는 표시 시점이 아니라 **직전 `body` 평가 시점의 상태**를
/// 잡을 수 있다. 개수와 표시 여부를 같은 틱에 세팅하면 아직 갱신 전인 값으로 그려진다
/// (실제로 옮기기 레이어가 "0개 옮기기" 로 떴다). `.sheet(item:)` 은 그릴 값을 함께 넘기므로
/// 이 어긋남이 구조적으로 생기지 않는다.
struct ClipCount: Identifiable {
    let value: Int
    var id: Int { value }
}

/// 채운 버튼 — 색만 갈아 끼운다(브랜드 / 위험).
struct ModalFilledButton: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColor.white)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(configuration.isPressed ? color.opacity(0.85) : color)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }
}

/// 테두리만 있는 위험 버튼 — 취소가 기본 동작인 레이어에서 확인 쪽에 쓴다.
struct ModalOutlinedDangerButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColor.danger)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(configuration.isPressed ? AppColor.danger.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(AppColor.danger, lineWidth: 1))
    }
}

/// 문장 안의 낱말만 강조한 `Text`.
///
/// 사전에는 `%@` 가 든 온전한 문장 하나만 두고(앞/뒤로 쪼개면 어순이 다른 언어에서 깨진다),
/// 화면에서 끼워 넣은 낱말을 기준으로 그 조각만 굵게 그린다 — 웹 `interpolateNode` 와 같은 방식.
///
/// 낱말이 문장에 없으면(번역이 자리표시자를 빠뜨렸다면) 그냥 강조 없이 그린다.
/// 화면이 깨지는 것보다 낫고, 그런 누락은 `scripts/check-localizations.py` 가 잡는다.
func emphasized(_ sentence: String, _ words: [String]) -> Text {
    var attributed = AttributedString(sentence)
    for word in words where !word.isEmpty {
        guard let range = attributed.range(of: word) else { continue }
        // 굵기만 준다 — 크기는 `Text` 에 걸린 폰트를 그대로 물려받아야 본문과 어긋나지 않는다.
        attributed[range].inlinePresentationIntent = .stronglyEmphasized
        attributed[range].foregroundColor = AppColor.fg
    }
    return Text(attributed)
}
