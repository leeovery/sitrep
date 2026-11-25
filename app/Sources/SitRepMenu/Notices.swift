import SitRepCore

/// The macOS notifications a board sends (DESIGN, "Settings", Notifications), each silent, a click jumping to its
/// session: one for each ask new on it, with its title, then its project and session, its buttons answering it; and one
/// for each session it moved into Lee's turn, "Stopped", with its project and session, then what Claude left him.
public enum Notices {
    /// What this board sends, with Lee's switches as they stand: a new ask's while its switch is on, then his turn's
    /// while its own is.
    public static func due(_ last: LastBoard, _ settings: AppSettings) -> [Banner] {
        let asks = settings.notifiesNewAsks ? last.newAsks.map { newAsk($0.ask, of: $0.row, on: last.board) } : []
        let turns = settings.notifiesTurns ? last.newTurnRows.map(turn) : []

        return asks + turns
    }

    /// The test notification Settings sends: a sample, never a real session's, so a click on it jumps nowhere. Lee, 26
    /// October 2026: one of a real project's took him to its session, which a test should not.
    public static var test: Banner {
        Banner(title: "Test notification", subtitle: nil, body: "This is what SitRep's notifications look like.", work: nil)
    }

    /// Its buttons answer the board's ask the line is, where it has buttons (DESIGN, "Its buttons").
    private static func newAsk(_ line: Board.Row.Line, of row: Board.Row, on board: Board?) -> Banner {
        let ask = line.ask.flatMap { board?.ask($0, of: row.session) }.flatMap { Banner.Ask($0, of: row) }

        return Banner(title: line.first.lead, subtitle: row.place, body: "", work: row.session, ask: ask)
    }

    private static func turn(_ row: Board.Row) -> Banner {
        Banner(title: "Stopped", subtitle: row.place, body: row.newest.first.lead, work: row.session)
    }
}

extension LastBoard {
    /// The asks new on this board, with their rows, the oldest first, so Notification Center, which stacks the last
    /// posted on top, shows the newest there, as Needs you does: an ask that landed or that its snooze's time woke, as
    /// core's `new` has both. None for a board that is a run's first, which counts what it shows as shown, nor for a
    /// stale one, the last line kept, whose new asks were told as it came; and only asks, not a window's new stop.
    var newAsks: [(ask: Board.Row.Line, row: Board.Row)] {
        guard stale == nil, !isRunsFirst, let board else {
            return []
        }

        let new = Set(board.new)
        let asks = board.rows.flatMap { row in
            row.lines.filter { $0.kind == .ask && new.contains($0.key) }.map { (ask: $0, row: row) }
        }

        return asks.enumerated().sorted { ($0.element.ask.since, $0.offset) < ($1.element.ask.since, $1.offset) }
            .map(\.element)
    }

    /// The rows of the sessions this board moved into Lee's turn (`newTurns`), the turn that ended first first, as the
    /// asks go; none for a stale board.
    var newTurnRows: [Board.Row] {
        guard stale == nil, let board else {
            return []
        }

        return board.rows.enumerated()
            .filter { newTurns.contains($0.element.session) }
            .sorted { ($0.element.since, $0.offset) < ($1.element.since, $1.offset) }
            .map(\.element)
    }
}
