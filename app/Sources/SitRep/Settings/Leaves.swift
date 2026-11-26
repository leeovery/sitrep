import AppKit
import os
import ServiceManagement
import SitRepCore
import SitRepMenu
import SitRepScreen

/// What macOS lets SitRep do, read for Settings and the welcome and changed only where Lee chooses: starting at login,
/// and the leave to control Ghostty, which SitRep's first jump to a Ghostty window asks for, or Allow… before it,
/// Ghostty opened for it.
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
            banners.post(.refused("SitRep could not change starting at login", error.localizedDescription))
        }

        let status = service.status

        loginLog.info("Login item now: \(status.words, privacy: .public)")
        if status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    /// Whether SitRep may control Ghostty, asked of macOS without asking Lee, off the main thread.
    static func ghostty() async -> GhosttyLeave {
        await ghosttyLeave(asking: false)
    }

    /// Allow…, before macOS has asked: macOS's own prompt, and what Lee chose.
    static func allowGhostty() async -> GhosttyLeave {
        await ghosttyLeave(asking: true)
    }

    /// Whether Ghostty is installed, as Launch Services finds it.
    static var ghosttyInstalled: Bool {
        ghosttyApp != nil
    }

    private static var ghosttyApp: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: GhosttyDriver.bundle)
    }

    /// Whether Ghostty runs, so macOS can ask for the leave to control it.
    static var ghosttyRuns: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: GhosttyDriver.bundle).isEmpty
    }

    /// Ghostty opened behind the window Lee is in, for macOS to ask for the leave, and what that came to: running once
    /// it has finished launching; not opened if it fails to, or is still launching after five seconds; at once, not
    /// installed.
    static func openGhostty() async -> GhosttyOpening {
        guard let app = ghosttyApp else {
            return .notInstalled
        }

        let configuration = NSWorkspace.OpenConfiguration()

        configuration.activates = false
        guard let ghostty = try? await NSWorkspace.shared.openApplication(at: app, configuration: configuration) else {
            return .didNotOpen
        }

        let deadline = ContinuousClock.now + .seconds(5)

        while !ghostty.isFinishedLaunching, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return ghostty.isFinishedLaunching ? .runs : .didNotOpen
    }

    /// The leave, for a harmless event, Get Data: macOS gives it for Ghostty, whatever the event. Off the main thread,
    /// which a prompt would hold up. The descriptor is held for the call, as its `aeDesc` points into it.
    private static func ghosttyLeave(asking: Bool) async -> GhosttyLeave {
        await Task.detached {
            let ghostty = NSAppleEventDescriptor(bundleIdentifier: GhosttyDriver.bundle)

            return withExtendedLifetime(ghostty) {
                guard let target = ghostty.aeDesc else {
                    return GhosttyLeave.unknown
                }

                return GhosttyLeave(AEDeterminePermissionToAutomateTarget(
                    target, AEEventClass(kAECoreSuite), AEEventID(kAEGetData), asking
                ))
            }
        }.value
    }

    /// Whether macOS gives SitRep the Accessibility leave the notch's panel takes keys with.
    static var keys: Bool {
        AXIsProcessTrusted()
    }

    /// Allow…, for the Accessibility leave: macOS's own prompt, which leads to System Settings, and whether the leave
    /// is given now, which macOS answers before Lee does.
    static func allowKeys() -> Bool {
        // the option by its name: `kAXTrustedCheckOptionPrompt` is a global var, which Swift 6 refuses to read
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// System Settings, where Lee changes what macOS lets SitRep do: the notices helper's page in Notifications, which
    /// it lists as SitRep, Automation, Accessibility, and Login Items, which macOS opens itself.
    enum Place {
        case notifications, automation, accessibility, loginItems
    }

    static func open(_ place: Place) {
        switch place {
        case .notifications: open("x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(Banners.helper)")
        case .automation: open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
        case .accessibility: open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .loginItems: SMAppService.openSystemSettingsLoginItems()
        }
    }

    private static func open(_ address: String) {
        if let url = URL(string: address) {
            NSWorkspace.shared.open(url)
        }
    }
}
