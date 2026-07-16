import Foundation
import Observation

/// 홈 화면 상태·로직. RN `app/index.tsx` 이식. URL 디바운스 메타 추출 + 저장/공유 입력 조립.
@MainActor
@Observable
final class HomeViewModel {
    var url = ""
    var title = ""
    var tagInput = ""

    private(set) var meta: ClipMetadata?
    private(set) var loading = false
    var errorMessage: String?

    private let api: APIClient
    private var debounceTask: Task<Void, Never>?
    private var fetchedURL: String?

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

    /// 미리보기용 제목(빈 값이면 플레이스홀더).
    var effectiveTitle: String {
        if !trimmedTitle.isEmpty { return trimmedTitle }
        if let mt = meta?.title, !mt.isEmpty { return mt }
        return hasInput ? prettyHost(url) : "여기에 제목이 표시됩니다"
    }

    /// 저장/전송용 제목(플레이스홀더 없음 — 빈 값이면 저장 불가).
    var resolvedTitle: String {
        if !trimmedTitle.isEmpty { return trimmedTitle }
        if let mt = meta?.title, !mt.isEmpty { return mt }
        return hasInput ? prettyHost(url) : ""
    }

    var previewDescription: String? { meta?.description }
    var previewImage: String? { meta?.image }
    var previewSiteName: String? { meta?.siteName }

    // MARK: - Metadata extraction (600ms debounce)

    /// URL 변경 콜백. 유효하면 600ms 디바운스 후 메타 추출. 변경 시 이전 Task 취소.
    func urlChanged() {
        let t = trimmedURL
        if let f = fetchedURL, f != t {
            fetchedURL = nil
            meta = nil
            title = ""
        }
        debounceTask?.cancel()
        guard isFetchableUrl(t), fetchedURL != t else { return }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.loadMeta(t)
        }
    }

    /// 메타 추출(테스트에서 직접 호출). 성공 시 제목이 비어있으면 자동 채움.
    func loadMeta(_ target: String) async {
        guard isFetchableUrl(target) else { return }
        loading = true
        errorMessage = nil
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
            errorMessage = "내용을 불러오지 못했어요. 잠시 후 다시 시도해 주세요."
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

    /// 로그인: 공유 링크 생성. 실패 시 errorMessage 설정 후 nil.
    func createShare(accessToken: String?) async -> CreateClipResult? {
        guard let input = makeInput(save: nil) else {
            errorMessage = "공유 링크를 만들려면 제목이 필요해요. 제목을 입력해 주세요."
            return nil
        }
        errorMessage = nil
        let res = await api.createClip(input, accessToken: accessToken)
        guard res.error == nil, res.shareUrl != nil else {
            errorMessage = res.error ?? "공유 링크 생성에 실패했어요."
            return nil
        }
        return res
    }

    /// 로그인: 공유 카드 없이 바로 내 클립(DB)에 저장.
    func saveToClips(accessToken: String?) async -> Bool {
        guard let input = makeInput(save: true) else {
            errorMessage = "저장하려면 제목이 필요해요. 제목을 입력해 주세요."
            return false
        }
        errorMessage = nil
        let res = await api.createClip(input, accessToken: accessToken)
        if let e = res.error { errorMessage = e; return false }
        return true
    }
}
