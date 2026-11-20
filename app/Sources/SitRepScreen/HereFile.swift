import Foundation
import os
import SitRepCore

/// `here.json` (DESIGN, "Storage"): the sessions a window holds that no terminal on this Mac shows, as the read of here
/// leaves them (`HereWatch`), for the board in a terminal to draw away as the notch does. At the top of the board's
/// folder. While any session is dimmed it is written at every read and every line, so its time says SitRep is still
/// reading; once none is, it is removed, once, so a Mac where every session shows writes nothing; and it is removed as
/// SitRep quits. No file means every held session is here to core's reader, as a file `HERE_STALE_MS` old does, which
/// covers a SitRep that crashed, hung or was napped.
public struct HereFile: Sendable {
    public static let name = "here.json"

    public let url: URL

    /// The writes and the removals, one at a time and in the order given, off the caller's thread: internal only for the
    /// tests, which hold it up.
    let queue = DispatchQueue(label: "sitrep.here-file")

    /// What the queue knows, touched on it alone.
    private let state = OSAllocatedUnfairLock(initialState: Standing())

    private let log: @Sendable (String) -> Void

    private static let logger = Logger(sitrep: "here")

    /// Whether a file may stand, this run's or one left by a run before, so an empty read removes it; and whether the
    /// last write failed, so a failure is logged once until a write succeeds.
    private struct Standing {
        var mayStand = true
        var isFailing = false
    }

    /// A file at `url`, its first failure in a row told to `log`.
    init(url: URL, log: @escaping @Sendable (String) -> Void) {
        self.url = url
        self.log = log
    }

    public init(url: URL) {
        self.init(url: url) { Self.logger.error("\($0, privacy: .public)") }
    }

    /// In the board's folder (`BoardFolder`), so the file sits by the board SitRep shows.
    public init(environment: [String: String], home: URL) {
        self.init(url: BoardFolder.url(environment: environment, home: home).appending(path: Self.name))
    }

    /// Where this Mac's SitRep writes it.
    public static var live: HereFile {
        HereFile(environment: ProcessInfo.processInfo.environment, home: FileManager.default.homeDirectoryForCurrentUser)
    }

    /// The file's text: the sessions in order, and the time in whole milliseconds since the epoch, as JSON with its keys
    /// sorted, so the same read at the same time is always the same bytes.
    public static func text(_ notHere: Set<String>, at time: Date) throws -> Data {
        let encoder = JSONEncoder()

        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(
            Contents(at: Int((time.timeIntervalSince1970 * 1000).rounded(.down)), notHere: notHere.sorted(), v: 1)
        )
    }

    /// The read written whole: beside the file, then renamed over it, so a reader never sees half a file. Only into the
    /// board's folder as it stands, which the board makes. A write that fails leaves things as they were, the next read
    /// writing again; the first of a run of failures is logged, and no other until a write succeeds.
    public func write(_ notHere: Set<String>, at time: Date) {
        do {
            try Self.text(notHere, at: time).write(to: url, options: .atomic)
            state.withLock { $0 = Standing(mayStand: true, isFailing: false) }
        } catch {
            let isFirst = state.withLock { standing in
                defer { standing = Standing(mayStand: true, isFailing: true) }
                return !standing.isFailing
            }

            if isFirst {
                log("\(Self.name) was not written: \(error)")
            }
        }
    }

    /// Each settling of the read, off the caller's thread, after every one posted before it: written while any session
    /// is dimmed; removed as none is, once, where a file may stand.
    public func post(_ notHere: Set<String>, at time: Date) {
        queue.async { [self] in
            if !notHere.isEmpty {
                write(notHere, at: time)
            } else if state.withLock({ $0.mayStand }) {
                removeNow()
            }
        }
    }

    /// The file removed, as SitRep quits, once every write posted before it is done; waited on up to `limit`, so a write
    /// hung on its volume never holds quitting up, a file left behind going stale. A file not there is no failure.
    public func remove(within limit: DispatchTimeInterval = .seconds(1)) {
        let removed = DispatchSemaphore(value: 0)

        queue.async { [self] in
            removeNow()
            removed.signal()
        }
        _ = removed.wait(timeout: .now() + limit)
    }

    /// Returns once everything posted before it is done: for the tests.
    func flush() {
        queue.sync {}
    }

    private func removeNow() {
        try? FileManager.default.removeItem(at: url)
        state.withLock { $0.mayStand = false }
    }

    /// The file's shape, as core's `notHereOf` reads it.
    private struct Contents: Encodable {
        let at: Int
        let notHere: [String]
        let v: Int
    }
}

extension HereWatch {
    /// `here.json` kept in step with every settling of `notHere`, at each line and each read, stamped as `now` says.
    public func writes(to file: HereFile, now: @escaping () -> Date = Date.init) {
        settled = { notHere in file.post(notHere, at: now()) }
    }
}
