import SwiftUI

/// 태그 칩. brandSoft 배경 + brandStrong 텍스트.
struct TagChip: View {
    let text: String
    var small = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppColor.brandStrong)
            .padding(.horizontal, small ? 8 : 10)
            .padding(.vertical, small ? 2 : 4)
            .background(AppColor.brandSoft)
            .clipShape(Capsule())
    }
}

/// 클립 카드 미리보기 — 목록에서 보일 모습. 썸네일(원본 image or 그라디언트) + 제목·호스트·태그.
struct ClipCardView: View {
    let title: String
    let host: String?
    let imageURL: String?
    let gradient: ClipGradient
    let tags: [String]

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.fg)
                    .lineLimit(1)
                if let h = host, !h.isEmpty {
                    Text(h)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.fgMuted)
                        .lineLimit(1)
                }
                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags, id: \.self) { TagChip(text: $0, small: true) }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(AppColor.border, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            LinearGradient(colors: [gradient.from, gradient.to],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let s = imageURL, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ClipCardView(title: "예쁜 공유 카드 만들기", host: "clipnote.co.kr",
                     imageURL: nil, gradient: pickGradient("clipnote"),
                     tags: ["개발", "디자인"])
        ClipCardView(title: "이미지 없는 클립", host: "example.com",
                     imageURL: nil, gradient: pickGradient("example"), tags: [])
    }
    .padding()
}
