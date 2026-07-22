import UIKit
import UniformTypeIdentifiers

/// 공유 확장 — 다른 앱의 공유 시트에서 URL을 받는다.
/// URL을 App Group에 저장하고 확인 레이어를 띄운다. 사용자가 "앱 열기"를 누르면
/// 호스트 앱(ClipNote)을 `clipnote://share?url=`로 연다. 앱은 홈 입력칸에 URL을 채운다(방식 A).
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private var deepLink: URL?

    private let card = UIView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let openButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let brand = UIColor(red: 0x7C / 255, green: 0x5C / 255, blue: 0xFC / 255, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear   // 딤 없이 하단 시트만 표시
        buildUI()

        Task { [weak self] in
            guard let self else { return }
            let shared = await self.extractSharedURL()
            if let shared {
                // 확실한 전달: App Group에 저장 → 앱이 포그라운드에서 읽는다(열기 실패해도 유실 없음).
                SharedURLStore.save(shared)
                self.deepLink = Self.deepLink(for: shared)
                self.showFound()
            } else {
                self.showNotFound()
            }
        }
    }

    // MARK: - UI

    private func buildUI() {
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 24
        // 상단 모서리만 둥글게(하단 바텀시트).
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.translatesAutoresizingMaskIntoConstraints = false
        // 딤이 없으므로 그림자로 배경과 분리.
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.15
        card.layer.shadowRadius = 16
        card.layer.shadowOffset = CGSize(width: 0, height: -2)
        view.addSubview(card)

        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.text = "ClipNote로 보내는 중…"

        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.text = "잠시만요."

        openButton.setTitle("앱 열기", for: .normal)
        openButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        openButton.setTitleColor(.white, for: .normal)
        openButton.backgroundColor = brand
        openButton.layer.cornerRadius = 12
        openButton.isHidden = true
        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)

        closeButton.setTitle("닫기", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        closeButton.setTitleColor(.secondaryLabel, for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [closeButton, openButton])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 10

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, buttons])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(18, after: bodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            // 하단 바텀시트 — 좌우·하단 화면 끝에 붙이고 내용 높이만큼.
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            // 홈 인디케이터 위로 여백.
            stack.bottomAnchor.constraint(equalTo: card.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            openButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func showFound() {
        titleLabel.text = "ClipNote에 담았어요 🎉"
        bodyLabel.text = "ClipNote 앱을 열면 홈 입력칸에 링크가 자동으로 채워져 있어요. "
            + "거기서 바로 저장하거나 공유 카드를 만들 수 있어요.\n"
            + "‘앱 열기’가 안 되면 홈 화면에서 ClipNote를 직접 열어 주세요."
        openButton.isHidden = (deepLink == nil)
    }

    private func showNotFound() {
        titleLabel.text = "링크를 찾지 못했어요"
        bodyLabel.text = "공유한 항목에서 URL을 찾지 못했어요. 링크를 직접 복사해 붙여넣어 주세요."
        openButton.isHidden = true
    }

    @objc private func openTapped() {
        if let deepLink { openHostApp(deepLink) }
        // 앱이 뜰 시간을 준 뒤 확장 종료(즉시 종료하면 open이 취소될 수 있음).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    @objc private func closeTapped() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    // MARK: - URL 추출

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

    /// 확장에서 호스트 앱 열기 시도(둘 다 best-effort, iOS 버전에 따라 동작 여부 다름).
    /// 어느 것도 안 되면 App Group에 저장돼 있으므로 사용자가 앱을 직접 열면 채워진다.
    private func openHostApp(_ url: URL) {
        // 1) 확장 컨텍스트 open — iOS 버전에 따라 호스트 앱을 열어준다.
        extensionContext?.open(url, completionHandler: nil)
        // 2) responder-chain openURL: 우회(확장은 UIApplication.shared 사용 불가).
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
