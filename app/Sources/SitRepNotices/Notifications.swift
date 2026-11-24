import os
import SitRepRelay
import UserNotifications

/// macOS banners: silent, since SitRep plays its own sound for a new ask, and shown even while the helper counts as
/// the active app, as it does once a click activates it. A click on one's body is told to `onClick`, with the
/// session it names, if any; a new ask's banner has its buttons (`Buttons`), whose answers are told to `onAnswer`.
@MainActor
final class Notifications: NSObject, Notifying, UNUserNotificationCenterDelegate {
    /// How many of the banners last posted keep their buttons' categories though Notification Center does not list
    /// them as delivered, as it may not yet for one just posted.
    private static let keptPosted = 10

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(helper: "banner")
    private var onClick: (String?) -> Void = { _ in }
    private var onAnswer: (NoticeAnswer) -> Void = { _ in }
    /// The categories of the banners with buttons last posted, the newest last.
    private var posted: [String] = []

    func listen(onClick: @escaping (String?) -> Void, onAnswer: @escaping (NoticeAnswer) -> Void) {
        self.onClick = onClick
        self.onAnswer = onAnswer
        center.delegate = self
    }

    func post(_ notice: Notice) async {
        guard await isAllowed() else {
            return logger.notice("Banner not shown, as banners are not allowed: \(notice.body, privacy: .public)")
        }

        let id = UUID().uuidString
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

    /// The banner's category registered before it posts, beside those the banners still delivered need.
    private func register(_ category: UNNotificationCategory) async {
        let delivered = await center.deliveredNotifications().map(\.request.content.categoryIdentifier)
        let registered = await center.notificationCategories()

        center.setNotificationCategories(
            Buttons.registered(registered, adding: category, needed: Set(delivered + posted))
        )
        posted = Array((posted + [category.identifier]).suffix(Self.keptPosted))
    }

    func leave() async -> NoticeLeave {
        let settings = await center.notificationSettings()

        return switch settings.authorizationStatus {
        case .notDetermined: .unasked
        case .denied: .denied
        case .provisional, .ephemeral: .provisional
        case .authorized: .allowed(settings.alertStyle.style)
        @unknown default: .denied
        }
    }

    func ask() async -> NoticeLeave {
        _ = await isAllowed()

        return await leave()
    }

    /// Whether banners may show; the first time, macOS asks Lee, for alerts alone: no sound, no badge.
    private func isAllowed() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus

        guard status == .notDetermined else {
            logger.info("Banner permission: \(status.words, privacy: .public)")

            return status == .authorized || status == .provisional
        }

        do {
            let isGranted = try await center.requestAuthorization(options: [.alert])

            logger.info("Banner permission asked: \(isGranted ? "granted" : "refused", privacy: .public)")

            return isGranted
        } catch {
            logger.error("Banner permission not asked: \(error.localizedDescription, privacy: .public)")

            return false
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    /// A click on the banner's body, or one of its buttons; anything else, as an action not of its ask, is passed over.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        guard response.actionIdentifier != UNNotificationDefaultActionIdentifier else {
            let work = Buttons.work(userInfo)

            return await MainActor.run { onClick(work) }
        }

        let typed = (response as? UNTextInputNotificationResponse)?.userText

        if let answer = Buttons.answer(to: response.actionIdentifier, typed: typed, userInfo: userInfo) {
            await MainActor.run { onAnswer(answer) }
        }
    }
}

private extension UNAlertStyle {
    var style: NoticeLeave.Style {
        switch self {
        case .banner: .banners
        case .alert: .alerts
        default: .none
        }
    }
}

private extension UNAuthorizationStatus {
    var words: String {
        switch self {
        case .notDetermined: "not asked"
        case .denied: "denied"
        case .authorized: "allowed"
        case .provisional: "provisional"
        case .ephemeral: "ephemeral"
        @unknown default: "unknown (\(rawValue))"
        }
    }
}
