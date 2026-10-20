import os
import SitRepCore
import SitRepMenu
import UserNotifications

/// macOS banners: silent, since each Claude window's own chime already
/// plays, and shown even while SitRep counts as the active app. Clicking one
/// that names a work jumps to it.
@MainActor
final class Banners: NSObject, UNUserNotificationCenterDelegate {
    /// The userInfo key carrying the id of the work a banner jumps to.
    private nonisolated static let workKey = "work"

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(sitrep: "banner")
    private var onClick: (String) -> Void = { _ in }

    func listen(onClick: @escaping (String) -> Void) {
        self.onClick = onClick
        center.delegate = self
    }

    func post(_ banner: Banner) async {
        guard await isAllowed() else {
            return logger.notice("Banner not shown, as banners are not allowed: \(banner.body, privacy: .public)")
        }

        let content = UNMutableNotificationContent()

        content.title = banner.title
        content.subtitle = banner.subtitle ?? ""
        content.body = banner.body
        content.userInfo = banner.work.map { [Self.workKey: $0] } ?? [:]

        do {
            try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        } catch {
            logger.error("Banner not posted: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// What macOS lets SitRep do with notifications, as its own settings say.
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

    /// Asks macOS for leave to show banners, unless Lee has answered already.
    func ask() async {
        _ = await isAllowed()
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
        guard
            response.actionIdentifier == UNNotificationDefaultActionIdentifier,
            let work = response.notification.request.content.userInfo[Self.workKey] as? String
        else {
            return
        }

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
