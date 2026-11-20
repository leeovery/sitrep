import Foundation
import os
import SitRepCore

/// `here.json` (DESIGN, "Storage"): who views each held session and each multiplexer tty, as the read of here leaves
/// them (`HereWatch`), for the board in a terminal to draw hollow what is open on no device it is looked at from. At the
/// top of the board's folder. Written at once as what it says changes, and otherwise at most every `refresh`, so its
/// time says SitRep is still reading; removed, once, as no session is read, nothing held among it, and as SitRep quits.
/// No file means every held session is filled to core's reader, as a file `HERE_STALE_MS` old does, which covers a
/// SitRep that crashed, hung or was napped.
public struct HereFile: Sendable {
    public static let name = "here.json"

    /// The longest a file saying the same stands before it is written again, its time made fresh: a third of core's
    /// `HERE_STALE_MS`, so a reading SitRep's file is never stale, with its 3 seconds' read stretched by App Nap.
    public static let refresh: TimeInterval = 10

    public let url: URL

    /// The writes and the removals, one at a time and in the order given, off the caller's thread: internal only for the
    /// tests, which hold it up.
    let queue = DispatchQueue(label: "sitrep.here-file")

    /// What the queue knows, touched on it alone.
    private let state = OSAllocatedUnfairLock(initialState: Standing())

    private let log: @Sendable (String) -> Void

    private static let logger = Logger(sitrep: "here")

    /// Whether a file may stand, this run's or one left by a run before, so an empty read removes it; whether the last
    /// write failed, so a failure is logged once until a write succeeds; and what the last write that stands wrote, and
    /// when.
    private struct Standing {
        var mayStand = true
        var isFailing = false
        var written: (sightings: Sightings, at: Date)?
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

    /// The file's text: the time in whole milliseconds since the epoch, and each session's and tty's viewers as
    /// `Viewer.text` words them, in order, as JSON with its keys sorted and its slashes as they are, so the same read at
    /// the same time is always the same bytes.
    public static func text(_ sightings: Sightings, at time: Date) throws -> Data {
        let encoder = JSONEncoder()

        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(
            Contents(
                at: Int((time.timeIntervalSince1970 * 1000).rounded(.down)),
                sessions: sightings.sessions.mapValues(texts), ttys: sightings.ttys.mapValues(texts), v: 2
            )
        )
    }

    private static func texts(_ viewers: Set<Viewer>) -> [String] {
        viewers.map(\.text).sorted()
    }

    /// The read written whole: beside the file, then renamed over it, so a reader never sees half a file. Only into the
    /// board's folder as it stands, which the board makes. A write that fails leaves things as they were, the next
    /// settling writing again; the first of a run of failures is logged, and no other until a write succeeds.
    public func write(_ sightings: Sightings, at time: Date) {
        do {
            try Self.text(sightings, at: time).write(to: url, options: .atomic)
            state.withLock { $0 = Standing(mayStand: true, isFailing: false, written: (sightings, time)) }
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

    /// Each settling of the read, off the caller's thread, after every one posted before it: written where it changed
    /// what the file says, or the file is `refresh` old, either side of its time, as a clock set back leaves it; removed
    /// as no session is read, once, where a file may stand.
    public func post(_ sightings: Sightings, at time: Date) {
        queue.async { [self] in
            if sightings.sessions.isEmpty {
                if state.withLock({ $0.mayStand }) {
                    removeNow()
                }
            } else if isDue(sightings, at: time) {
                write(sightings, at: time)
            }
        }
    }

    private func isDue(_ sightings: Sightings, at time: Date) -> Bool {
        state.withLock { standing in
            guard let written = standing.written else {
                return true
            }

            return written.sightings != sightings || abs(time.timeIntervalSince(written.at)) >= Self.refresh
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
        state.withLock { $0 = Standing(mayStand: false, isFailing: $0.isFailing) }
    }

    /// The file's shape, as core's `sightingsOf` reads it.
    private struct Contents: Encodable {
        let at: Int
        let sessions: [String: [String]]
        let ttys: [String: [String]]
        let v: Int
    }
}

extension HereWatch {
    /// `here.json` kept in step with every settling of `sightings`, at each line and each read, stamped as `now` says.
    public func writes(to file: HereFile, now: @escaping () -> Date = Date.init) {
        settled = { sightings in file.post(sightings, at: now()) }
    }
}
