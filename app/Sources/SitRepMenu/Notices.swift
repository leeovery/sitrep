import SitRepCore

/// The macOS notifications a board sends (DESIGN, "Settings", Notifications): one for each ask new on it, silent,
/// with its title, then its project and session, a click jumping to it.
public enum Notices {
    /// What this board sends, with Lee's switch as it stands: none while it is off; none for a board that is a run's
    /// first, which counts what it shows as shown, nor for a stale one, the last line kept, whose new asks were told
    /// as it came; and only for asks, not a window's new stop.
    public static func due(_ last: LastBoard, isOn: Bool) -> [Banner] {
        guard isOn, last.stale == nil, !last.isRunsFirst, let board = last.board else {
            return []
        }

        let new = Set(board.new)

        return board.rows.filter { $0.kind == .ask && new.contains($0.key) }.map { newAsk($0, on: board) }
    }

    /// The test notification Settings sends: as a new ask's would be, of the board's first row a window holds, which a
    /// click jumps to; with none, one that jumps nowhere.
    public static func test(_ last: LastBoard) -> Banner {
        guard let board = last.board, let row = board.rows.first(where: { !$0.isAway }) else {
            return Banner(title: "SitRep", subtitle: nil, body: "A test notification. No window holds a session, so it jumps nowhere.", work: nil)
        }

        return Banner(title: row.first.lead, subtitle: placeOf(row, on: board), body: "A test notification. Click it to jump to this session.", work: row.session)
    }

    private static func newAsk(_ row: Board.Row, on board: Board) -> Banner {
        Banner(title: row.first.lead, subtitle: placeOf(row, on: board), body: "", work: row.isAway ? nil : row.session)
    }

    /// The row's project and session by name: its second line, but for an away ask, whose second line says no window
    /// holds it.
    private static func placeOf(_ row: Board.Row, on board: Board) -> String {
        let project = board.projects.first { $0.key == row.project }
        let session = project?.sessions.first { $0.id == row.session }

        guard let project, let session else {
            return row.second
        }

        return "\(project.name) · \(session.name)"
    }
}
