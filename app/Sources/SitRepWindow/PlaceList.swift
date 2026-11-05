import Foundation
import SitRepCore
import SitRepPanel

/// What a click or an arrow key picks in the middle list: a line waiting on Lee, by its key; a snoozed ask under
/// "N snoozed", by its key, the one it has in Needs you, or a snoozed turn, by its own; a session's row in Working or
/// Your turn; a parked item, by its session and its id.
public enum ListPick: Hashable, Codable, Sendable {
    case line(String)
    case snoozed(String)
    case session(String)
    case parked(session: String, id: String)
}

/// A place's list, the middle column. Needs you is a row per line waiting on Lee, each ask and each window's stop, not
/// per session: the newest first, those of sessions a window holds before those of sessions none does; then
/// "N snoozed", its asks and turns asleep, the soonest to wake first. Your turn and Working are a row per session, in
/// core's order, Your turn's past the fold period under "N earlier". Parked is a row per item, under a heading per
/// project, the projects in `watch`'s order and each one's items the oldest first, narrowed to a project or a session
/// where its scope says. A fold at the list's foot shows its rows only while it is open, and always while the filter
/// holds text. The filter keeps a line while every word typed appears in its session's name, its project's or its own
/// words; a session's row while every word appears in its name, its project's or its lines'; an item while every word
/// appears in its title, its session's name or its project's.
public struct PlaceList: Equatable, Sendable {
    /// A line of a session's row in Needs you, an ask or a window's stop; or in Snoozed, an ask asleep, or a turn,
    /// keyed `turn:<session>` apart from its session's asks' keys.
    public struct LineRow: Equatable, Sendable, Identifiable {
        /// The session's row it is a line of, which has its names, its mark and whether a window holds it.
        public let session: Listed.Row
        public let line: Listed.Line

        public var id: String { line.id }

        public var pick: ListPick {
            isAsleep ? .snoozed(line.id) : .line(line.id)
        }

        /// An ask asleep, or a turn, under "N snoozed".
        public var isAsleep: Bool { session.section == .snoozed }

        /// A turn asleep, its line what Claude left Lee, its time the turn's end.
        public var isTurn: Bool { session.isTurn }

        /// Its mark: asleep, the snoozed mark, a turn's the faint ring; else the orange dot, or the away ring while no
        /// window holds its session.
        public var mark: Mark {
            isAsleep ? (isTurn ? .snoozedTurn : .snoozed) : session.isAway ? .awayAsk : .needs
        }

        /// The ask it is, by its id, none for a window's stop or a turn: all its menu snoozes or wakes, and VoiceOver
        /// speaks of, never the other asks of its session's row.
        public var asks: [String] {
            line.ask.map { [$0] } ?? []
        }

        /// What its menu's Snooze puts off, or its Wake now brings back: its one ask, or its turn by the turn's end;
        /// none for a window's stop.
        public var snoozable: Snoozable? {
            .of(isTurn: isTurn, ended: line.since, asks: asks)
        }
    }

    public enum Row: Equatable, Sendable, Identifiable {
        case line(LineRow)
        case session(Listed.Row)
        case parked(Listed.Parked)

        public var id: ListPick { pick }

        public var pick: ListPick {
            switch self {
            case let .line(line): line.pick
            case let .session(row): .session(row.session)
            case let .parked(item): item.id
            }
        }

        /// The session's row it is of, or is; none for a parked item, which is no session's row.
        public var row: Listed.Row? {
            switch self {
            case let .line(line): line.session
            case let .session(row): row
            case .parked: nil
            }
        }

        /// A window holds its session: its button under the pointer, and VoiceOver's "Jump to the window", jump there.
        /// A parked item's row, which shows the item and not its session, has none.
        public var jumps: Bool { row?.jumps ?? false }

        /// A line under "N snoozed", which its menu wakes.
        public var isAsleep: Bool {
            if case let .line(line) = self { line.isAsleep } else { false }
        }

        /// What its menu's Snooze puts off, or its Wake now brings back: a line's (`LineRow.snoozable`); a Your turn
        /// row's turn, by the turn's end; none for a Working row nor a parked item.
        public var snoozable: Snoozable? {
            switch self {
            case let .line(line): line.snoozable
            case let .session(row): row.section == .yourTurn ? .turn(ended: row.since) : nil
            case .parked: nil
            }
        }

        /// The session it shows, or that parked it, which the page beside the list follows.
        public var session: String {
            switch self {
            case let .line(line): line.session.session
            case let .session(row): row.session
            case let .parked(item): item.session
            }
        }

        /// What the filter reads of it.
        fileprivate var words: [String] {
            switch self {
            case let .line(line): [line.session.name, line.session.project, line.line.words]
            case let .session(row): [row.name, row.project] + row.lines.map(\.words)
            case let .parked(item): [item.item.title, item.sessionName, item.projectName]
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
            Earlier(projects: rows.compactMap(\.row?.project), isOpen: isOpen)
        }
    }

    /// The heading over a project's items in Parked, which the list never selects: its name, and how many of its
    /// items the list shows.
    public struct Heading: Equatable, Sendable {
        /// Its project's key.
        public let project: String
        public let name: String
        public let count: Int
    }

