import Foundation

/// 공유 확장 ↔ 앱 간 URL 전달(App Group).
/// 확장이 저장하고, 앱이 포그라운드로 올라올 때 1회 소비한다.
/// openURL 열기 hack이 실패해도 앱을 열면 URL을 집어가므로 유실이 없다.
enum SharedURLStore {
    static let appGroupID = "group.kr.co.clipnote.app"
    private static let key = "pendingSharedURL"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    /// 확장에서 공유받은 URL 저장.
    static func save(_ url: String) {
        defaults?.set(url, forKey: key)
    }

    /// 저장된 URL을 읽고 즉시 지운다(1회 소비). 없으면 nil.
    static func consume() -> String? {
        guard let d = defaults, let value = d.string(forKey: key) else { return nil }
        d.removeObject(forKey: key)
        return value
    }
}
