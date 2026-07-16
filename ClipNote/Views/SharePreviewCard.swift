import SwiftUI

/// 공유 카드 미리보기 — 서버 `/api/og`가 만드는 OG 이미지를 네이티브로 재현.
/// 비율 1200:630, 폰트/여백은 카드 너비 비례(RN cqw 대응). 색은 `pickGradient` 동일.
struct SharePreviewCard: View {
    let title: String
    let description: String?
    let siteName: String?
    let gradient: ClipGradient

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let pad = w * 0.06
            let fsSite = w * 0.026
            let fsTitle = title.count > 40 ? w * 0.05 : w * 0.06
            let fsDesc = w * 0.028
            let fsMark = w * 0.026

            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [gradient.from, gradient.to],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                // 하단 스크림(가독성)
                LinearGradient(colors: [.clear, .black.opacity(0.28)],
                               startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: w * 0.012) {
                    if let s = siteName, !s.isEmpty {
                        Text(s.uppercased())
                            .font(.system(size: fsSite, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                    }
                    Text(title)
                        .font(.system(size: fsTitle, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                    if let d = description, !d.isEmpty {
                        Text(d)
                            .font(.system(size: fsDesc))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                    Text("ClipNote")
                        .font(.system(size: fsMark, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.top, w * 0.008)
                }
                .padding(pad)
            }
        }
        .aspectRatio(1200.0 / 630.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}

#Preview {
    SharePreviewCard(
        title: "붙여넣으면 끝, 예쁜 공유 카드",
        description: "링크만 넣으면 미리보기 카드와 짧은 공유 링크가 한 번에.",
        siteName: "clipnote.co.kr",
        gradient: pickGradient("clipnote")
    )
    .padding()
}
