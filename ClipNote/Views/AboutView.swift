import SwiftUI

/// 소개 화면 — ClipNote 설명·동작·로그인 유무 안내. RN `app/about.tsx` 이식.
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BrandLogo(size: 24)
                    .padding(.bottom, 16)

                sectionTitle("ClipNote란?")
                paragraph("ClipNote(클립노트)는 밋밋하고 긴 링크를 클릭하고 싶어지는 공유 카드로 바꿔 주는 무료 서비스예요. 링크만 붙여넣으면 페이지의 제목·설명·대표 이미지를 자동으로 읽어와 카드 미리보기를 만들고, 카카오톡이나 SNS에 올렸을 때 한눈에 들어오는 이미지와 짧은 링크를 만들어 드려요. 네이버 카페 게시글, 인스타그램 릴처럼 미리보기가 잘 안 잡히는 링크도 문제없어요.")

                sectionTitle("이렇게 동작해요").padding(.top, 24)
                step("1. 공유할 URL을 붙여넣어요. 붙여넣기만 하면 끝이에요.")
                step("2. 제목·설명·대표 이미지를 자동으로 읽어와 카드를 완성해요.")
                step("3. 로그인하면 짧은 공유 링크까지 — 어디에 올려도 예쁜 카드로 떠요.")

                infoBox(title: "로그인 하면", titleColor: AppColor.brandStrong,
                        background: AppColor.brandSoft, border: AppColor.brand.opacity(0.35),
                        items: [
                            "· 짧은 공유 링크로 카카오톡·SNS에 바로 보낼 수 있어요.",
                            "· 공유한 링크가 제목·이미지가 담긴 미리보기 카드로 떠요.",
                            "· 클립이 계정에 쌓여 어느 기기에서나 그대로 보이고, 태그로 깔끔하게 정리돼요.",
                        ])
                    .padding(.top, 16)

                infoBox(title: "로그인 안 해도", titleColor: AppColor.fg,
                        background: AppColor.surface, border: AppColor.border,
                        items: [
                            "· URL을 붙여넣어 미리보기 카드를 바로 만들 수 있어요.",
                            "· 만든 클립을 이 기기에 저장하고 '내 클립'에서 다시 봐요.",
                            "· 단, 저장은 이 기기에만 남고 짧은 공유 링크는 못 만들어요.",
                        ])
                    .padding(.top, 12)
            }
            .padding(20)
        }
        .background(AppColor.bg)
        .navigationTitle("소개")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 18, weight: .bold)).foregroundStyle(AppColor.fg)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).lineSpacing(4)
            .foregroundStyle(AppColor.fgMuted).padding(.top, 10)
    }

    private func step(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).lineSpacing(3)
            .foregroundStyle(AppColor.fgMuted).padding(.top, 6)
    }

    private func infoBox(title: String, titleColor: Color, background: Color,
                         border: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(titleColor)
            ForEach(items, id: \.self) { item in
                Text(item).font(.system(size: 14)).lineSpacing(3).foregroundStyle(AppColor.fgMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(border, lineWidth: 0.5))
    }
}
