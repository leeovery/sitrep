import os
import SitRepRelay
import UserNotifications

/// macOS banners: silent, since SitRep plays its own sound for a new ask, and shown even while the helper counts as
/// the active app, as it does once a click activates it. A click on one's body is told to `onClick`, with the
/// session it names, if any.
@MainActor
final class Notifications: NSObject, Notifying, UNUserNotificationCenterDelegate {
    /// The userInfo key carrying the id of the work a banner jumps to.
    private nonisolated static let workKey = "work"

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(helper: "banner")
    private var onClick: (String?) -> Void = { _ in }

    func listen(onClick: @escaping (String?) -> Void) {
        self.onClick = onClick
        center.delegate = self
    }

    func post(_ notice: Notice) async {
        guard await isAllowed() else {
            return logger.notice("Banner not shown, as banners are not allowed: \(notice.body, privacy: .public)")
        }

        let content = UNMutableNotificationContent()

        content.title = notice.title
        content.subtitle = notice.subtitle ?? ""
        content.body = notice.body
        content.userInfo = notice.work.map { [Self.workKey: $0] } ?? [:]

        do {
            try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        } catch {
            logger.error("Banner not posted: \(error.localizedDescription, privacy: .public)")
        }
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

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            return
        }

        let work = response.notification.request.content.userInfo[Self.workKey] as? String

        await MainActor.run { onClick(work) }
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
