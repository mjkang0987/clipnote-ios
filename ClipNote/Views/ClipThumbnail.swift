import SwiftUI

/// 클립 썸네일 — 그라디언트 배경 위에 원본 대표 이미지.
///
/// **이미지는 반드시 프록시(`/api/image?url=`)를 거친다.** 원본 URL 을 직접 불러오면 hotlink
/// 차단·referer 요구(네이버 CDN)·혼합 콘텐츠에 걸려 실패한다. 실패해도 그라디언트가 그대로
/// 보여서 **눈에는 정상처럼 보이고**, 스크롤할 때마다 실패 요청만 반복된다.
///
/// 이 뷰가 따로 있는 이유가 그거다. 전에는 홈 미리보기(`ClipCardView`)와 목록
/// (`ClipsView.ClipRow`)이 같은 그림을 따로 그리고 있었고, 프록시가 한쪽에만 적용돼 있었다.
/// 이미지 정책이 바뀔 자리를 하나로 모아 둔다.
///
/// 크기·모서리는 호출부가 정한다(`.frame` + `.clipShape`).
struct ClipThumbnail: View {
    let imageURL: String?
    let gradient: ClipGradient

    var body: some View {
        ZStack {
            LinearGradient(colors: [gradient.from, gradient.to],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let url = proxiedImageURL(imageURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        // 로딩 중·실패 모두 투명 — 뒤의 그라디언트가 그대로 보인다.
                        Color.clear
                    }
                }
            }
        }
    }
}
