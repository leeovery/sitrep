import AppKit
import os
import ServiceManagement
import SitRepCore
import SitRepMenu

/// What macOS lets SitRep do, read for Settings and changed only where Lee chooses: starting at login, and the leave
/// to control Ghostty, which the CLI's first jump asks for.
@MainActor
enum Leaves {
    private static let loginLog = Logger(sitrep: "login")

    /// Starting at login, from the login item's real status.
    static var login: LoginItem {
        let status = SMAppService.mainApp.status

        loginLog.info("Login item: \(status.words, privacy: .public)")

        return LoginItem(status)
    }

    /// Lee flipped Open at login: it starts or stops, or, where macOS waits on his approval, System Settings' Login
    /// Items opens for it. What macOS refused is said in a banner.
    static func chooseLogin(_ banners: Banners) {
        let service = SMAppService.mainApp

        do {
            switch LoginItem(service.status).choice {
            case .register:
                try service.register()
            case .unregister:
                try service.unregister()
            case .openSettings:
                break
            }
        } catch {
            loginLog.error("Login item unchanged: \(error.localizedDescription, privacy: .public)")
            Task { await banners.post(.refused("SitRep could not change starting at login", error.localizedDescription)) }
        }

        let status = service.status

        loginLog.info("Login item now: \(status.words, privacy: .public)")
        if status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    /// Whether SitRep may control Ghostty, asked of macOS without asking Lee, off the main thread.
    static func ghostty() async -> GhosttyLeave {
        await Task.detached {
            guard let ghostty = NSAppleEventDescriptor(bundleIdentifier: "com.mitchellh.ghostty").aeDesc else {
                return GhosttyLeave.unknown
            }

            return GhosttyLeave(AEDeterminePermissionToAutomateTarget(
                ghostty, AEEventClass(typeWildCard), AEEventID(typeWildCard), false
            ))
        }.value
    }

    /// System Settings, where Lee changes what macOS lets SitRep do.
    enum Place: String {
        case notifications = "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.leeovery.sitrep"
        case automation = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    }

    static func open(_ place: Place) {
        if let url = URL(string: place.rawValue) {
            NSWorkspace.shared.open(url)
        }
    }
}
