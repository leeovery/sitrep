import Foundation
import SitRepCore
import SitRepEdge
import SitRepPanel

/// A session's mark, in the panel row's lane: needs you an orange dot, and an ask waiting in a session no window holds
/// a hollow orange ring; your turn an open ring, working the turning arc, on its own work the dotted ring, still; away,
/// with nothing waiting, a faint dot; an ask asleep, or its row in Snoozed, a grey dot, unlit.
public enum Mark: Sendable, Equatable {
    case needs, awayAsk, turn, working, onItsWork, away, snoozed

    /// A session's, by its state, and whether a window holds it.
    init(_ state: Board.Session.State, isAway: Bool) {
        switch state {
        case .needsYou: self = isAway ? .awayAsk : .needs
        case .yourTurn: self = .turn
        case .working: self = .working
        case .onItsWork: self = .onItsWork
        case .away, .finished: self = .away
        }
    }

    /// A row's, by its first line, and whether a window holds its session: an ask or a window's stop needs Lee.
    init(_ line: Board.Row.Line.Kind, isAway: Bool) {
        switch line {
        case .ask, .permission, .question: self = isAway ? .awayAsk : .needs
        case .yourTurn: self = .turn
        case .working: self = .working
        case .onItsWork: self = .onItsWork
        }
    }
}

/// The board down the window's left, as the card lists it: a row for each session core has one for, in its section,
/// Needs you, Your turn or Working, in core's order, each session once; a row in Snoozed for each with asks asleep,
/// beside any it has in another; and every project, quiet ones too, for Projects at the list's foot.
public struct Listed: Equatable, Sendable {
    /// A project, a row of Projects, which opens its page: its sessions, those no window holds among them, and their
    /// notes as their boards are read.
    public struct Project: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// Its current sessions.
        public var sessions = 0
        /// Its sessions a window holds.
        public var open = 0
        /// Its asks waiting, on Lee or on a window to deliver Lee's reply.
        public var waiting = 0
        /// Its asks snoozed.
        public var snoozed = 0
        /// The items its sessions parked.
        public var parked = 0

