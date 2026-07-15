import SwiftUI
import SafariServices

/// SFSafariViewController 래퍼. 네이버 커스텀 OAuth에 사용(#8).
/// ASWebAuthenticationSession은 커스텀 스킴 복귀를 삼켜서 네이버 콜백에 부적합 →
/// SFSafari는 콜백이 `clipnote://`로 이동하면 앱을 실제로 열어준다(복귀는 `.onOpenURL`).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
