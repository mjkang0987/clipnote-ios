import UIKit
import UniformTypeIdentifiers

/// 공유 확장 — 다른 앱의 공유 시트에서 URL을 받는다.
///
/// URL 을 App Group 에 저장하고 "담았어요" 를 알린 뒤 사라진다. 앱은 다음에 켜질 때 그 값을
/// 읽어 홈 입력칸을 채운다.
///
/// **여기서 앱을 열지 않는다.** `NSExtensionContext.open(_:)` 은 문서상 Today 위젯용이고,
/// responder chain 으로 `openURL:` 을 찾는 우회도 최근 iOS 에서 막혔다 — 실제로 시도했고
/// 둘 다 실패했다. 공유 시트에서 앱이 바로 열리는 사례는 대개 **보내는 쪽 앱**이 스킴으로
/// 여는 것이거나(확장이 아니라 일반 앱이라 제한이 없다) 파일을 넘겨 `LSItemContentTypes`
/// 경로로 여는 것이라, URL 을 받는 확장이 따라 할 수 있는 길이 아니다.
///
/// 그래서 **항상 실패하는 버튼을 두지 않는다.** 눌러도 안 되는 버튼은 없느니만 못하다.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    /// 표시 언어. 앱에서 고른 값을 App Group 에서 읽는다 — 확장은 앱과 `standard` 도메인이
    /// 달라서, 저장 위치를 맞추지 않으면 앱만 영어이고 공유 시트는 한국어로 뜬다.
    private let i18n = LocalizationStore()

    /// 카드 뒤를 덮는 **실제 뷰**.
    ///
    /// 처음에는 root view 에 탭 제스처만 붙였는데 안 먹었다. 확장은 시스템이 감싸는 컨테이너
    /// 안에서 도는 환경이라 root view 의 제스처가 터치를 받는다는 보장이 없다. 뷰를 하나
    /// 깔고 거기에 붙이면 그 자리는 확실히 이쪽이 받는다.
    private let backdrop = UIView()
    private let card = UIView()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
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
                // App Group 에 저장 → 앱이 다음에 켜질 때 읽어 입력칸을 채운다.
                SharedURLStore.save(shared)
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
        // 바깥을 눌러 닫는다. 시트에서 몸에 밴 동작이라 반응이 없으면 갇힌 것처럼 느껴진다.
        //
        // 제스처를 backdrop **에** 붙인다. 카드는 이 위에 얹히므로 카드 안쪽 탭은 여기까지
        // 내려오지 않는다 — 좌표를 비교해 걸러낼 필요가 없다.
        //
        // **색을 채워 둔다.** 문서상 히트 테스트는 배경색을 보지 않지만, 색을 빼자 바깥 탭이
        // 다시 먹지 않았다 — 확장이 시스템 컨테이너 안에서 도는 환경이라 문서대로만 굴러가지
        // 않는다. 되는 쪽을 택한다. 옅게 하고 싶으면 이 값만 낮추고 **반드시 눌러서 확인**할 것.
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(backdropTapped)))
        view.addSubview(backdrop)

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

        closeButton.setTitle(i18n.t("share.close"), for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        closeButton.setTitleColor(.secondaryLabel, for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, closeButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(18, after: bodyLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // 하단 카드 — 좌우·하단 화면 끝, 내용 높이만큼.
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    private func showFound() {
        titleLabel.text = i18n.t("share.foundTitle")
        bodyLabel.text = i18n.t("share.foundBody")
    }

    private func showNotFound() {
        titleLabel.text = i18n.t("share.notFoundTitle")
        bodyLabel.text = i18n.t("share.notFoundBody")
    }

    @objc private func closeTapped() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// 카드 뒤를 눌렀을 때. 카드는 이 위에 얹혀 있어 여기로 오지 않는다.
    @objc private func backdropTapped() {
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
}
