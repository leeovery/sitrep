import Foundation
import os
import SitRepRelay
import UserNotifications

/// What posting and taking down banners asks of macOS's notification center.
@MainActor
protocol BannerCenter {
    /// The asks of the banners still delivered, by their requests' ids; a banner with none left out.
    func deliveredAsks() async -> [String: NoticeAsk]
    func add(_ request: UNNotificationRequest) async throws
    func remove(_ ids: [String])
}

/// Posts each banner, carrying the session its click jumps to and the ask it tells of (`BannerInfo`), and takes down
/// those of an ask that waits on Lee no more.
@MainActor
final class Poster {
    private let center: BannerCenter
    private let newId: () -> String
    private let logger = Logger(helper: "banner")

    init(center: BannerCenter, newId: @escaping () -> String = { UUID().uuidString }) {
        self.center = center
        self.newId = newId
    }

    func post(_ notice: Notice) async {
        let content = UNMutableNotificationContent()

        content.title = notice.title
        content.subtitle = notice.subtitle ?? ""
        content.body = notice.body
        content.userInfo = BannerInfo.of(notice)

        do {
            try await center.add(UNNotificationRequest(identifier: newId(), content: content, trigger: nil))
        } catch {
            logger.error("Banner not posted: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The banners still delivered of the ask of the session go, so Notification Center keeps only what still waits.
    func clear(ask: String, session: String) async {
        let ids = await center.deliveredAsks().filter { $1.id == ask && $1.session == session }.map(\.key)

        if !ids.isEmpty {
            center.remove(ids.sorted())
        }
    }
}

/// macOS's own notification center.
@MainActor
final class LiveCenter: BannerCenter {
    private let center = UNUserNotificationCenter.current()

    func deliveredAsks() async -> [String: NoticeAsk] {
        let delivered = await center.deliveredNotifications().compactMap { notification in
            BannerInfo.ask(notification.request.content.userInfo).map { (notification.request.identifier, $0) }
        }

        return Dictionary(delivered) { first, _ in first }
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func remove(_ ids: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}
