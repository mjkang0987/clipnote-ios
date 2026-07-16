import Foundation
import SwiftData

/// 비로그인 사용자의 '내 클립' — 이 기기(SwiftData)에만 보관(공유 X).
/// RN `lib/local-clips.ts`의 `LocalClip` 이식. `description`은 NSObject 충돌 회피로 `clipDescription`.
@Model
final class LocalClip {
    var url: String
    var title: String
    var clipDescription: String?
    var image: String?
    var siteName: String?
    var gradient: String
    var tags: [String]
    var savedAt: Date

    init(
        url: String,
        title: String,
        clipDescription: String?,
        image: String?,
        siteName: String?,
        gradient: String,
        tags: [String],
        savedAt: Date
    ) {
        self.url = url
        self.title = title
        self.clipDescription = clipDescription
        self.image = image
        self.siteName = siteName
        self.gradient = gradient
        self.tags = tags
        self.savedAt = savedAt
    }
}
