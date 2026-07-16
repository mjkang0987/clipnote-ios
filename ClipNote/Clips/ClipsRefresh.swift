import Foundation

/// 내 클립 목록 강제 새로고침 신호(마이그레이션·편집 등 외부 트리거). RN `lib/clips-refresh.ts` 이식.
/// 뷰는 `NotificationCenter.default.publisher(for: ClipsRefresh.name)`를 구독.
enum ClipsRefresh {
    static let name = Notification.Name("clipnote.clipsRefresh")

    static func emit() {
        NotificationCenter.default.post(name: name, object: nil)
    }
}