        public var pick: Pick { .project(id) }
    }

    /// A session's row, in its section: under Needs you, its name and a count of its lines waiting on Lee over its
    /// project; in Working, its turn's line over its project and its name; in Your turn, what Claude left Lee, on one
    /// line with its project; in Snoozed, as under Needs you, its asks asleep its lines, or its turn's, and when the
    /// soonest wakes.
    public struct Row: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// Its project's name.
        public let project: String
        public let section: BoardSection
        public let mark: Mark
        /// No window holds it: its words are faint, whatever its mark.
        public let isAway: Bool
        /// When the line its time counts from began: under Needs you, its newest's; on Your turn, its turn's end; in
        /// Snoozed, its oldest's.
        public let since: Date
        /// Under Needs you, its asks and stops waiting on Lee, the newest first, as core's row has them; in Snoozed,
        /// its asks asleep, the soonest to wake first; else its turn's one line.
        public var lines: [Line] = []
        /// In Snoozed, when its soonest ask wakes, or its turn; nil for a turn snoozed until it moves.
        public var wakesAt: Date?
        /// Its session's turn, on Your turn or in Snoozed, its time the turn's end: what its menu's Snooze puts off.
        public var isTurn = false
        /// New to needing Lee: washed orange from then (`Wash`).
        public var washed: Date?
        /// On Your turn, ended longer ago than the fold period: folded into "N earlier" (`WindowRun.listed(at:)`).
        public var isEarlier = false

        /// What a click on it picks: its session, or in Snoozed, its row there, which shows the same page.
        public var pick: Pick { section == .snoozed ? .snoozed(id) : .session(id) }

        /// The asks its lines show, by their ids, a window's stops aside: what its menu snoozes, or wakes.
        public var asks: [String] { lines.compactMap(\.ask) }

        /// A window holds it: its button under the pointer, and VoiceOver's "Jump to the window", jump there.
        public var jumps: Bool { !isAway }

        /// Under Needs you and in Snoozed, what follows its name: "+2" for its two lines after the first.
        public var more: String? { Session.more(over: lines.count) }

        /// When its newest line new to needing Lee began to wash, while one does: its age washes with it.
        public var lineWashed: Date? { lines.compactMap(\.washed).max() }
    }

    /// One of a row's lines, as the card's line says it: an ask or a window's stop waiting on Lee, or the session's
    /// turn; and its time.
    public struct Line: Equatable, Sendable, Identifiable {
        /// Its key in core's row.
        public let id: String
        /// The ask it is, by its id; nil for a window's stop or the session's turn.
        public var ask: String?
        /// Its words, or a working line's verb.
        public let lead: String
        /// A command or a path, set in mono after the lead.
        public let code: String?
        /// Set plain after the lead, where what it acts on is no command: "3 agents".
        public var subject: String?
        /// When the wake a line on its own work waits on is due: its subject counts down to it, "in 12m".
        public var until: Date?
        /// A question's "+2".
        public let more: String?
        public let since: Date
        /// In Snoozed, when it wakes.
        public var wakesAt: Date?
        /// New on the board: its time washed orange from then (`Wash`), which tells the new one among its row's.
        public var washed: Date?

        /// Its words, as the filter reads them, with no clock.
        public var words: String {
            [lead, code, subject].compactMap { $0 }.joined(separator: " ")
        }

        /// What it says plain after its lead at this time: a wake's countdown, "in 12m", else its subject.
        public func subject(at now: Date) -> String? {
            until.map { Session.untilText($0.timeIntervalSince(now) * 1000) } ?? subject
        }

        /// Its words at this time, as VoiceOver reads them, a wake's countdown among them.
        func words(at now: Date) -> String {
            [lead, code, subject(at: now)].compactMap { $0 }.joined(separator: " ")
        }
    }

    public let head: Head
    /// Every row, by its section in the sections' order, each section's in core's order (`Listed.rows(_:)`).
    public var rows: [Row]
    /// Every project on the board, in `watch`'s order.
    public var projects: [Project]
    /// The sessions on the board with no row, as an away one with nothing waiting, each by its project's key.
    public var rowless: [String: String]
    /// Every session on the board, each by its project's key.
    public var homes: [String: String]
    /// A board was heard, stale or not: without one, before `watch` prints its first line or with no `watch` to run,
    /// the list says nothing of what is on the board, so nothing has left it.
    public let hasBoard: Bool

    /// Before `watch` prints its first line.
    public init() {
        self.init(LastBoard())
    }

    /// With no `watch` to run, its head says why.
    public init(unrun why: String) {
        head = PanelBoard(unrun: why).head
        rows = []
        projects = []
        rowless = [:]
        homes = [:]
        hasBoard = false
    }

    /// The board as last heard, its head as the panel's says it, stale or not.
    public init(_ last: LastBoard) {
        let board = last.board

        hasBoard = board != nil
        head = PanelBoard(last).head
        rows = board.map(Self.rows) ?? []
        projects = board?.projects.map(Project.init) ?? []
        rowless = board.map(Self.rowless) ?? [:]
        homes = board.map(Self.homes) ?? [:]
    }

    /// A section's rows, in their order.
    public func rows(in section: BoardSection) -> [Row] {
        rows.filter { $0.section == section }
    }

    /// Every session needing Lee, in core's order.
    public var needsYou: [Row] { rows(in: .needsYou) }

    /// It has a row for the pick, a session's, a session's in Snoozed or a project's.
    func lists(_ pick: Pick) -> Bool {
        rows.contains { $0.pick == pick } || projects.contains { $0.pick == pick }
    }

    /// The pick as a row of its holds it: a session by its row outside Snoozed, and by its row in Snoozed only where it
    /// has no other; the row in Snoozed it was picked by, while it lists it, else the session. A project, and a
    /// session it lists no row of, as they are.
    func held(_ pick: Pick) -> Pick {
        switch pick {
        case let .session(id) where !lists(pick) && lists(.snoozed(id)): .snoozed(id)
        case let .snoozed(id) where !lists(pick): .session(id)
        default: pick
        }
    }

    /// The row it lists that shows a pick: its own; for a session with no row, its project's in Projects; none where
    /// it lists neither.
    func listedRow(showing pick: Pick) -> Pick? {
        if lists(pick) {
            return pick
        }
        guard case let .session(id) = pick, let key = rowless[id], lists(.project(key)) else {
            return nil
        }
        return .project(key)
    }

    /// Each of its rows changed.
    mutating func changeRows(_ change: (inout Row) -> Void) {
        rows.indices.forEach { change(&rows[$0]) }
    }
}

