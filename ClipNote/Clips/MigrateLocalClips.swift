import Foundation

/// 로그인 전환 시 로컬 클립을 내 계정(DB)으로 옮긴다. 설계 §5. RN `MigrateLocalClips` 이식.
/// 방침: **전량 업로드 성공 시에만** `clearLocalClips`(부분 실패 시 유지 → 재시도 가능, 데이터 손실 방지).
@MainActor
final class MigrateLocalClips {
    private let api: APIClient
    private let localStore: LocalClipStore
    private var inProgress = false

    init(api: APIClient = .shared, localStore: LocalClipStore) {
        self.api = api
        self.localStore = localStore
    }

    /// 옮길 로컬 클립 수(0이면 마이그레이션 불필요).
    func pendingCount() -> Int { localStore.all().count }

    static func input(from c: LocalClip) -> CreateClipInput {
        CreateClipInput(
            url: c.url, title: c.title,
            description: c.clipDescription, image: c.image, siteName: c.siteName,
            tags: c.tags, gradient: c.gradient, save: true
        )
    }

    /// 실행. 반환(업로드 성공 수, 전량 성공 여부). 전량 성공 시 로컬 비우고 목록 새로고침 신호.
    func run(accessToken: String?) async -> (uploaded: Int, allOK: Bool) {
        guard !inProgress else { return (0, false) }
        inProgress = true
        defer { inProgress = false }

        let clips = localStore.all()
        guard !clips.isEmpty else { return (0, true) }

        var uploaded = 0
        for c in clips {
            let res = await api.createClip(Self.input(from: c), accessToken: accessToken)
            if res.error == nil { uploaded += 1 }
        }

        let allOK = uploaded == clips.count
        if allOK {
            localStore.clearLocalClips()
            ClipsRefresh.emit()
        }
        return (uploaded, allOK)
    }
}
