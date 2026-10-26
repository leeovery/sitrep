import AppKit
import os
import SitRepRelay

/// SitRep's notices helper: a windowless app inside SitRep.app that posts SitRep's banners, so a click on one
/// activates it rather than SitRep (DESIGN, "The menu bar").
@main
enum NoticesApp {
    @MainActor
    static func main() {
        guard let id = Bundle.main.bundleIdentifier else {
            Logger(helper: "notices").error("No bundle id: the helper runs only in SitRep.app")
            exit(1)
        }

        let app = NSApplication.shared
        let delegate = NoticesDelegate(helper: id)

        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class NoticesDelegate: NSObject, NSApplicationDelegate {
    private let notifications = Notifications()
    private let relay: Relay<ToSitRep, ToHelper>
    private let helper: Helper

    init(helper id: String) {
        let relay = Relay<ToSitRep, ToHelper>(helper: id)

        self.relay = relay
        helper = Helper(
            notifications: notifications, sitRep: OwnSitRep(), send: relay.send, quit: { NSApp.terminate(nil) }
        )
    }

    /// Clicks are listened to before launching ends, so the click that starts the helper is heard.
    func applicationWillFinishLaunching(_ notification: Notification) {
        notifications.listen { [helper] in helper.clicked($0) }
        relay.listen { [helper] in helper.heard($0) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { [helper] in await helper.start() }
    }
}

extension Logger {
    /// SitRep's own log, as SitRep's `Logger(sitrep:)` makes it, which lives where the helper does not link.
    init(helper category: String) {
        self.init(subsystem: "com.leeovery.sitrep", category: category)
    }
}

/// The SitRep.app the helper sits in, three folders up from its own bundle.
@MainActor
final class OwnSitRep: SitRepApp {
    private let bundle = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    private let logger = Logger(helper: "notices")
    private var watch: EndWatch?

    func running() -> Int32? {
        guard let id = Bundle(url: bundle)?.bundleIdentifier else {
            return nil
        }

        return NSRunningApplication.runningApplications(withBundleIdentifier: id).first { !$0.isTerminated }?
            .processIdentifier
    }

    func launch() async -> Int32? {
        do {
            return try await Apps.open(bundle).processIdentifier
        } catch {
            logger.error("SitRep not started: \(error.localizedDescription, privacy: .public)")

            return nil
        }
    }

    func watch(_ pid: Int32, ended: @escaping @MainActor () -> Void) {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return ended()
        }

        watch = EndWatch(app, ended: ended)
    }
}
