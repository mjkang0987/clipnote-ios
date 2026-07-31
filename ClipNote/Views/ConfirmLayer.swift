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
    let title: String
    let message: Text
    /// 확인 버튼 라벨.
    let confirmLabel: String
    /// 되돌릴 수 없는 동작인가. 확인 버튼을 위험 색으로 그린다.
    var destructive: Bool = false
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
                Button(cancelLabel, action: onCancel)
                    .buttonStyle(ModalGhostButton())
                    .disabled(busy)
                Button(action: onConfirm) {
                    SpinnerLabel(title: busy ? (busyLabel ?? confirmLabel) : confirmLabel,
                                 loading: busy,
                                 tint: AppColor.white)
                }
                .buttonStyle(ModalConfirmButton(destructive: destructive))
                .disabled(busy)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heightReader)
        .presentationDetents([.height(contentHeight)])
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

/// 확인 버튼 — 보통은 브랜드색, 되돌릴 수 없는 동작이면 위험색.
struct ModalConfirmButton: ButtonStyle {
    let destructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let base = destructive ? AppColor.danger : AppColor.brand
        return configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppColor.white)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(configuration.isPressed ? base.opacity(0.85) : base)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
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
