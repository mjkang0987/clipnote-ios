import SwiftUI

/// 브랜드 로고 — 아이콘 + "ClipNote" 워드마크. RN `BrandLogo` 이식(아이콘은 SF Symbol로 대체).
struct BrandLogo: View {
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: size + 2))
                .foregroundStyle(AppColor.brand)
            HStack(spacing: 0) {
                Text("Clip").foregroundStyle(AppColor.fg)
                Text("Note").foregroundStyle(AppColor.brand)
            }
            .font(.system(size: size, weight: .bold))
        }
    }
}