    /// The list as it shows, in order.
    public enum Item: Equatable, Sendable, Identifiable {
        case row(Row)
        case fold(Fold)
        case heading(Heading)

        public var id: ID {
            switch self {
            case let .row(row): .pick(row.pick)
            case let .fold(fold): .fold(fold.kind)
            case let .heading(heading): .heading(heading.project)
            }
        }

        public enum ID: Hashable, Sendable {
            case pick(ListPick)
            case fold(Fold.Kind)
            /// A project's heading, by its key.
            case heading(String)
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

    /// The place's list on the board given, narrowed by the filter, its fold open as given; Parked's narrowed to its
    /// scope too.
    public init(
        _ place: Place, in listed: Listed, filter: Filter = Filter(), isFoldOpen: Bool = false,
        scope: ParkedScope = .all
    ) {
        let given = Self.rows(of: place, in: listed, scope: scope)
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
    private static func rows(of place: Place, in listed: Listed, scope: ParkedScope) -> Given {
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
            return (parked(in: listed, scope: scope).map(Row.parked), nil)
        }
    }

    /// The items in the scope, by project in `watch`'s order, each project's the oldest first, those as old as each
    /// other as the board has them.
    private static func parked(in listed: Listed, scope: ParkedScope) -> [Listed.Parked] {
        let rank = Dictionary(listed.projects.enumerated().map { ($1.id, $0) }) { first, _ in first }
        let order = { (item: (offset: Int, element: Listed.Parked)) in
            (rank[item.element.project] ?? rank.count, item.element.item.at, item.offset)
        }

        return listed.parked.enumerated().filter { scope.holds($0.element) }.sorted { order($0) < order($1) }
            .map(\.element)
    }

    private static func lines(of rows: [Listed.Row]) -> [LineRow] {
        rows.flatMap { row in row.lines.map { LineRow(session: row, line: $0) } }
    }

    /// The list as it shows: its rows, then its fold, with its rows while it is open; Parked's under their projects'
    /// headings.
    public var items: [Item] {
        guard place != .parked else {
            return Self.headed(rows)
        }
        return rows.map(Item.row) + (fold.map { [.fold($0)] + ($0.isOpen ? $0.rows.map(Item.row) : []) } ?? [])
    }

    /// Parked's rows, each run of a project's under its heading. A project's items are always one run: they come so
    /// from the board, and a held order never parts them, as each project's keep their order and an item new to it
    /// goes in after the one `watch` has before it (`Hold.merge`).
    private static func headed(_ rows: [Row]) -> [Item] {
        let runs = rows.reduce(into: [[Listed.Parked]]()) { runs, row in
            guard case let .parked(item) = row else {
                return
            }

            if runs.last?.last?.project == item.project {
                runs[runs.count - 1].append(item)
            } else {
                runs.append([item])
            }
        }

        return runs.flatMap { run in
            [Item.heading(Heading(project: run[0].project, name: run[0].projectName, count: run.count))]
                + run.map { Item.row(.parked($0)) }
        }
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
    /// first row and ↑ nowhere. None where no row lies that way. What it picks stands where the list shows it.
    public func step(from selection: Selection?, down: Bool) -> Selection? {
        let picks = picks
        let at = picks.firstIndex { $0 == selection?.pick }
        let after = at.map { $0 + 1 } ?? selection?.standing(among: picks) ?? 0
        let to = down ? after : (at ?? after) - 1

        return picks.indices.contains(to) ? self.selection(of: picks[to]) : nil
    }
}

/// Your turn's "N earlier" at the foot of the SitRep window's middle list: the sessions whose turn ended longer ago
/// than the fold period, in one line, which opens in place to show them. The card shows every your-turn row (board J).
public struct Earlier: Equatable, Sendable {
    public let count: Int
    /// Their projects, each once, in the rows' order.
    public let projects: [String]
    public let isOpen: Bool

    /// Of sessions in these projects, one each, in the rows' order.
    public init(projects: [String], isOpen: Bool) {
        count = projects.count
        self.projects = projects.reduce(into: []) { once, project in
            if !once.contains(project) {
                once.append(project)
            }
        }
        self.isOpen = isOpen
    }

    /// "8 earlier".
    public var title: String { "\(count) earlier" }
}

private extension PlaceList.LineRow {
    /// Needs you's order: a session a window holds before one none does, then the newest first, so a new ask comes
    /// in at the top (Lee, 4 November 2026), then by key.
    var first: (Int, TimeInterval, String) { (session.isAway ? 1 : 0, -line.since.timeIntervalSince1970, line.id) }

    /// Snoozed's, as core's: the soonest to wake first, then the oldest, then by key.
    var soonest: (Date, Date, String) { (line.wakesAt ?? .distantFuture, line.since, line.id) }
}

extension ParkedScope {
    /// The item is in it: every item in all; a project's items in their project's; a session's in its session's.
    func holds(_ item: Listed.Parked) -> Bool {
        switch self {
        case .all: true
        case let .project(key): item.project == key
        case let .session(id): item.session == id
        }
    }
}
