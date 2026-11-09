import AppKit

/// A running app, by its bundle, as LaunchServices brings it forward.
public struct RunningApp: Sendable, Hashable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}

/// The Mac's apps, as a jump sees them: which is in front, each as it comes to the front, which run, and bringing one
/// forward. The real one is NSWorkspace's (`MacWorkspace`); the tests' plays a Mac of their own.
public protocol Workspace: Sendable {
    /// The app in front now, by its bundle id; nil where none is told.
    func frontmost() async -> String?
    /// Hears each app as it comes to the front, by its bundle id, nil for one with none, from now until the listening
    /// ends.
    func listen(_ heard: @escaping @Sendable (String?) -> Void) -> any Listening
    /// The first of the bundle ids given whose app is running; nil for none.
    func running(_ bundles: [String]) async -> RunningApp?
    /// The app running from the bundle at the path; nil for none.
    func running(at path: String) async -> RunningApp?
    /// Brings a running app forward through LaunchServices, as `open` does, sending it no Apple Event: whether it came.
    func bringForward(_ app: RunningApp) async -> Bool
}

/// Listening to the front, until ended.
public protocol Listening: Sendable {
    func end()
}

/// How long bringing an app forward may take, as the CLI's `open` had, so a LaunchServices not answering never holds a
/// jump.
let forwardLimit = Duration.seconds(2)

extension Workspace {
    /// Brings a running app forward within its limit: whether it came.
    func bringForward(_ app: RunningApp, on clock: any JumpClock) async -> Bool {
        await answer(within: forwardLimit, on: clock) { await bringForward(app) } ?? false
    }
}

/// The Mac's own apps, through NSWorkspace and NSRunningApplication. An app is found running before it is brought
/// forward, never launched: LaunchServices launches one that is not running.
public struct MacWorkspace: Workspace {
    public init() {}

    public func frontmost() async -> String? {
        await MainActor.run { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
    }

    /// NSWorkspace posts each activation on the main thread, where it is heard at once.
    public func listen(_ heard: @escaping @Sendable (String?) -> Void) -> any Listening {
        let center = NSWorkspace.shared.notificationCenter

        return Observing(center: center, center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil
        ) { activated in
            heard((activated.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier)
        })
    }

    public func running(_ bundles: [String]) async -> RunningApp? {
        bundles.lazy.compactMap { bundle in
            NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first { !$0.isTerminated }?.bundleURL
        }.first.map(RunningApp.init)
    }

    public func running(at path: String) async -> RunningApp? {
        let wanted = Self.folder(path)

        return await MainActor.run {
            NSWorkspace.shared.runningApplications.lazy.compactMap(\.bundleURL).first {
                Self.folder($0.path(percentEncoded: false)) == wanted
            }
        }.map(RunningApp.init)
    }

    /// A folder's path without the slash a bundle's URL ends in.
    private static func folder(_ path: String) -> String {
        path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    /// LaunchServices sends a running app the reopen event, which makes one with no window open one; that does not
    /// happen here, as a live window of the session is in the app. A jump is no opening of Lee's: the app is not added
    /// to his recent items.
    public func bringForward(_ app: RunningApp) async -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()

        configuration.addsToRecentItems = false
        return (try? await NSWorkspace.shared.openApplication(at: app.url, configuration: configuration)) != nil
    }
}

/// An observer of NSWorkspace's activations, removed as the listening ends. The token is never changed once made, and
/// a notification center removes an observer from any thread.
private final class Observing: Listening, @unchecked Sendable {
    private let center: NotificationCenter
    private let token: any NSObjectProtocol

    init(center: NotificationCenter, _ token: any NSObjectProtocol) {
        self.center = center
        self.token = token
    }

    func end() {
        center.removeObserver(token)
    }
}
