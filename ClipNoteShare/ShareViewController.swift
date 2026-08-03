import UIKit
import UniformTypeIdentifiers
import os

/// 공유 확장 — 다른 앱의 공유 시트에서 URL을 받는다.
/// URL을 App Group에 저장하고 확인 레이어를 띄운다. 사용자가 "앱 열기"를 누르면
/// 호스트 앱(ClipNote)을 `clipnote://share?url=`로 연다. 앱은 홈 입력칸에 URL을 채운다(방식 A).
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    /// 표시 언어. 앱에서 고른 값을 App Group 에서 읽는다 — 확장은 앱과 `standard` 도메인이
    /// 달라서, 저장 위치를 맞추지 않으면 앱만 영어이고 공유 시트는 한국어로 뜬다.
    private let i18n = LocalizationStore()

    private var deepLink: URL?

    /// 카드 뒤를 덮는 **실제 뷰**.
    ///
    /// 처음에는 투명한 root view 에 탭 제스처만 붙였는데 시뮬레이터에서 안 먹었다. 공유
    /// 확장은 시스템이 감싸는 컨테이너 안에서 도는 특수한 환경이라, 아무것도 그리지 않은
    /// 자리의 터치가 확장까지 온다는 보장이 없다. 실제 뷰를 깔면 그 자리는 확실히 이쪽이
    /// 받는다.
    ///
    /// 살짝 어둡게 깐 건 진단이자 디자인이다 — 어두워지지 않으면 이 뷰가 화면을 덮지
    /// 못한다는 뜻이고, 어두워지면 "바깥을 눌러 닫는 레이어" 라는 신호가 된다.
    private let backdrop = UIView()
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
        // 바깥을 눌러 닫는다. 시트에서 몸에 밴 동작이라 반응이 없으면 갇힌 것처럼 느껴진다.
        //
        // 제스처를 backdrop **에** 붙인다. 카드는 이 위에 얹히므로 카드 안쪽 탭은 여기까지
        // 내려오지 않는다 — 좌표를 비교해 걸러낼 필요가 없다.
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.35)
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
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            // 하단 카드 — 좌우·하단 화면 끝, 내용 높이만큼(위쪽은 backdrop 이 덮는다).
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
        guard let deepLink else { return }
        openHostApp(deepLink)
    }

    @objc private func closeTapped() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// 카드 뒤 어두운 자리를 눌렀을 때. 카드는 이 위에 얹혀 있어 여기로 오지 않는다.
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
    /// 호스트 앱 열기.
    ///
    /// **애플이 보장하는 길이 없다.** `NSExtensionContext.open(_:)` 은 문서상 Today 위젯용이고,
    /// 공유 확장에서 되는지는 iOS 판에 달렸다. 남은 건 responder chain 을 뒤져 `openURL:` 을
    /// 찾는 우회인데 이것도 최근 판에서는 잘 끊긴다.
    ///
    /// 그래서 **열지 못하는 경우를 정상 경로로 다룬다.** URL 은 이미 App Group 에 저장돼
    /// 있으므로, 못 열어도 사용자가 앱을 직접 켜면 입력칸이 채워져 있다 — 그 사실을 알려 준다.
    private func openHostApp(_ url: URL) {
        // 결과를 받아야 실패를 알 수 있다. 전에는 `nil` 을 넘겨 성공·실패를 모두 버렸다.
        extensionContext?.open(url) { [weak self] opened in
            guard let self else { return }
            if opened {
                Self.log.debug("호스트 앱 열기 성공(extensionContext)")
                // 여기서 확장을 닫지 않는다. 앱이 뜨면 시스템이 알아서 걷어간다 —
                // 전에는 0.3 초 뒤 무조건 닫아서, 진행 중이던 열기까지 함께 취소됐다.
                return
            }
            Self.log.error("extensionContext.open 실패 — responder chain 으로 재시도")
            self.openViaResponderChain(url)
            self.reportFailureIfStillHere()
        }
    }

    /// responder chain 우회 시도.
    ///
    /// **성공 여부를 돌려주지 않는다.** 전에는 `responds(to:)` 가 참이면 열었다고 봤는데,
    /// 그건 그 selector 가 **존재한다**는 뜻일 뿐 호출이 무슨 일을 했는지는 알려 주지 않는다.
    /// 그래서 아무 일도 안 일어났는데 성공으로 처리돼, 실패 안내가 영영 뜨지 않았다.
    private func openViaResponderChain(_ url: URL) {
        var responder: UIResponder? = self
        let selector = sel_registerName("openURL:")
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
        Self.log.error("responder chain 에 openURL: 이 없다")
    }

    /// 잠시 뒤에도 **우리가 아직 화면에 있으면** 열기가 실패한 것이다.
    ///
    /// 여는 데 성공했는지 물어볼 API 가 없다. 대신 결과를 본다 — 앱이 떴다면 이 확장은
    /// 가려지거나 걷혀서 창에서 빠진다. 그대로 남아 있다는 건 아무 일도 없었다는 뜻이다.
    private func reportFailureIfStillHere() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.openGrace) { [weak self] in
            guard let self, self.view.window != nil else { return }
            Self.log.error("호스트 앱을 열지 못했다 — 직접 열기 안내로 전환")
            self.showOpenFailed()
        }
    }

    /// 앱이 뜰 때까지 기다려 주는 시간(초).
    private static let openGrace: TimeInterval = 1.5

    /// 앱을 못 열었을 때. 실패를 삼키지 않고 다음 할 일을 알려 준다.
    private func showOpenFailed() {
        titleLabel.text = i18n.t("share.openFailedTitle")
        bodyLabel.text = i18n.t("share.openFailedBody")
        openButton.isHidden = true
    }

    private static let log = Logger(subsystem: "clipnote.share", category: "extension")
}
