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
        // `alignment: .top` 은 목록 행(`ClipRow`)과 같은 이유 — 제목이 행 높이를 정하므로
        // 가운데 정렬이면 썸네일이 카드 중간에 뜬다.
        HStack(alignment: .top, spacing: 12) {
            ClipThumbnail(imageURL: imageURL, gradient: gradient)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                // 목록 행(`ClipRow`)과 같은 규칙. 홈 미리보기가 목록보다 짧게 자르면
                // 저장한 뒤 다른 걸 보게 된다 — 그건 미리보기가 아니다.
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.fg)
                    .fixedSize(horizontal: false, vertical: true)
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
