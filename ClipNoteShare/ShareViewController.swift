import UIKit
import UniformTypeIdentifiers

/// 공유 확장 — 다른 앱의 공유 시트에서 URL을 받아 호스트 앱(ClipNote)을 `clipnote://share?url=`로 연다.
/// 클립 저장은 하지 않는다(방식 A). 앱이 홈 입력칸에 URL을 채우고, 저장·공유는 사용자가 선택.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { [weak self] in
            let shared = await self?.extractSharedURL()
            if let shared, let deepLink = Self.deepLink(for: shared) {
                self?.openHostApp(deepLink)
            }
            // 즉시 completeRequest를 부르면 시스템이 앱을 열기 전에 확장이 종료돼
            // open이 취소될 수 있다 → 짧게 대기한 뒤 확장을 닫는다.
            try? await Task.sleep(nanoseconds: 300_000_000)
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    /// 입력 항목에서 첫 URL을 추출(웹 URL 우선, 없으면 텍스트에 담긴 URL).
    private func extractSharedURL() async -> String? {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .flatMap { $0.attachments ?? [] } ?? []

        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(urlType) }),
           let item = try? await p.loadItem(forTypeIdentifier: urlType) {
            return (item as? URL)?.absoluteString ?? (item as? String)
        }
        if let p = providers.first(where: { $0.hasItemConformingToTypeIdentifier(textType) }),
           let item = try? await p.loadItem(forTypeIdentifier: textType) {
            let s = (item as? String) ?? (item as? URL)?.absoluteString
            return Self.firstURL(in: s)
        }
        return nil
    }

    /// 텍스트에서 첫 http(s) URL만 골라낸다(공유 텍스트에 설명이 섞여 오는 경우 대비).
    private static func firstURL(in text: String?) -> String? {
        guard let text else { return nil }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector?.firstMatch(in: text, range: range), let url = match.url {
            return url.absoluteString
        }
        return text.hasPrefix("http") ? text : nil
    }

    /// `clipnote://share?url=<인코딩>` 딥링크 조립.
    private static func deepLink(for original: String) -> URL? {
        var comps = URLComponents()
        comps.scheme = "clipnote"
        comps.host = "share"
        comps.queryItems = [URLQueryItem(name: "url", value: original)]
        return comps.url
    }

    /// 확장에서 호스트 앱을 여는 responder-chain 우회(확장은 UIApplication.shared 사용 불가).
    private func openHostApp(_ url: URL) {
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let r = responder {
            if r.responds(to: selector) {
                r.perform(selector, with: url)
                return
            }
            responder = r.next
        }
    }
}
