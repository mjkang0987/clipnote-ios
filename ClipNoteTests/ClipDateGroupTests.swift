import Testing
import Foundation
@testable import ClipNote

/// 날짜 그룹 라벨·묶기.
///
/// 라벨 **문구 자체는 검사하지 않는다.** 시스템 포매터가 만드는 값이라 OS 판마다 달라질 수
/// 있고, 그걸 못 박으면 애플이 문구를 다듬을 때마다 테스트가 깨진다. 대신 이 기능이 실제로
/// 지켜야 하는 것 — **경계가 맞는지, 언어를 따라가는지, 순서가 보존되는지** — 를 본다.
struct ClipDateGroupTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let ko = Locale(identifier: "ko")

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func clip(_ id: String, at when: Date) -> UClip {
        UClip(id: id, slug: id, url: "https://x.com/\(id)", title: id,
              description: nil, image: nil, siteName: nil, gradient: "ocean",
              tags: [], shared: false, local: false, savedAt: when)
    }

    /// 다섯 구간이 서로 다른 라벨로 갈리는지. 경계가 어긋나면 "어제" 가 "이번 주" 로 샌다.
    @Test func bucketsAreDistinct() {
        let now = date(2026, 8, 3)
        let labels = [
            clipDateGroupLabel(now, now: now, locale: ko),                       // 오늘
            clipDateGroupLabel(date(2026, 8, 2), now: now, locale: ko),          // 어제
            clipDateGroupLabel(date(2026, 7, 30), now: now, locale: ko),         // 이번 주(4일 전)
            clipDateGroupLabel(date(2026, 8, 20), now: date(2026, 8, 30), locale: ko), // 같은 달
            clipDateGroupLabel(date(2026, 3, 5), now: now, locale: ko),          // 지난 연월
        ]
        #expect(Set(labels).count == labels.count, "겹치는 라벨: \(labels)")
        #expect(labels.allSatisfy { !$0.isEmpty })
    }

    /// 하루 차이로 라벨이 바뀌는 경계 두 곳. 시각이 아니라 **날짜**로 끊어야 한다.
    @Test func boundariesFallOnDayNotHour() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 1))!
        // 같은 날 늦은 시각과 이른 시각은 같은 그룹이다(23시간 차이여도).
        let lateSameDay = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 23))!
        #expect(clipDateGroupLabel(lateSameDay, now: now, locale: ko)
                == clipDateGroupLabel(now, now: now, locale: ko))
        // 두 시간 전이지만 날짜가 다르면 다른 그룹이다.
        let lastNight = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 23))!
        #expect(clipDateGroupLabel(lastNight, now: now, locale: ko)
                != clipDateGroupLabel(now, now: now, locale: ko))
    }

    /// 선택 언어를 따른다. 시스템 언어를 따라가면 앱 안에서 언어를 바꿔도 머리글만 안 바뀐다.
    ///
    /// **네 언어가 모두 다르길 기대하지 않는다.** 일본어와 중국어 간체는 연월 형식이 같아
    /// (`2026年3月`) 값이 겹친다 — 그건 정상이다. 확인해야 하는 건 "언어를 바꾸면 값이
    /// 바뀐다" 이지 "네 값이 서로 다르다" 가 아니다.
    @Test func followsSelectedLanguage() {
        let now = date(2026, 8, 3)
        let labels: (Date) -> [String] = { when in
            ["ko", "en", "ja", "zh-Hans"].map {
                clipDateGroupLabel(when, now: now, locale: Locale(identifier: $0))
            }
        }
        // 잡아야 하는 회귀는 "로케일이 무시돼 전부 한 언어로 나온다" 이다. 어느 두 언어가
        // 우연히 같은지까지 못 박으면(방금 그래서 깨졌다) 시스템 문구가 바뀔 때 또 깨진다.
        for when in [now, date(2026, 3, 5)] {
            let values = labels(when)
            #expect(values.allSatisfy { !$0.isEmpty })
            #expect(Set(values).count > 1, "로케일이 무시된다: \(values)")
            #expect(values[0] != values[1], "한국어와 영어가 같다: \(values)")
        }
    }

    /// 묶어도 순서와 개수가 보존되는지. 목록이 최신순이면 그룹도 최신순이어야 한다.
    @Test func groupingKeepsOrderAndCount() {
        let now = date(2026, 8, 3)
        let clips = [
            clip("a", at: now),
            clip("b", at: now),
            clip("c", at: date(2026, 8, 2)),
            clip("d", at: date(2026, 3, 5)),
        ]
        let groups = groupClipsByDate(clips, now: now, locale: ko)
        #expect(groups.count == 3)
        #expect(groups.map(\.clips.count) == [2, 1, 1])
        #expect(groups.flatMap { $0.clips.map(\.id) } == ["a", "b", "c", "d"])
    }
}
