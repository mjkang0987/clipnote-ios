import SwiftUI

/// 온보딩 슬라이드(4장) — 기능 설명. RN `app/onboarding.tsx` 이식.
/// 완료 시 `onDone`(호출부가 onboardingSeen 저장).
struct OnboardingView: View {
    let onDone: () -> Void

    private struct Slide: Identifiable {
        let key: String
        let emoji: String
        let title: String
        let body: [String]
        let steps: [(Int, String)]
        var id: String { key }
    }

    private let slides: [Slide] = [
        Slide(key: "welcome", emoji: "🔗", title: "링크만 붙여넣으면\n예쁜 공유 카드",
              body: ["ClipNote가 밋밋한 링크를 클릭하고 싶은 카드로 바꿔 줘요."], steps: []),
        Slide(key: "how", emoji: "✨", title: "이렇게 동작해요", body: [],
              steps: [(1, "공유할 URL을 붙여넣어요."),
                      (2, "제목·설명·이미지를 자동으로 읽어 카드를 완성해요."),
                      (3, "로그인하면 짧은 공유 링크까지 만들어져요.")]),
        Slide(key: "more", emoji: "📚", title: "이런 것도 돼요",
              body: ["인스타·네이버 카페처럼 미리보기가 안 잡히는 링크도 알아서 정리해요.",
                     "로그인만 하면 어느 기기·브라우저에서든 내 북마크를 볼 수 있어요."], steps: []),
        Slide(key: "share", emoji: "🚀", title: "공유는 클릭 한 번",
              body: ["공유용 페이지를 자동으로 만들어 줘요.",
                     "굳이 설명을 안 써도 받는 사람이 한눈에 알아봐요."], steps: []),
    ]

    @State private var index = 0

    private var isLast: Bool { index == slides.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if !isLast {
                    Button("건너뛰기") { onDone() }
                        .font(.system(size: 14))
                        .foregroundStyle(AppColor.fgMuted)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 16)

            TabView(selection: $index) {
                ForEach(Array(slides.enumerated()), id: \.element.id) { i, slide in
                    slideView(slide).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if isLast { onDone() }
                else { withAnimation { index += 1 } }
            } label: {
                Text(isLast ? "시작하기" : "다음")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(AppColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .padding(24)
        }
        .background(AppColor.bg)
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(slide.emoji).font(.system(size: 64))
            Text(slide.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppColor.fg)
                .multilineTextAlignment(.center)

            if !slide.steps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(slide.steps, id: \.0) { n, text in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(n)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppColor.white)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(AppColor.brand))
                            Text(text)
                                .font(.system(size: 15)).lineSpacing(3)
                                .foregroundStyle(AppColor.fgMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(slide.body, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 15)).lineSpacing(4)
                            .foregroundStyle(AppColor.fgMuted)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