extension Listed {
    /// A row for each of core's, with its lines, by its section, in the sections' order: within one, core's order,
    /// Needs you's the newest first by its newest line, an away session's after the live ones; Snoozed's the soonest to
    /// wake first.
    static func rows(_ board: Board) -> [Row] {
        let rows = board.rows.map(Row.init) + board.snoozed.map(Row.init)

        return BoardSection.allCases.flatMap { section in rows.filter { $0.section == section } }
    }

    /// The board's sessions core has no row for, in Snoozed or out of it, by their projects' keys.
    static func rowless(_ board: Board) -> [String: String] {
        let rowed = Set(board.rows.map(\.session) + board.snoozed.map(\.session))

        return homes(board).filter { !rowed.contains($0.key) }
    }

    /// The board's sessions, by their projects' keys.
    static func homes(_ board: Board) -> [String: String] {
        let sessions = board.projects.flatMap { project in project.sessions.map { ($0.id, project.key) } }

        return Dictionary(sessions) { first, _ in first }
    }
}

extension Listed.Project {
    /// The board's project, with its counts.
    init(_ project: Board.Project) {
        self.init(
            id: project.key, name: project.name, sessions: project.sessions.count, open: project.open,
            waiting: project.waiting, snoozed: project.snoozed, parked: project.parked
        )
    }
}

extension Listed.Row {
    /// Core's row, with its lines and time.
    init(_ row: Board.Row) {
        self.init(
            id: row.session, name: row.name, project: row.projectName, section: BoardSection(row.section),
            mark: Mark(row.newest.kind, isAway: row.isAway), isAway: row.isAway, since: row.since,
            lines: row.lines.map(Listed.Line.init), isTurn: row.section == .yourTurn
        )
    }

    /// Core's Snoozed row, its asks asleep its lines, or its turn's, its time its oldest's, and when its soonest wakes.
    init(_ row: Board.SnoozedRow) {
        self.init(
            id: row.session, name: row.name, project: row.projectName, section: .snoozed, mark: .snoozed,
            isAway: row.isAway, since: row.lines.map(\.since).min()!, lines: row.lines.map(Listed.Line.init),
            wakesAt: row.wakesAt, isTurn: row.isTurn
        )
    }
}

private extension Listed.Line {
    init(_ line: Board.Row.Line) {
        self.init(
            id: line.key, ask: line.ask, lead: line.first.lead, code: line.first.mono, subject: line.first.subject,
            until: line.first.until, more: line.first.more, since: line.since
        )
    }

    init(_ line: Board.SnoozedRow.Line) {
        self.init(
            id: line.key, ask: line.ask, lead: line.first.lead, code: nil, more: nil, since: line.since,
            wakesAt: line.wakesAt
        )
    }
}

extension BoardSection {
    init(_ section: Board.Row.Section) {
        switch section {
        case .needsYou: self = .needsYou
        case .working: self = .working
        case .yourTurn: self = .yourTurn
        }
    }
}
