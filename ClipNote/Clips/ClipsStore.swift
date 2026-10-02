import Foundation
import Observation

enum TagMode { case add, replace }

/// 내 클립 목록 상태·로직. RN `app/clips.tsx` 이식.
///
/// 목록의 출처는 로그인 여부로 갈린다 — 게스트는 이 기기(로컬), 로그인은 계정(DB). 섞지 않는다.
/// 로그인 상태에서 이 기기에 남은 클립은 `localOnlyCount` 로만 알리고 `LocalClipsView` 가 맡는다.
@MainActor
@Observable
final class ClipsStore {
    /// nil = 로딩 중.
    private(set) var clips: [UClip]?

    /// 목록에 있는 모든 태그(순서 보존·중복 제거).
    ///
    /// **목록이 바뀔 때 한 번만 계산한다.** 전에는 계산 프로퍼티라 접근할 때마다 전체를 훑었는데,
    /// 필터 칩과 `filtered` 가 각각 읽어서 렌더 한 번에 클립 수만큼을 두 번씩 순회했다.
    private(set) var allTags: [String] = []

    /// 태그 필터. 바뀌면 `filtered` 를 다시 계산한다.
    ///
    /// `didSet` 을 쓰지 않는다 — `@Observable` 매크로가 저장 프로퍼티에 get/set 접근자를
    /// 만들어 넣는데, 관찰자(`didSet`)와 겹칠 때 어떻게 되는지 이 저장소에 선례가 없다.
    /// 확실한 쪽으로 간다: 저장은 따로 두고 set 에서 직접 부른다.
    var activeTag: String? {
        get { storedActiveTag }
        set {
            storedActiveTag = newValue
            refreshFiltered()
        }
    }
    private var storedActiveTag: String?

    /// 검색어. 태그와 좁히는 축이 달라(태그=분류, 검색어=내용) 서로를 지우지 않는다.
    var query: String {
        get { storedQuery }
        set {
            storedQuery = newValue
            refreshFiltered()
        }
    }
    private var storedQuery: String = ""

    private let api: APIClient
    private let localStore: LocalClipStore
    private let shareBase: URL
    /// 마지막 로드 컨텍스트 — 변경 후 reload에 사용.
    private var ctx: (loggedIn: Bool, token: String?) = (false, nil)

    init(api: APIClient = .shared, localStore: LocalClipStore, shareBase: URL = Config.apiBase) {
        self.api = api
        self.localStore = localStore
        self.shareBase = shareBase
    }

    // MARK: - Load

    /// 마지막 조회가 **실패**했는가. 빈 목록과 구분해야 한다.
    ///
    /// 실패를 빈 목록으로 흘리면 "아직 저장한 클립이 없어요" 가 뜬다. 클립이 사라진 줄 알고
    /// 다시 만들게 되는 화면이라, 실패는 실패라고 말하고 다시 시도할 길을 준다.
    private(set) var loadFailed = false

    /// 이 기기에만 남아 있는 클립 수. 로그인 목록 위의 진입 줄이 쓴다.
    ///
    /// 목록과 함께 갱신한다 — 옮기거나 지운 뒤 `reload()` 가 돌면 이 값도 따라온다.
    /// 게스트일 때는 목록 자체가 로컬이라 0 으로 둔다(진입 줄을 띄울 이유가 없다).
    private(set) var localOnlyCount = 0

    func load(loggedIn: Bool, accessToken: String?) async {
        ctx = (loggedIn, accessToken)
        guard loggedIn else {
            loadFailed = false
            localOnlyCount = 0
            apply(localStore.all().map(UClip.init))
            return
        }
        localOnlyCount = localStore.all().count
        let result = await api.getClips(accessToken: accessToken)
        loadFailed = result.failed
        guard !result.failed else {
            // 이미 받아 둔 목록이 있으면 지우지 않는다 — 잠깐 끊겼다고 화면에서 비우면
            // 그것도 사라진 것처럼 보인다. 첫 조회였다면 로딩 상태에서는 빠져나온다.
            if clips == nil { apply([]) }
            return
        }
        apply(result.clips.map(UClip.init))
    }

