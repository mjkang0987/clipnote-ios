import SwiftUI

/// 태그 필터 칩. 활성 시 brandSoft/brandStrong.
struct FilterChip: View {
    let label: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? AppColor.brandStrong : AppColor.fgMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(active ? AppColor.brandSoft : AppColor.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(active ? AppColor.brand : AppColor.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
