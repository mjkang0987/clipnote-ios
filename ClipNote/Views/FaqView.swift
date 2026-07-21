import SwiftUI

/// 자주 묻는 질문. RN `app/faq.tsx` 이식.
struct FaqView: View {
    private struct QA: Identifiable {
        let q: String
        let a: String
        var id: String { q }
    }

    private let items: [QA] = [
        QA(q: "태그는 어떻게 쓰나요?",
           a: "태그 칸에 쉼표(,)로 최대 6개까지 달 수 있어요. '내 클립'에서 같은 태그끼리 모아 볼 수 있어요."),
        QA(q: "로그인 없이도 쓸 수 있나요?",
           a: "네. 비로그인 상태에서도 URL을 이 기기에 저장할 수 있어요. 다만 공유 링크 생성은 로그인(Google·Kakao)이 필요합니다."),
        QA(q: "네이버 카페·인스타그램 링크도 되나요?",
           a: "네. 전용 추출 기능으로 네이버 카페 게시글 제목, 인스타그램 릴·게시물 정보까지 가져와요. (비공개·멤버 전용 글은 제한될 수 있어요.)"),
        QA(q: "공유 링크를 열면 어떻게 되나요?",
           a: "클릭하면 예쁜 미리보기 카드가 잠깐 보였다가, 원본 페이지로 자연스럽게 넘어가요."),
        QA(q: "무료인가요?", a: "네, 무료로 사용할 수 있어요."),
    ]

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
        .navigationTitle("자주 묻는 질문")
        .navigationBarTitleDisplayMode(.inline)
    }
}
