import SwiftUI

/// 버튼/라벨용 인라인 로딩 표시 — 로딩 중이면 텍스트 앞에 작은 스피너.
/// 진행 중 상태를 텍스트 변경만으로 알기 어려운 문제 보완(§로딩 인디케이터).
struct SpinnerLabel: View {
    let title: String
    let loading: Bool
    var tint: Color = AppColor.white

    var body: some View {
        HStack(spacing: 8) {
            if loading {
                ProgressView()
                    .controlSize(.small)
                    .tint(tint)
            }
            Text(title)
        }
    }
}
