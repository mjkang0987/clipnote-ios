import UIKit
import UniformTypeIdentifiers

/// 공유 확장 — 다른 앱의 공유 시트에서 URL을 받는다.
/// URL을 App Group에 저장하고 확인 레이어를 띄운다. 사용자가 "앱 열기"를 누르면
/// 호스트 앱(ClipNote)을 `clipnote://share?url=`로 연다. 앱은 홈 입력칸에 URL을 채운다(방식 A).
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    /// 표시 언어. 앱에서 고른 값을 App Group 에서 읽는다 — 확장은 앱과 `standard` 도메인이
    /// 달라서, 저장 위치를 맞추지 않으면 앱만 영어이고 공유 시트는 한국어로 뜬다.
    private let i18n = LocalizationStore()

    private var deepLink: URL?

    private let card = UIView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let openButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let brand = UIColor(red: 0x7C / 255, green: 0x5C / 255, blue: 0xFC / 255, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // iOS가 확장을 감싸는 시스템 시트/컨테이너의 흰 배경 때문에 하단 레이어 뒤가 흰색으로
        // 꽉 찼음 → 상위 뷰 계층의 배경을 모두 투명화해 호스트 위에 뜬 레이어처럼 보이게 한다.
        var v: UIView? = view
        while let cur = v {
            cur.backgroundColor = .clear
            v = cur.superview
        }
    }

    // MARK: - UI

    private func buildUI() {
        // 카드 위쪽 빈 자리(backdrop)를 눌러도 닫힌다.
        //
        // 그 자리는 투명해서 호스트 화면이 비치는데, 시트에서 바깥을 눌러 닫는 건 iOS 에서
        // 몸에 밴 동작이라 아무 반응이 없으면 갇힌 것처럼 느껴진다. 카드 안쪽 탭은
        // 그대로 흘려보내야 버튼이 계속 동작한다.
        let backdrop = UITapGestureRecognizer(target: self, action: #selector(backdropTapped))
        backdrop.cancelsTouchesInView = false
        view.addGestureRecognizer(backdrop)

        // 카드를 아래로 쓸어내려도 닫힌다.
        //
        // 시트를 내려서 닫는 건 바깥 탭과 함께 iOS 에서 몸에 밴 두 가지 동작이다. 손가락을
        // 따라 움직여야 "닫히는 중" 이 보이므로 스와이프가 아니라 팬으로 받는다 —
        // 스와이프는 끝난 뒤에야 알 수 있어 잡아당기다 마음을 바꿀 수가 없다.
        card.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(cardDragged)))

        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 24
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowRadius = 16
        card.layer.shadowOffset = CGSize(width: 0, height: -2)
        view.addSubview(card)

        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.text = i18n.t("share.loadingTitle")

        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0
        bodyLabel.text = i18n.t("share.loadingBody")

        openButton.setTitle(i18n.t("share.open"), for: .normal)
        openButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        openButton.setTitleColor(.white, for: .normal)
        openButton.backgroundColor = brand
        openButton.layer.cornerRadius = 12
        openButton.isHidden = true
        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)

        closeButton.setTitle(i18n.t("share.close"), for: .normal)
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
            // 하단 카드 — 좌우·하단 화면 끝, 내용 높이만큼(위쪽은 투명해 호스트가 비침).
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            openButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func showFound() {
        titleLabel.text = i18n.t("share.foundTitle")
        // 안내문이 '앱 열기' 버튼을 가리킨다 — 라벨을 직접 적으면 버튼 이름을 바꿀 때
        // 안내만 옛 이름으로 남는다.
        bodyLabel.text = i18n.t("share.foundBody", args: i18n.t("share.open"))
        openButton.isHidden = (deepLink == nil)
    }

    private func showNotFound() {
        titleLabel.text = i18n.t("share.notFoundTitle")
        bodyLabel.text = i18n.t("share.notFoundBody")
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

    /// 카드 **바깥**을 눌렀을 때만 닫는다. 카드 안쪽이면 아무것도 하지 않는다 —
    /// 제스처가 `view` 에 붙어 있어 카드 위 빈 곳을 눌러도 여기로 들어온다.
    @objc private func backdropTapped(_ gesture: UITapGestureRecognizer) {
        guard !card.frame.contains(gesture.location(in: view)) else { return }
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// 아래로 끌어 닫기. 위로는 끌리지 않는다 — 시트가 화면 위로 뜨면 어색하다.
    @objc private func cardDragged(_ gesture: UIPanGestureRecognizer) {
        let dragged = max(0, gesture.translation(in: view).y)

        switch gesture.state {
        case .changed:
            card.transform = CGAffineTransform(translationX: 0, y: dragged)
        case .ended, .cancelled:
            // 많이 내렸거나 빠르게 튕겼으면 닫는다. 속도를 함께 보는 건 짧고 빠른 손짓도
            // 닫으려는 뜻이기 때문이다 — 거리만 보면 그 손짓이 무시된다.
            let flicked = gesture.velocity(in: view).y > 800
            guard dragged > Self.dismissDrag || flicked else {
                UIView.animate(withDuration: 0.2) { self.card.transform = .identity }
                return
            }
            UIView.animate(withDuration: 0.2) {
                self.card.transform = CGAffineTransform(translationX: 0, y: self.card.bounds.height)
            } completion: { [weak self] _ in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        default:
            break
        }
    }

    /// 이만큼 내리면 닫는다(pt). 짧게 스치는 손짓으로 닫히면 실수로 닫는 일이 생긴다.
    private static let dismissDrag: CGFloat = 80

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