    /// 목록과 그로부터 나오는 값을 함께 갱신한다. 목록은 여기서만 바뀐다.
    private func apply(_ next: [UClip]) {
        clips = next
        allTags = orderedUnique(next.flatMap(\.tags))
        // `allTags` 가 먼저 정해져야 한다 — `effectiveTag` 가 그걸 보고 stale 태그를 버린다.
        refreshFiltered()
    }

    func reload() async {
        await load(loggedIn: ctx.loggedIn, accessToken: ctx.token)
    }

    // MARK: - Derived

    /// 실제로 걸려 있는 태그. 목록이 바뀌어 사라진 태그는 **안 건 것**으로 본다.
    ///
    /// 빈 상태 문구도 이 값을 봐야 한다 — `activeTag` 를 그대로 읽으면 걸리지도 않은
    /// 필터를 탓하게 된다.
    var effectiveTag: String? {
        storedActiveTag.flatMap { allTags.contains($0) ? $0 : nil }
    }

    /// 태그와 검색어를 **함께** 건 결과. 한쪽이 다른 쪽을 지우면 태그를 고른 채로는 검색할 수 없다.
    ///
    /// **계산 프로퍼티가 아니다.** 한 번 그리는 동안 목록·하단 바·제목이 각각 읽어 네 번쯤
    /// 훑게 되고, 그게 키 입력마다 반복된다. `allTags` 를 캐시로 돌린 것과 같은 이유다.
    private(set) var filtered: [UClip] = []

    /// `filtered` 의 id 집합 — 선택이 지금 보이는지 O(1) 로 본다.
    private var visibleIDs: Set<String> = []

    /// 목록·태그·검색어가 바뀔 때만 다시 계산한다.
    private func refreshFiltered() {
        let source = clips ?? []
        let tag = effectiveTag
        // 소문자 변환은 **여기서 한 번만** — 클립마다 내리면 목록 길이만큼 낭비다.
        let q = storedQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if tag == nil, q.isEmpty {
            filtered = source
        } else {
            filtered = source.filter { clip in
                if let tag, !clip.tags.contains(tag) { return false }
                if !q.isEmpty, !clip.matches(lowercasedQuery: q) { return false }
                return true
            }
        }
        visibleIDs = Set(filtered.map(\.id))
    }

    /// 선택한 것 중 **지금 화면에 보이는** 개수. 하단 바·제목·확인 문구가 쓴다.
    func visibleSelectedCount(_ ids: Set<String>) -> Int {
        ids.filter { visibleIDs.contains($0) }.count
    }

    /// 공유 복사 텍스트(§4.3) — 제목+브릿지 링크(설명 제외, #74/PR #75). 로컬 클립은 slug 없어 nil.
    func shareText(_ c: UClip) -> String? {
        guard let slug = c.slug else { return nil }
        let url = shareBase.appendingPathComponent(slug).absoluteString
        return buildShareText(title: c.title, description: c.description, url: url)
    }

    // MARK: - Mutations (각자 reload로 마무리)

    func removeOne(_ c: UClip) async {
        if c.local {
            localStore.delete(url: c.url)
        } else if let slug = c.slug {
            _ = await api.deleteClip(slug: slug, accessToken: ctx.token)
        }
    }

    func delete(_ c: UClip) async {
        await removeOne(c)
        await reload()
    }

    /// 다중선택 일괄 삭제.
    ///
    /// 서버 왕복을 **동시에** 보낸다. 전에는 순차 `await` 라 10개를 지우면 왕복 10번을 줄줄이
    /// 기다렸다 — 모바일 네트워크에서 체감이 크다. 대상 조회도 매번 배열을 훑는 대신 사전을 쓴다.
    func bulkDelete(ids: [String]) async {
        let targets = lookup(ids)
        guard !targets.isEmpty else { return }
        await forEachConcurrently(targets) { await self.removeOne($0) }
        await reload()
    }

