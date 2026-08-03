import SwiftUI

/// 자주 묻는 질문. 웹 홈 하단 FAQ 와 **같은 6문항·같은 문구**를 쓴다.
///
/// 답변에 버튼 이름이 나오는 문항은 실제 라벨(`homeActions.*`)을 끼워 넣는다. 문장에 직접
/// 적으면 버튼 이름이 바뀔 때 FAQ 만 옛 이름으로 남아 사용자가 화면에서 못 찾는다.
struct FaqView: View {
    @Environment(LocalizationStore.self) private var i18n

    private struct QA: Identifiable {
        let q: String
        let a: String
        var id: String { q }
    }

    private var items: [QA] {
        let copyLink = i18n.t("homeActions.copyLink")
        let copyOriginal = i18n.t("homeActions.copyOriginal")
        return [
            QA(q: i18n.t("faq.q1", args: copyLink, copyOriginal),
               a: i18n.t("faq.a1", args: copyLink, copyOriginal)),
            QA(q: i18n.t("faq.q2"), a: i18n.t("faq.a2", args: i18n.t("common.myClips"))),
            QA(q: i18n.t("faq.q3"), a: i18n.t("faq.a3")),
            QA(q: i18n.t("faq.q4"), a: i18n.t("faq.a4")),
            QA(q: i18n.t("faq.q5"), a: i18n.t("faq.a5")),
            QA(q: i18n.t("faq.q6"), a: i18n.t("faq.a6")),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.q)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColor.fg)
                        Text(item.a)
                            .font(.system(size: 14)).lineSpacing(4)
                            .foregroundStyle(AppColor.fgMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(AppColor.bg)
        .navigationTitle(i18n.t("faq.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
