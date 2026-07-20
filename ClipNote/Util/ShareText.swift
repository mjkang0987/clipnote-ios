import Foundation

/// Builds the clipboard/share payload for a clip's share link.
/// Format: `title\nurl`. 설명은 길어 붙여넣기 글이 지저분해져 제외(웹 clipnote c4c4ad9와 동일).
/// `description`은 호출부 시그니처 호환을 위해 남기되 사용하지 않는다.
func buildShareText(title: String, description: String?, url: String) -> String {
    [title, url].joined(separator: "\n")
}
