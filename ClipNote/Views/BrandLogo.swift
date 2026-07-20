import SwiftUI

/// 브랜드 로고 — 아이콘 + "ClipNote" 워드마크. RN `BrandLogo` 이식(아이콘은 SF Symbol로 대체).
struct BrandLogo: View {
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 6) {
            Image("BrandIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size + 4, height: size + 4)
                .clipShape(RoundedRectangle(cornerRadius: (size + 4) * 0.22))
            HStack(spacing: 0) {
                Text("Clip").foregroundStyle(AppColor.fg)
                Text("Note").foregroundStyle(AppColor.brand)
            }
            .font(.system(size: size, weight: .bold))
        }
    }
}
