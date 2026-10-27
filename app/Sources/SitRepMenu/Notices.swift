import SitRepCore

/// The macOS notifications a board sends (DESIGN, "Settings", Notifications): one for each ask new on it, silent,
/// with its title, then its project and session, a click jumping to it.
public enum Notices {
    /// What this board sends, with Lee's switch as it stands: none while it is off, else one for each of its new asks.
    public static func due(_ last: LastBoard, isOn: Bool) -> [Banner] {
        isOn ? last.newAsks.map { newAsk($0.ask, of: $0.row) } : []
    }

    /// The test notification Settings sends: a sample, never a real session's, so a click on it jumps nowhere. Lee, 26
    /// October 2026: one of a real project's took him to its session, which a test should not.
    public static var test: Banner {
        Banner(title: "Test notification", subtitle: nil, body: "This is what SitRep's notifications look like.", work: nil)
    }

    private static func newAsk(_ ask: Board.Row.Line, of row: Board.Row) -> Banner {
        Banner(title: ask.first.lead, subtitle: placeOf(row), body: "", work: row.isAway ? nil : row.session)
    }

    /// The row's project and session by name, an away row's too, whose second line says no window holds it.
    private static func placeOf(_ row: Board.Row) -> String {
        "\(row.projectName) · \(row.name)"
    }
}

extension LastBoard {
    /// The asks new on this board, with their rows, in core's order: an ask that landed or that its snooze's time woke,
    /// as core's `new` has both. None for a board that is a run's first, which counts what it shows as shown, nor for
    /// a stale one, the last line kept, whose new asks were told as it came; and only asks, not a window's new stop.
    var newAsks: [(ask: Board.Row.Line, row: Board.Row)] {
        guard stale == nil, !isRunsFirst, let board else {
            return []
        }

        let new = Set(board.new)

        return board.rows.flatMap { row in
            row.lines.filter { $0.kind == .ask && new.contains($0.key) }.map { ($0, row) }
        }
    }
}
