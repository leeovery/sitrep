import os

/// What the views show of the board: the last one `sitrep watch` printed,
/// and why it is stale, while it is. It is kept while `watch` is down, so
/// the views keep showing it, marked as stale, until a run prints anew.
public struct LastBoard: Sendable, Equatable {
    /// Nil until `watch` prints its first line, while the views say they are looking.
    public private(set) var board: Board?
    /// Why the board is not the board as it stands; nil while `watch` runs and reads.
    public private(set) var stale: Stale?

    private static let logger = Logger(sitrep: "watch")

    public init() {}

    /// Takes what a run of `watch` said; whether that changed what the views show.
    mutating func hear(_ heard: Heard) -> Bool {
        let was = self

        switch heard {
        case let .line(line):
            read(line)
        case let .exited(status, stderr):
            stale = .exited(status: status, said: Said(stderr).last)
        case let .unstartable(reason):
            stale = .unstartable(reason)
        }

        return self != was
    }

    /// A line read is the board; one that is not is skipped, the board
    /// kept, and stale until a line reads, as `watch` will most likely print
    /// no other kind until it or the app is updated.
    private mutating func read(_ line: String) {
        do {
            board = try Board.read(line)
            stale = nil
        } catch {
            Self.logger.error("sitrep watch \(error, privacy: .public): \(line.prefix(200), privacy: .public)")
            stale = .unread(error)
        }
    }
}

/// Why the board kept is not the board as it stands.
public enum Stale: Sendable, Equatable, CustomStringConvertible {
    /// `watch` ended, saying what it last said of its own, if anything.
    case exited(status: Int32, said: String?)
    case unstartable(String)
    /// `watch` printed a line this app cannot read.
    case unread(Unread)

    /// Why, in plain words, for "SitRep can't read the board".
    public var description: String {
        switch self {
        case let .exited(status, said):
            said ?? "sitrep watch ended with status \(status)."
        case let .unstartable(reason):
            "sitrep watch \(RunError.unstartable(reason))."
        case let .unread(unread):
            "sitrep watch \(unread)."
        }
    }
}
