import os
import SitRepRelay
import UserNotifications

/// macOS banners: silent, since SitRep plays its own sound for a new ask, and shown even while the helper counts as
/// the active app, as it does once a click activates it. A click on one's body is told to `onClick`, with the
/// session it names, if any.
@MainActor
final class Notifications: NSObject, Notifying, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let poster = Poster(center: LiveCenter())
    private let logger = Logger(helper: "banner")
    private var onClick: (String?) -> Void = { _ in }

    /// Clicks told to `onClick` from now on, and no banner buttons: macOS keeps the categories a build registered
    /// until another registers its own, so the buttons of the builds that answered from a banner (#203 to #206) would
    /// show on a banner still, and a press on one go nowhere.
    func listen(onClick: @escaping (String?) -> Void) {
        self.onClick = onClick
        center.delegate = self
        center.setNotificationCategories([])
    }

    func post(_ notice: Notice) async {
        guard await isAllowed() else {
            return logger.notice("Banner not shown, as banners are not allowed: \(notice.body, privacy: .public)")
        }

        await poster.post(notice)
    }

    func clear(ask: String, session: String) async {
        await poster.clear(ask: ask, session: session)
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

        let work = BannerInfo.work(response.notification.request.content.userInfo)

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
