import Foundation
import SitRepPanel

/// What a click or an arrow key picks in the middle list: a line waiting on Lee, by its key; a snoozed ask under
/// "N snoozed", by its key, the one it has in Needs you; a session's row in Working or Your turn; a parked item, by its
/// session and its id.
public enum ListPick: Hashable, Codable, Sendable {
    case line(String)
    case snoozed(String)
    case session(String)
    case parked(session: String, id: String)
}

/// A place's list, the middle column. Needs you is a row per line waiting on Lee, each ask and each window's stop, not
/// per session: the oldest first, those of sessions a window holds before those of sessions none does; then
/// "N snoozed", its asks asleep, the soonest to wake first. Working and Your turn are a row per session, in core's
/// order, Your turn's past the fold period under "N earlier". A fold at the list's foot shows its rows only while it is
/// open, and always while the filter holds text. The filter keeps a line while every word typed appears in its
/// session's name, its project's or its own words; a session's row while every word appears in its name, its project's
/// or its lines'.
public struct PlaceList: Equatable, Sendable {
    /// A line of a session's row in Needs you, an ask or a window's stop; or in Snoozed, an ask asleep.
    public struct LineRow: Equatable, Sendable, Identifiable {
        /// The session's row it is a line of, which has its names, its mark and whether a window holds it.
        public let session: Listed.Row
        public let line: Listed.Line

        public var id: String { line.id }

        public var pick: ListPick {
            session.section == .snoozed ? .snoozed(line.id) : .line(line.id)
        }

        /// The ask it is, by its id, none for a window's stop: all its menu snoozes or wakes, and VoiceOver speaks of,
        /// never the other asks of its session's row.
        public var asks: [String] {
            line.ask.map { [$0] } ?? []
        }
    }

    public enum Row: Equatable, Sendable, Identifiable {
        case line(LineRow)
        case session(Listed.Row)

        public var id: ListPick { pick }

        public var pick: ListPick {
            switch self {
            case let .line(line): line.pick
            case let .session(row): .session(row.id)
            }
        }

        /// The session it shows, which the page beside the list follows.
        public var session: String {
            switch self {
            case let .line(line): line.session.id
            case let .session(row): row.id
            }
        }

        /// What the filter reads of it.
        fileprivate var words: [String] {
            switch self {
            case let .line(line): [line.session.name, line.session.project, line.line.words]
            case let .session(row): [row.name, row.project] + row.lines.map(\.words)
            }
        }
    }

    /// The fold at a list's foot, which opens in place and is never kept: Needs you's "N snoozed", Your turn's
    /// "N earlier".
    public struct Fold: Equatable, Sendable {
        public enum Kind: Sendable {
            case snoozed, earlier
        }

        public let kind: Kind
        public internal(set) var rows: [Row]
        public let isOpen: Bool

        public var title: String {
            switch kind {
            case .snoozed: "\(rows.count) snoozed"
            case .earlier: earlier.title
            }
        }

        /// As the card's "N earlier" has it: its rows' projects.
        public var earlier: Earlier {
            Earlier(projects: rows.map { $0.project }, isOpen: isOpen)
        }
    }

    /// The list as it shows, in order.
    public enum Item: Equatable, Sendable, Identifiable {
        case row(Row)
        case fold(Fold)

        public var id: ID {
            switch self {
            case let .row(row): .pick(row.pick)
            case let .fold(fold): .fold(fold.kind)
            }
        }

        public enum ID: Hashable, Sendable {
            case pick(ListPick)
            case fold(Fold.Kind)
        }
    }

    /// Where a pick stands in the list: "2 / 5".
    public struct Position: Equatable, Sendable {
        /// From 1.
        public let index: Int
        public let count: Int

        public var text: String { "\(index) / \(count)" }

        /// As VoiceOver says it: "2 of 5".
        public var spoken: String { "\(index) of \(count)" }
    }

    public let place: Place
    /// Its rows above the fold.
    public internal(set) var rows: [Row]
    public internal(set) var fold: Fold?

    /// Before `watch` prints its first line: Needs you, empty.
    public init() {
        self.init(.needsYou, in: Listed())
    }

