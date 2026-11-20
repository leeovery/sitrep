import Foundation
import SitRepCore

/// `here.json` (DESIGN, "Storage"): the sessions a window holds that no terminal on this Mac shows, as each read of here
/// leaves them (`HereWatch`), for the board in a terminal to draw away as the notch does. At the top of the board's
/// folder; written at every read, changed or not, so its time says SitRep is still reading, and removed as SitRep quits.
/// Core's reader takes a file 10 seconds old for none (`HERE_STALE_MS`), so a SitRep gone without removing it leaves no
/// session dimmed for long.
public struct HereFile: Sendable {
    public static let name = "here.json"

    public let url: URL

    /// The writes and the removal, one at a time and in the order given, off the caller's thread.
    private let queue = DispatchQueue(label: "sitrep.here-file")

    public init(url: URL) {
        self.url = url
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
    /// board's folder as it stands, which the board makes; a write that fails leaves things as they were and says
    /// nothing, the next read writing again.
    public func write(_ notHere: Set<String>, at time: Date) {
        try? Self.text(notHere, at: time).write(to: url, options: .atomic)
    }

    /// The read written off the caller's thread, after every write posted before it.
    public func post(_ notHere: Set<String>, at time: Date) {
        queue.async { [self] in
            write(notHere, at: time)
        }
    }

    /// The file removed, once every write posted before it is done, so none comes after it. A file not there is no
    /// failure.
    public func remove() {
        queue.sync {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// The file's shape, as core's `notHereOf` reads it.
    private struct Contents: Encodable {
        let at: Int
        let notHere: [String]
        let v: Int
    }
}
