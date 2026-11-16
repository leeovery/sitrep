import AppKit
import os
import SitRepCore
import SitRepRelay

/// The notices helper as an app, as Banners asks of it.
@MainActor
protocol HelperStarting: AnyObject {
    /// Started where none is running, or the one running found, and watched for ending; nothing while one is opening
    /// or watched.
    func open()
    /// The pid of the helper watched, while it runs.
    var watched: Int32? { get }
    func isRunning(_ pid: Int32) -> Bool
}

/// What HelperApp asks of macOS: a seam, as a test starts no app.
struct HelperMac {
    /// The pid of a helper running, if any.
    var running: @MainActor () -> Int32?
    /// The helper started, or the one running found: its pid.
    var open: @MainActor () async throws -> Int32
    /// A watch on the app with this pid, held for as long as it watches, telling `ended` once the app ends.
    var watch: @MainActor (_ pid: Int32, _ ended: @escaping @MainActor () -> Void) -> AnyObject?
    var isRunning: @MainActor (Int32) -> Bool
}

/// The notices helper as an app: started where it is not running, once at a time, and watched for ending. Opened
/// where it runs already, as when one says it listens, it is the one running that is watched; while another is watched,
/// only once that one's end is told.
@MainActor
final class HelperApp: HelperStarting {
    /// A helper that ended: its pid, and whether it was running before SitRep opened it, as one left from the SitRep
    /// before, rather than one this SitRep started.
    struct End: Equatable {
        let pid: Int32
        let wasRunning: Bool
    }

    var ended: (End) -> Void = { _ in }
    private(set) var watched: Int32?
    private let mac: HelperMac
    private let logger = Logger(sitrep: "banner")
    /// Whether an open is under way.
    private(set) var isOpening = false
    private var watch: AnyObject?

    init(_ mac: HelperMac) {
        self.mac = mac
    }

    func open() {
        guard !isOpening, watched == nil else {
            return
        }

        isOpening = true

        let wasRunning = mac.running() != nil

        Task {
            defer { isOpening = false }
            do {
                watching(try await mac.open(), wasRunning: wasRunning)
            } catch {
                logger.error("Notices helper not started: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func isRunning(_ pid: Int32) -> Bool {
        mac.isRunning(pid)
    }

    private func watching(_ pid: Int32, wasRunning: Bool) {
        watched = pid
        watch = mac.watch(pid) { [weak self] in self?.end(End(pid: pid, wasRunning: wasRunning)) }
    }

    /// Told for the helper watched alone: the end of one watched before, told late, is passed over.
    private func end(_ end: End) {
        guard end.pid == watched else {
            return
        }

        watched = nil
        watch = nil
        ended(end)
    }
}

extension HelperMac {
    /// The helper in this bundle, under this bundle id, as macOS runs it.
    static func live(_ bundle: URL, id: String) -> HelperMac {
        HelperMac(
            running: {
                NSRunningApplication.runningApplications(withBundleIdentifier: id).first { !$0.isTerminated }?
                    .processIdentifier
            },
            open: { try await Apps.open(bundle).processIdentifier },
            watch: { pid, ended in
                guard let app = NSRunningApplication(processIdentifier: pid) else {
                    Task { ended() }

                    return nil
                }

                return EndWatch(app, ended: ended)
            },
            isRunning: { pid in NSRunningApplication(processIdentifier: pid).map { !$0.isTerminated } ?? false }
        )
    }
}
