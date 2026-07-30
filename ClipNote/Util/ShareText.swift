import Foundation

/// 공유 텍스트 제목의 최대 길이(말줄임표 `…` 포함).
/// 웹 `lib/shareText.ts`의 `SHARE_TITLE_MAX`와 같은 값을 유지한다.
let shareTitleMaxLength = 80

/// Builds the clipboard/share payload for a clip's share link.
/// Format: `title\nurl`. 설명은 길어 붙여넣기 글이 지저분해져 제외(웹 clipnote c4c4ad9와 동일).
/// `description`은 호출부 시그니처 호환을 위해 남기되 사용하지 않는다.
func buildShareText(title: String, description: String?, url: String) -> String {
    [truncateShareTitle(title), url]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
}

/// 제목을 `max`자(말줄임표 포함)로 줄인다.
///
/// 인스타 어댑터는 `og:title`을 제목으로 쓰는데(웹 `lib/adapters/instagram.ts`) 인스타는
/// 여기에 캡션 전문을 넣는다. 자르지 않으면 공유문이 캡션 통째로 길어진다.
/// `String`의 길이·`prefix`는 그래핌 클러스터 단위라 이모지·조합 문자가 쪼개지지 않는다.
func truncateShareTitle(_ value: String, max: Int = shareTitleMaxLength) -> String {
    let title = collapseWhitespace(value)
    guard max >= 1, title.count > max else { return title }
    // 말줄임표가 한 자를 차지하므로 본문은 max-1자까지. 잘린 끝의 공백은 떼낸다.
    var head = String(title.prefix(max - 1))
    while let last = head.last, last.isWhitespace { head.removeLast() }
    return head + "…"
}

/// 공백·줄바꿈을 한 칸으로 정리(앞뒤 공백 제거 포함).
/// 인스타 캡션처럼 개행이 섞인 제목을 그대로 쓰면 `제목\nURL` 포맷이 깨져
/// 링크가 어느 줄에 있는지 알 수 없게 된다.
private func collapseWhitespace(_ value: String) -> String {
    value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
}
