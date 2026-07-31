import SwiftUI

/// 소개 화면 — ClipNote 설명·동작·로그인 유무 안내. 웹 홈 하단 소개 섹션과 같은 문구를 쓴다.
///
/// 사용법 문단은 실제 버튼 이름(`homeActions.*`)을 끼워 넣는다. 문장에 버튼 이름을 직접 적으면
/// 버튼 라벨이 바뀔 때 안내만 옛 이름으로 남는다 — 웹도 같은 이유로 자리표시자를 쓴다.
struct AboutView: View {
    @Environment(LocalizationStore.self) private var i18n

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                BrandLogo(size: 24)
                    .padding(.bottom, 16)

                sectionTitle("ClipNote\(i18n.t("about.titleSuffix"))")
                paragraph(i18n.t("about.body1"))
                paragraph(i18n.t("about.body2"))
                paragraph(i18n.t("about.body3"))

                sectionTitle(i18n.t("about.howTitle")).padding(.top, 24)
                // 번호는 목록 표시라 사전에 넣지 않는다(번역 대상이 아니다).
                step(1, i18n.t("about.how1"))
                step(2, i18n.t("about.how2",
                               args: i18n.t("homeActions.createLink"), i18n.t("homeActions.copyLink")))
                step(3, i18n.t("about.how3", args: i18n.t("homeActions.copyOriginal")))
                step(4, i18n.t("about.how4",
                               args: i18n.t("homeActions.saveToClips"), i18n.t("homeActions.saveHere")))

                // 로그인/게스트 비교는 로그인 화면과 같은 한 벌(`compare.*`)을 쓴다 —
                // 전에는 두 화면에 따로 적혀 있어 같은 뜻이 조금씩 다르게 갈렸다.
                infoBox(title: i18n.t("compare.signedInTitle"), titleColor: AppColor.brandStrong,
                        background: AppColor.brandSoft, border: AppColor.brand.opacity(0.35),
                        items: [
                            i18n.t("compare.signedInItem1", args: i18n.t("compare.signedInItem1Emphasis")),
                            i18n.t("compare.signedInItem2"),
                            i18n.t("compare.signedInItem3", args: i18n.t("compare.signedInItem3Emphasis")),
                        ])
                    .padding(.top, 16)

                infoBox(title: i18n.t("compare.guestTitle"), titleColor: AppColor.fg,
                        background: AppColor.surface, border: AppColor.border,
                        items: [
                            i18n.t("compare.guestItem1"),
                            i18n.t("compare.guestItem2", args: i18n.t("common.myClips")),
                            i18n.t("compare.guestItem3",
                                   args: i18n.t("compare.guestItem3Device"),
                                   i18n.t("compare.guestItem3NoLink")),
                        ])
                    .padding(.top, 12)
            }
            .padding(20)
        }
        .background(AppColor.bg)
        .navigationTitle(i18n.t("menu.about"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 18, weight: .bold)).foregroundStyle(AppColor.fg)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).lineSpacing(4)
            .foregroundStyle(AppColor.fgMuted).padding(.top, 10)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        Text("\(number). \(text)").font(.system(size: 14)).lineSpacing(3)
            .foregroundStyle(AppColor.fgMuted).padding(.top, 6)
    }

    private func infoBox(title: String, titleColor: Color, background: Color,
                         border: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(titleColor)
            ForEach(items, id: \.self) { item in
                Text("· \(item)").font(.system(size: 14)).lineSpacing(3).foregroundStyle(AppColor.fgMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(border, lineWidth: 0.5))
    }
}
