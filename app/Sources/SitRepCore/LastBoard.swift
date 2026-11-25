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
    /// The line just heard is its run's first, the first run's among them,
    /// whether or not it read: a run's first line has no `new`, and what it
    /// shows counts as shown, so only a later line's `new` is news. True only
    /// as the line comes.
    public private(set) var isRunsFirst = false
    /// The sessions the line just heard moved into Lee's turn, by their ids
    /// (`turnsEnded`). Only as the line comes, as `isRunsFirst` is.
    public private(set) var newTurns: Set<String> = []
    /// The asks that waited on Lee on the board kept and wait on him no more on the line just heard: answered, ignored,
    /// commented on, resolved, or gone with their session, so their banners go. Only as the line comes, as `newTurns`
    /// is; a restarted run's first line among them, against the board the last run left, as asks may have left
    /// between the runs.
    public private(set) var asksLeft: Set<AskOf> = []
    /// The asks that waited on Lee on the board kept and still wait on him on the line just heard, edited meanwhile:
    /// their title, their yes, their options or what they want, so their banners go, which tell of what the ask no
    /// longer asks. Only as the line comes, as `asksLeft` is, and by the same rules.
    public private(set) var asksChanged: Set<AskOf> = []

    /// A run has started and nothing it printed has been heard yet.
    private var awaitsRunsFirst = false
    /// For each session on the board's rows, the end of the latest turn it
    /// has stood at Lee's turn from, which moves it into his turn no more.
    private var turnEnds: [String: Date] = [:]

    public init() {}

    /// A run of `watch` starts.
    mutating func begin() {
        awaitsRunsFirst = true
    }

    /// Takes what a run of `watch` said, heard at the instant given; whether
    /// that changed what the views show.
    mutating func hear(_ heard: Heard, at instant: Date) -> Bool {
        let was = self

        isRunsFirst = false
        newTurns = []
        asksLeft = []
        asksChanged = []

        switch heard {
        case let .line(line):
            isRunsFirst = awaitsRunsFirst
            awaitsRunsFirst = false
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
            let read = try Board.read(line)

            newTurns = turnsEnded(on: read, after: isRunsFirst ? nil : board)
            asksLeft = asksLeft(on: read, after: board)
            asksChanged = asksChanged(on: read, after: board)
            board = read
            stale = nil
            staleSince = nil
        } catch {
            Logger.watch.error("sitrep watch \(error, privacy: .public): \(line.prefix(200), privacy: .public)")
            goStale(.unread(error), at: instant)
        }
    }

    /// The sessions this board moved into Lee's turn after the last (DESIGN,
    /// "Settings", Notifications): at his turn now, working or on its own
    /// work on the last board, from a turn that ended later than any it stood
    /// at his turn from before. So only Claude ending a turn moves a session
    /// in, and each turn once: never as it comes to his turn from needing
    /// him, an ask snoozed or answered elsewhere; never from his turn itself,
    /// as a window joining a session there restarts its turn's time; never
    /// from off the rows, as a snooze woken or a session new to them; never
    /// again for a turn it flickered out of; and never on a run's first line,
    /// the first since SitRep started among them, whose sessions at his turn
    /// were there already. The turns' ends are kept for the sessions on this
    /// board's rows alone.
    private mutating func turnsEnded(on board: Board, after last: Board?) -> Set<String> {
        let working = Set(last?.rows.filter { $0.section == .working }.map(\.session) ?? [])
        let turns = board.rows.filter { $0.section == .yourTurn }
        let ended = turns.filter { turn in
            working.contains(turn.session) && turnEnds[turn.session].map { turn.since > $0 } ?? true
        }

        turnEnds = board.rows.reduce(into: [:]) { ends, row in
            let end = turnEnds[row.session]

            ends[row.session] = row.section == .yourTurn ? max(row.since, end ?? row.since) : end
        }
        return Set(ended.map(\.session))
    }

    /// The asks waiting on Lee on the last board that wait on him no more on this one: none where either line's
    /// projects did not read, as such a line says nothing of its asks, so no banner goes for an ask still waiting.
    private func asksLeft(on board: Board, after last: Board?) -> Set<AskOf> {
        guard let was = last?.waitingOnLee, let now = board.waitingOnLee else {
            return []
        }

        return was.subtracting(now)
    }

    /// The asks waiting on Lee on both the last board and this one that ask something else on this one; none where
    /// either line's projects did not read, as for `asksLeft`.
    private func asksChanged(on board: Board, after last: Board?) -> Set<AskOf> {
        guard let was = last?.asksWaitingOnLee, let now = board.asksWaitingOnLee else {
            return []
        }

        let changed = now.filter { ask, asked in was[ask].map { !$0.asksAlike(asked) } ?? false }

        return Set(changed.keys)
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
