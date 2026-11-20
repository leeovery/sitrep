import Foundation
import os
import SitRepCore
import SitRepPanel

/// `snooze.json`, Snooze's choices as Lee set them, for the pane in Claude Code to offer the same (DESIGN, "Storage"):
/// at the top of the board's folder, which SitRep alone writes.
public struct SnoozeFile: Sendable {
    public static let name = "snooze.json"

    public let url: URL

    private static let logger = Logger(sitrep: "settings")

    public init(url: URL) {
        self.url = url
    }

    /// In the board's folder (`BoardFolder`), so the file sits by the board SitRep shows.
    public init(environment: [String: String], home: URL) {
        self.init(url: BoardFolder.url(environment: environment, home: home).appending(path: Self.name))
    }

    /// Where this Mac's SitRep writes it.
    public static var live: SnoozeFile {
        SnoozeFile(environment: ProcessInfo.processInfo.environment, home: FileManager.default.homeDirectoryForCurrentUser)
    }

    /// The file's text: the settings as JSON, its keys sorted, so the same settings are always the same bytes.
    public static func text(_ settings: SnoozeSettings) throws -> Data {
        let encoder = JSONEncoder()

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(settings)
    }

    /// The settings written whole: beside the file, then renamed over it, so a reader never sees half a file; its
    /// folder made where it is not there yet. A failure is logged, and the pane keeps what it last read.
    public func write(_ settings: SnoozeSettings) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.text(settings).write(to: url, options: .atomic)
        } catch {
            Self.logger.error("\(Self.name, privacy: .public) was not written: \(error, privacy: .public)")
        }
    }
}
