import AppKit

/// SitRep's notices helper, as SitRep and app/bundle know it.
public enum NoticeHelper {
    /// Its bundle id: SitRep's, and this. app/bundle gives it the same.
    public static func id(of sitRep: String) -> String {
        "\(sitRep).notices"
    }

    /// Where it sits in SitRep.app, as app/bundle puts it.
    public static let place = "Contents/Helpers/SitRepNotices.app"
}

/// The other app of the two, SitRep or its helper, opened from its bundle: never activated, kept out of the recent
/// items, and the one already running when it is.
@MainActor
public enum Apps {
    public static func open(_ bundle: URL) async throws -> NSRunningApplication {
        let configuration = NSWorkspace.OpenConfiguration()

        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = false

        return try await NSWorkspace.shared.openApplication(at: bundle, configuration: configuration)
    }
}

/// Told once a running app ends, however it ends, as its `isTerminated` says; at once for one ended already.
@MainActor
public final class EndWatch {
    /// Held for as long as it is observed: an app freed while observed crashed SitRep and the helper as they started.
    private let app: NSRunningApplication
    private let observation: NSKeyValueObservation

    public init(_ app: NSRunningApplication, ended: @escaping @MainActor () -> Void) {
        self.app = app
        observation = app.observe(\.isTerminated, options: [.initial, .new]) { app, _ in
            if app.isTerminated {
                Task { @MainActor in ended() }
            }
        }
    }

    /// Observing stopped before the app is let go: left to the order its properties are released in, the app went
    /// first and was freed still observed.
    deinit {
        observation.invalidate()
    }
}
