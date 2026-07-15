import Foundation

/// Builds the clipboard/share payload for a clip's share link.
/// Format: title, then description (only if non-blank), then url — newline-joined.
func buildShareText(title: String, description: String?, url: String) -> String {
    var lines = [title]
    if let d = description?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
        lines.append(d)
    }
    lines.append(url)
    return lines.joined(separator: "\n")
}