    /// id 목록을 클립으로 바꾼다. `ids` 하나마다 배열을 훑으면 선택이 늘수록 제곱으로 느려진다.
    ///
    /// **`clips` 가 아니라 `filtered` 에서 찾는다.** 선택한 뒤 검색어나 태그로 목록을 좁히면
    /// 고른 것 중 일부가 화면에서 사라지는데, 전체 목록에서 찾으면 **보이지 않는 클립까지**
    /// 지워진다. 삭제는 되돌릴 수 없다. 화면 밖으로 나간 선택을 잊지는 않는다 — 호출부의
    /// `selected` 에 그대로 있고, 필터를 풀면 다시 대상이 된다.
    private func lookup(_ ids: [String]) -> [UClip] {
        let byID = Dictionary(filtered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byID[$0] }
    }

    /// 동시에 띄울 요청 수 상한. 무제한으로 풀면 선택이 많을 때(로컬 캡 300개) 서버를 때린다.
    private static let maxInFlight = 6

    /// 각 클립에 대해 `work` 를 **동시에, 그러나 상한을 두고** 실행한다.
    /// 하나 끝날 때마다 다음 하나를 띄운다.
    private func forEachConcurrently(
        _ clips: [UClip],
        _ work: @escaping @Sendable (UClip) async -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            var pending = clips.makeIterator()
            for _ in 0..<min(Self.maxInFlight, clips.count) {
                guard let clip = pending.next() else { break }
                group.addTask { await work(clip) }
            }
            while await group.next() != nil {
                guard let clip = pending.next() else { continue }
                group.addTask { await work(clip) }
            }
        }
    }

    func saveEdit(_ c: UClip, title: String, tags: [String]) async {
        if c.local {
            localStore.update(url: c.url, title: title, tags: tags)
        } else if let slug = c.slug {
            _ = await api.updateClip(slug: slug, title: title, tags: tags, shared: nil, accessToken: ctx.token)
        }
        await reload()
    }

    /// 공유 링크 켜기(shared=true). 성공 시 reload.
    func makeShared(_ c: UClip) async -> Bool {
        guard let slug = c.slug else { return false }
        let ok = await api.updateClip(slug: slug, title: nil, tags: nil, shared: true, accessToken: ctx.token)
        if ok { await reload() }
        return ok
    }

    /// 다중선택 태그 일괄. add=기존∪신규(dedup·최대6), replace=신규(최대6).
    /// 삭제와 같은 이유로 서버 왕복을 동시에 보낸다.
    func applyTags(ids: [String], tags: [String], mode: TagMode) async {
        let targets = lookup(ids)
        guard !targets.isEmpty else { return }
        await forEachConcurrently(targets) { clip in
            let next: [String]
            switch mode {
            case .add: next = Array(orderedUnique(clip.tags + tags).prefix(6))
            case .replace: next = Array(tags.prefix(6))
            }
            await self.applyTags(to: clip, tags: next)
        }
        await reload()
    }

    private func applyTags(to clip: UClip, tags: [String]) async {
        if clip.local {
            localStore.update(url: clip.url, title: nil, tags: tags)
        } else if let slug = clip.slug {
            _ = await api.updateClip(slug: slug, title: nil, tags: tags, shared: nil, accessToken: ctx.token)
        }
    }
}

extension UClip {
    /// 검색어와 맞는가 — **제목·URL·태그**. 웹 `ClipsClient` 와 같은 규칙이다.
    /// 카드에 보이는 호스트는 URL 에서 뽑은 것이라 URL 만 훑으면 함께 걸린다.
    ///
    /// `localizedCaseInsensitiveContains` 를 **쓰지 않는다.** 그건 `Locale.current` 로
    /// 대소문자를 접어서, 터키어 기기에서는 `I` 가 `ı` 로 내려가 같은 검색어가 기기마다
    /// 다르게 걸린다. 웹이 `toLocaleLowerCase()` 대신 `toLowerCase()` 를 쓰는 것과 같은
    /// 이유다 — `lowercased()` 는 로케일을 타지 않는 유니코드 기본 매핑이다.
    ///
    /// `query` 는 **이미 소문자로 내린 것**을 받는다. 클립마다 다시 내리면 목록 길이만큼 낭비다.
    func matches(lowercasedQuery query: String) -> Bool {
        title.lowercased().contains(query)
            || url.lowercased().contains(query)
            || tags.contains { $0.lowercased().contains(query) }
    }
}

