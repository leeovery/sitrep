import Foundation
import os
import SitRepRelay
import UserNotifications

/// What posting a banner asks of macOS's notification center.
@MainActor
protocol BannerCenter {
    /// The asks of the banners still delivered, by their requests' ids; a banner with none left out.
    func deliveredAsks() async -> [String: NoticeAsk]
    /// Replaces the whole set; it lands later, once this returns.
    func setCategories(_ categories: Set<UNNotificationCategory>)
    /// The set registered, read only to wait for the last set to land.
    func categories() async -> Set<UNNotificationCategory>
    func add(_ request: UNNotificationRequest) async throws
}

/// Posts each banner, a new ask's under a category of its own (`Buttons`), its set registered and landed before the
/// banner is added, or macOS would draw it with no buttons.
@MainActor
final class Poster {
    /// How many categories of the banners last posted are kept, though Notification Center does not list them as
    /// delivered, as it may not yet for one just posted.
    static let keptRecent = 10

    private let center: BannerCenter
    private let newId: () -> String
    private let logger = Logger(helper: "banner")
    /// The categories last posted, the newest last.
    private var recent: [UNNotificationCategory] = []

    init(center: BannerCenter, newId: @escaping () -> String = { UUID().uuidString }) {
        self.center = center
        self.newId = newId
    }

    func post(_ notice: Notice) async {
        let id = newId()
        let content = UNMutableNotificationContent()

        content.title = notice.title
        content.subtitle = notice.subtitle ?? ""
        content.body = notice.body
        content.userInfo = Buttons.userInfo(notice)
        if let ask = notice.ask {
            await register(Buttons.category(ask, id: id))
            content.categoryIdentifier = id
        }

        do {
            try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
        } catch {
            logger.error("Banner not posted: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func register(_ category: UNNotificationCategory) async {
        recent = Array((recent + [category]).suffix(Self.keptRecent))
        center.setCategories(Buttons.categories(delivered: await center.deliveredAsks(), recent: recent))
        _ = await center.categories()
    }
}

/// macOS's own notification center.
@MainActor
final class LiveCenter: BannerCenter {
    private let center = UNUserNotificationCenter.current()

    func deliveredAsks() async -> [String: NoticeAsk] {
        let delivered = await center.deliveredNotifications().compactMap { notification in
            Buttons.ask(notification.request.content.userInfo).map { (notification.request.identifier, $0) }
        }

        return Dictionary(delivered) { first, _ in first }
    }

    func setCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }

    func categories() async -> Set<UNNotificationCategory> {
        await center.notificationCategories()
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }
}