    /// The place's list on the board given, narrowed by the filter, its fold open as given.
    public init(_ place: Place, in listed: Listed, filter: Filter = Filter(), isFoldOpen: Bool = false) {
        let given = Self.rows(of: place, in: listed)
        let kept = { (rows: [Row]) in rows.filter { filter.matches($0.words) } }

        self.place = place
        rows = kept(given.rows)
        fold = given.fold.flatMap { folded in
            let rows = kept(folded.rows)

            return rows.isEmpty ? nil : Fold(kind: folded.kind, rows: rows, isOpen: isFoldOpen || !filter.isEmpty)
        }
    }

    private typealias Given = (rows: [Row], fold: (kind: Fold.Kind, rows: [Row])?)

    /// The place's rows on the board, in its order, and its fold's, with any.
    private static func rows(of place: Place, in listed: Listed) -> Given {
        switch place {
        case .needsYou:
            let waiting = lines(of: listed.needsYou).sorted { $0.first < $1.first }
            let snoozed = lines(of: listed.rows(in: .snoozed)).sorted { $0.soonest < $1.soonest }

            return (waiting.map(Row.line), (.snoozed, snoozed.map(Row.line)))
        case .working:
            return (listed.rows(in: .working).map(Row.session), nil)
        case .yourTurn:
            let rows = listed.rows(in: .yourTurn)
            let current = rows.filter { !$0.isEarlier }

            return (current.map(Row.session), (.earlier, rows.filter(\.isEarlier).map(Row.session)))
        case .parked:
            return ([], nil)
        }
    }

    private static func lines(of rows: [Listed.Row]) -> [LineRow] {
        rows.flatMap { row in row.lines.map { LineRow(session: row, line: $0) } }
    }

    /// The list as it shows: its rows, then its fold, with its rows while it is open.
    public var items: [Item] {
        rows.map(Item.row) + (fold.map { [.fold($0)] + ($0.isOpen ? $0.rows.map(Item.row) : []) } ?? [])
    }

    /// The rows it shows, which a click or an arrow key picks, in order.
    public var shown: [Row] {
        rows + (fold.flatMap { $0.isOpen ? $0.rows : nil } ?? [])
    }

    /// What it shows that picks, in order.
    public var picks: [ListPick] {
        shown.map(\.pick)
    }

    /// It lists nothing, its fold none either.
    public var isEmpty: Bool { rows.isEmpty && fold == nil }

    /// Its fold holds the pick's row, which shows only while the fold is open: as a pick made outside the list shows,
    /// the fold opens for it.
    public func folds(_ pick: ListPick?) -> Bool {
        fold?.rows.contains { $0.pick == pick } ?? false
    }

    /// The row it shows for the pick, while it shows one.
    public func row(_ pick: ListPick?) -> Row? {
        shown.first { $0.pick == pick }
    }

    /// Where the pick stands among the rows it shows; none where it shows no row for it, as one that left the list.
    public func position(of pick: ListPick?) -> Position? {
        let picks = picks

        return picks.firstIndex { $0 == pick }.map { Position(index: $0 + 1, count: picks.count) }
    }

    /// The selection picking the row it lists for the pick makes, standing where the list shows it; none where it
    /// lists no row for the pick, its fold's included.
    public func selection(of pick: ListPick) -> Selection? {
        let row = (rows + (fold?.rows ?? [])).first { $0.pick == pick }

        return row.map { Selection(pick: pick, session: $0.session).standing(in: self) }
    }

    /// Where ↓, or ↑, goes from the selection: the row after its pick, or before it; for a pick it no longer shows,
    /// from where it stood, after the nearest of the rows above it that it still shows; with nothing picked, ↓ to the
    /// first row and ↑ nowhere. None where no row lies that way.
    public func step(from selection: Selection?, down: Bool) -> ListPick? {
        let picks = picks
        let at = picks.firstIndex { $0 == selection?.pick }
        let after = at.map { $0 + 1 } ?? selection?.standing(among: picks) ?? 0
        let to = down ? after : (at ?? after) - 1

        return picks.indices.contains(to) ? picks[to] : nil
    }
}

private extension PlaceList.LineRow {
    /// Needs you's order, as core's: a session a window holds before one none does, then the oldest first, then by
    /// key.
    var first: (Int, Date, String) { (session.isAway ? 1 : 0, line.since, line.id) }

    /// Snoozed's, as core's: the soonest to wake first, then the oldest, then by key.
    var soonest: (Date, Date, String) { (line.wakesAt ?? .distantFuture, line.since, line.id) }
}

private extension PlaceList.Row {
    /// Its session's project's name.
    var project: String {
        switch self {
        case let .line(line): line.session.project
        case let .session(row): row.project
        }
    }
}
