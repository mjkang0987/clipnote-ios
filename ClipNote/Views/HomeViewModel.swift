import Foundation
import Observation

/// 홈에서 사용자에게 보여 줄 오류.
///
/// **문자열이 아니라 케이스로 둔다.** 표시 언어는 `LocalizationStore`(뷰 환경)가 알고 있는데
/// 이 모델은 뷰가 아니라서 접근할 수 없다. 모델에 스토어를 주입하면 언어가 바뀔 때 모델까지
/// 다시 만들어야 하고, 문자열을 만들 시점의 언어로 굳어 버린다. 케이스로 두면 뷰가 그릴 때
/// 그 시점의 언어로 번역한다.
enum HomeError: Equatable {
    case metaFailed
    case titleRequiredForLink
    case titleRequiredForClip
    /// 링크 생성 실패. 서버가 사유를 주면 그걸 쓰고(이미 사람이 읽는 문장), 없으면 사전 문구.
    case linkCreateFailed(server: String?)
    /// 서버가 준 메시지를 그대로 보여 준다(클립 추가 실패 등).
    case server(String)
}

/// 홈 화면 상태·로직. RN `app/index.tsx` 이식. URL 디바운스 메타 추출 + 저장/공유 입력 조립.
@MainActor
@Observable
final class HomeViewModel {
    var url = ""
    var title = ""
    var tagInput = ""

    private(set) var meta: ClipMetadata?
    private(set) var loading = false
    var error: HomeError?

    private let api: APIClient
    private var debounceTask: Task<Void, Never>?
    private var fetchedURL: String?
    /// 직전 URL — 이번 변경이 타이핑인지 붙여넣기인지 가르는 데만 쓴다.
    private var previousURL = ""

    /// 타이핑 디바운스. 한 글자마다 요청을 보내지 않으려고 둔다.
    private static let typingDebounce = Duration.milliseconds(600)

    init(api: APIClient = .shared) { self.api = api }

    // MARK: - Derived

    var tags: [String] { parseTags(tagInput) }
    var trimmedURL: String { url.trimmingCharacters(in: .whitespacesAndNewlines) }
    var hasInput: Bool { !trimmedURL.isEmpty }
    var noMeta: Bool { meta?.source == "none" }
    var metaReason: String? { meta?.reason }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 그라디언트 시드 — RN과 동일 우선순위(입력 제목 > 메타 제목 > url > "clipnote").
    var gradient: ClipGradient {
        if !trimmedTitle.isEmpty { return pickGradient(trimmedTitle) }
        if let mt = meta?.title, !mt.isEmpty { return pickGradient(mt) }
        return pickGradient(url.isEmpty ? "clipnote" : url)
    }

    /// 저장·전송·미리보기에 쓰는 제목. 빈 값이면 화면이 `home.preview.titlePlaceholder` 를 대신 그린다
    /// — 플레이스홀더는 번역 대상이라 모델이 들고 있으면 안 된다.
    var resolvedTitle: String {
        if !trimmedTitle.isEmpty { return trimmedTitle }
        if let mt = meta?.title, !mt.isEmpty { return mt }
        return hasInput ? prettyHost(url) : ""
    }

    var previewDescription: String? { meta?.description }
    var previewImage: String? { meta?.image }
    var previewSiteName: String? { meta?.siteName }

    // MARK: - Metadata extraction (600ms debounce)

    /// 이번 변경이 **사람이 한 글자 친 것**인가.
    ///
    /// 아니라면 붙여넣기·공유 확장으로 URL 이 통째로 들어온 것이다. 그때는 더 들어올 글자가
    /// 없으니 디바운스를 기다릴 이유가 없다 — 이 앱의 주 입력이 붙여넣기라 체감이 그만큼 빨라진다.
    static func isTyping(from previous: String, to current: String) -> Bool {
        current.count == previous.count + 1 && current.hasPrefix(previous)
    }

    /// URL 변경 콜백. 유효하면 메타 추출(타이핑이면 디바운스 후). 변경 시 이전 Task 취소.
    func urlChanged() {
        let t = trimmedURL
        let typed = Self.isTyping(from: previousURL, to: t)
        previousURL = t

        if let f = fetchedURL, f != t {
            fetchedURL = nil
            meta = nil
            title = ""
        }
        debounceTask?.cancel()
        guard isFetchableUrl(t), fetchedURL != t else { return }
        debounceTask = Task { [weak self] in
            if typed { try? await Task.sleep(for: Self.typingDebounce) }
            guard !Task.isCancelled else { return }
            await self?.loadMeta(t)
        }
    }

    /// 메타 추출(테스트에서 직접 호출). 성공 시 제목이 비어있으면 자동 채움.
    func loadMeta(_ target: String) async {
        guard isFetchableUrl(target) else { return }
        loading = true
        error = nil
        defer { loading = false }
        do {
            let data = try await api.fetchMetadata(url: target)
            guard !Task.isCancelled else { return }
            meta = data
            fetchedURL = target
            if let ft = data.title, !ft.isEmpty, trimmedTitle.isEmpty {
                title = ft
            }
        } catch {
            self.error = .metaFailed
        }
    }

    // MARK: - Save / share

    private func makeInput(save: Bool?) -> CreateClipInput? {
        let t = resolvedTitle
        guard !t.isEmpty else { return nil }
        return CreateClipInput(
            url: trimmedURL, title: t,
            description: meta?.description, image: meta?.image, siteName: meta?.siteName,
            tags: tags, gradient: gradient.name, save: save
        )
    }

    /// 게스트: 이 기기(로컬)에 저장. 제목 없으면 false.
    @discardableResult
    func saveToDevice(_ store: LocalClipStore) -> Bool {
        let t = resolvedTitle
        guard !t.isEmpty else { return false }
        store.save(
            url: trimmedURL, title: t,
            description: meta?.description, image: meta?.image, siteName: meta?.siteName,
            gradient: gradient.name, tags: tags
        )
        return true
    }

    /// 로그인: 공유 링크 생성. 실패 시 `error` 설정 후 nil.
    func createShare(accessToken: String?) async -> CreateClipResult? {
        guard let input = makeInput(save: nil) else {
            error = .titleRequiredForLink
            return nil
        }
        error = nil
        let res = await api.createClip(input, accessToken: accessToken)
        guard res.error == nil, res.shareUrl != nil else {
            error = .linkCreateFailed(server: res.error)
            return nil
        }
        return res
    }

    /// 로그인: 공유 카드 없이 바로 내 클립(DB)에 저장.
    func saveToClips(accessToken: String?) async -> Bool {
        guard let input = makeInput(save: true) else {
            error = .titleRequiredForClip
            return false
        }
        error = nil
        let res = await api.createClip(input, accessToken: accessToken)
        if let e = res.error { error = .server(e); return false }
        return true
    }
}
