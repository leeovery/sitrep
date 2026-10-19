import Foundation
import os

/// What the views show of the board: the last one `sitrep watch` printed,
/// and why it is stale, while it is. It is kept while `watch` is down, so
/// the views keep showing it, marked as stale, until a run prints anew.
public struct LastBoard: Sendable, Equatable {
    /// Nil until `watch` prints its first line, while the views say they are looking.
    public private(set) var board: Board?
    /// Why the board is not the board as it stands; nil while `watch` runs and reads.
    public private(set) var stale: Stale?
    /// When the board stopped being known current: when `watch` was heard
    /// ending, failing to start or printing a line that does not read. The
    /// views say "as of" it, not `board.at`: `watch` prints only on a change,
    /// so the last line may be hours older.
    public private(set) var staleSince: Date?
    /// The board is a run's first after another run: its `new` and
    /// `changed` are empty, as on every run's first line, though the board
    /// may have moved between the runs, so a view reads what it shows again
    /// in full. True only as the board comes.
    public private(set) var isResumed = false

    private var runs = 0
    private var isRunsFirst = false

    public init() {}

    /// A run of `watch` starts.
    mutating func begin() {
        runs += 1
        isRunsFirst = true
    }

    /// Takes what a run of `watch` said, heard at the instant given; whether
    /// that changed what the views show.
    mutating func hear(_ heard: Heard, at instant: Date) -> Bool {
        let was = self

        isResumed = false

        switch heard {
        case let .line(line):
            read(line, at: instant)
        case let .exited(exit, stderr):
            goStale(.exited(exit, said: Said(stderr).reason), at: instant)
        case let .unstartable(reason):
            goStale(.unstartable(reason), at: instant)
        }

        return self != was
    }

    /// A line read is the board; one that is not is skipped, the board
    /// kept, and stale until a line reads, as `watch` will most likely print
    /// no other kind until it or the app is updated.
    private mutating func read(_ line: String, at instant: Date) {
        do {
            board = try Board.read(line)
            stale = nil
            staleSince = nil
            isResumed = isRunsFirst && runs > 1
            isRunsFirst = false
        } catch {
            Logger.watch.error("sitrep watch \(error, privacy: .public): \(line.prefix(200), privacy: .public)")
            goStale(.unread(error), at: instant)
        }
    }

    /// Stale for the reason given, since it first went stale.
    private mutating func goStale(_ why: Stale, at instant: Date) {
        stale = why
        staleSince = staleSince ?? instant
    }
}

/// Why the board kept is not the board as it stands.
public enum Stale: Sendable, Equatable, CustomStringConvertible {
    /// `watch` ended, saying what ended it, if anything.
    case exited(Exit, said: String?)
    case unstartable(String)
    /// `watch` printed a line this app cannot read.
    case unread(Unread)

    /// Why, in plain words, a sentence, for "SitRep can't read the board".
    public var description: String {
        let why = switch self {
        case let .exited(_, said?):
            said
        case .exited(.status(0), nil):
            "sitrep watch ended"
        case let .exited(.status(status), nil):
            "sitrep watch ended with status \(status)"
        case let .exited(.signal(signal), nil):
            "sitrep watch was stopped (signal \(signal))"
        case let .unstartable(reason):
            "sitrep watch \(RunError.unstartable(reason))"
        case let .unread(unread):
            "sitrep watch \(unread)"
        }

        return why.last.map(".!?".contains) == true ? why : "\(why)."
    }
}