/// 순서 보존 중복 제거.
func orderedUnique(_ arr: [String]) -> [String] {
    var seen = Set<String>()
    var out: [String] = []
    for x in arr where seen.insert(x).inserted { out.append(x) }
    return out
}

/// 날짜 그룹 — 목록을 저장 시각으로 묶는다(웹 `groupByDate` 이식).
struct ClipDateGroup: Identifiable {
    let label: String
    let clips: [UClip]
    var id: String { label }
}

/// 날짜 그룹 라벨. **문자열 카탈로그에 넣지 않는다.**
///
/// 웹이 `Intl` 에 맡긴 것과 같은 이유다. 문구가 넷(오늘·어제·이번 주·이번 달)이라 사전에
/// 넣을 수는 있지만, `2026년 7월` 같은 연월은 **형식 자체가 언어마다 다르다**
/// (en `July 2026`, ja `2026年7月`). 형식은 사전으로 표현할 수 없어서 어차피 시스템
/// 포매터가 필요하고, 그러면 넷도 같은 곳에 맡기는 게 일관된다.
func clipDateGroupLabel(_ date: Date, now: Date = Date(), locale: Locale) -> String {
    clipDateGroupLabel(date, now: now, locale: locale, formatter: relativeFormatter(locale))
}

/// 포매터를 **바깥에서 받는** 판. 목록 하나를 묶는 동안 하나만 만들어 돌려 쓴다.
///
/// `RelativeDateTimeFormatter` 는 만드는 비용이 있는 객체다. 클립마다 새로 만들면 로컬
/// 상한(300개)에서 렌더 한 번에 300번을 만든다.
private func clipDateGroupLabel(_ date: Date, now: Date, locale: Locale,
                                formatter: RelativeDateTimeFormatter) -> String {
    let calendar = Calendar(identifier: .gregorian)
    let days = calendar.dateComponents([.day],
                                       from: calendar.startOfDay(for: date),
                                       to: calendar.startOfDay(for: now)).day ?? 0

    if days <= 0 { return formatter.localizedString(from: DateComponents(day: 0)) }
    if days == 1 { return formatter.localizedString(from: DateComponents(day: -1)) }
    if days < 7 { return formatter.localizedString(from: DateComponents(weekOfMonth: 0)) }
    if calendar.isDate(date, equalTo: now, toGranularity: .month) {
        return formatter.localizedString(from: DateComponents(month: 0))
    }
    return date.formatted(.dateTime.year().month(.wide).locale(locale))
}

private func relativeFormatter(_ locale: Locale) -> RelativeDateTimeFormatter {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = locale
    // `.named` 라야 "1일 전" 이 아니라 "오늘"·"어제" 가 나온다.
    formatter.dateTimeStyle = .named
    return formatter
}

/// 순서를 유지한 채 날짜로 묶는다. 목록은 이미 최신순이라 그룹도 최신순이 된다.
func groupClipsByDate(_ clips: [UClip], now: Date = Date(), locale: Locale) -> [ClipDateGroup] {
    let formatter = relativeFormatter(locale)
    var order: [String] = []
    var buckets: [String: [UClip]] = [:]
    for clip in clips {
        let label = clipDateGroupLabel(clip.savedAt, now: now, locale: locale, formatter: formatter)
        if buckets[label] == nil { order.append(label) }
        buckets[label, default: []].append(clip)
    }
    return order.map { ClipDateGroup(label: $0, clips: buckets[$0] ?? []) }
}
