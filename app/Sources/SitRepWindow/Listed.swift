import Foundation
import SitRepCore
import SitRepEdge
import SitRepPanel

/// A session's mark, in the panel row's lane: needs you an orange dot, your turn an open ring, working the turning
/// arc, on its own work the dotted ring, still; away, with nothing waiting, a faint dot.
public enum Mark: Sendable, Equatable {
    case needs, turn, working, onItsWork, away

    init(_ state: Board.Session.State) {
        switch state {
        case .needsYou: self = .needs
        case .yourTurn: self = .turn
        case .working: self = .working
        case .onItsWork: self = .onItsWork
        case .away, .finished: self = .away
        }
    }
}

/// The board down the window's left: its head; every session with an ask, for Needs you at its top; every project with
/// something open, in `watch`'s order, its sessions under it in theirs; and the quiet projects.
public struct Listed: Equatable, Sendable {
    public struct Project: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// What waits on Lee there: its rows that need Lee, asks and stops alike.
        public let waiting: Int
        /// Its sessions with an ask, which its heading counts while it is folded.
        public let asking: Int
        public var sessions: [Row]
    }

    /// A session's row: under its project, a small panel row, its name on one line and the panel row's time; under
    /// Needs you, its lines waiting on Lee over its project and its name.
    public struct Row: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// Its project's name, under its own in Needs you.
        public let project: String
        public let mark: Mark
        /// No window holds it: its name is faint, whatever its mark.
        public let isAway: Bool
        /// When its state began, which its time counts from.
        public let since: Date
        /// Under Needs you, its asks and stops waiting on Lee, the oldest first, as core's row has them; none under
        /// its project.
        public var lines: [Waiting] = []
        /// New to needing Lee: washed orange from then (`Wash`).
        public var washed: Date?
    }

    /// One of a Needs you row's lines: an ask or a window's stop waiting on Lee, as the card's line says it, and its
    /// time.
    public struct Waiting: Equatable, Sendable, Identifiable {
        /// Its key in core's row.
        public let id: String
        public let lead: String
        /// A command or a path, set in mono after the lead.
        public let code: String?
        /// A question's "+2".
        public let more: String?
        public let since: Date
        /// New on the board: its time washed orange from then (`Wash`), which tells the new one among its row's.
        public var washed: Date?

        /// Its words, as the filter reads them.
        public var words: String {
            code.map { "\(lead) \($0)" } ?? lead
        }
    }

    /// A project with nothing open, a row among the quiet projects, which opens its project: its sessions, none of them
    /// in a window, and their notes as their boards are read.
    public struct Quiet: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// Its sessions' names, which the filter finds it by as well as its own.
        public let sessions: [String]

        public var pick: Pick { .project(id) }
    }

    public let head: Head
    /// Every session needing Lee, in core's order, its lines with it (`Listed.needsYou(_:)`).
    public var needsYou: [Row]
    public var projects: [Project]
    /// The quiet projects, in `watch`'s order.
    public var quiet: [Quiet]

    /// Before `watch` prints its first line.
    public init() {
        self.init(LastBoard())
    }

    /// With no `watch` to run, its head says why.
    public init(unrun why: String) {
        head = PanelBoard(unrun: why).head
        needsYou = []
        projects = []
        quiet = []
    }

    /// The board as last heard, its head as the panel's says it, stale or not.
    public init(_ last: LastBoard) {
        let board = last.board
        let needs = Dictionary(grouping: board?.rows.filter(\.needsLee) ?? [], by: \.project).mapValues { rows in
            rows.map(\.lines.count).reduce(0, +)
        }
        let shown = board?.projects.filter { !$0.isQuiet } ?? []

        head = PanelBoard(last).head
        needsYou = board.map(Self.needsYou) ?? []
        projects = shown.map { project in
            let sessions = project.sessions.map { Row($0, of: project) }

            return Project(
                id: project.key, name: project.name, waiting: needs[project.key] ?? 0,
                asking: sessions.filter { $0.mark == .needs }.count, sessions: sessions
            )
        }
        quiet = board?.projects.filter(\.isQuiet).map {
            Quiet(id: $0.key, name: $0.name, sessions: $0.sessions.map(\.name))
        } ?? []
    }

    /// Every session it lists, in its order.
    public var sessions: [Row] { projects.flatMap(\.sessions) }

    /// Each of its rows changed, under Needs you and under their projects.
    mutating func changeRows(_ change: (inout Row) -> Void) {
        needsYou.indices.forEach { change(&needsYou[$0]) }
        for project in projects.indices {
            projects[project].sessions.indices.forEach { change(&projects[project].sessions[$0]) }
        }
    }
}

extension Listed {
    /// Every session needing Lee, as core's rows have them, in their order: the oldest first, by its oldest line, an
    /// away session's after the live ones; each with its lines.
    static func needsYou(_ board: Board) -> [Row] {
        board.rows.filter(\.needsLee).compactMap { row in
            board.session(row.session).map { Row(row, of: $0.session, in: $0.project) }
        }
    }
}

extension Listed.Row {
    init(_ session: Board.Session, of project: Board.Project) {
        self.init(
            id: session.id, name: session.name, project: project.name, mark: Mark(session.state),
            isAway: session.doing.isAway, since: session.since
        )
    }

    /// A row of Needs you: its session's, with core's row's lines and time.
    init(_ row: Board.Row, of session: Board.Session, in project: Board.Project) {
        self.init(
            id: session.id, name: session.name, project: project.name, mark: .needs, isAway: row.isAway,
            since: row.since, lines: row.lines.map(Listed.Waiting.init)
        )
    }
}

private extension Listed.Waiting {
    init(_ line: Board.Row.Line) {
        self.init(id: line.key, lead: line.first.lead, code: line.first.mono, more: line.first.more, since: line.since)
    }
}

extension Board.Project {
    /// Nothing open: no window on any of its sessions, no ask waiting on Lee and nothing parked, as core folds a
    /// project into All projects' one line (core/views.ts's `isFolded`).
    var isQuiet: Bool {
        open == 0 && parked == 0 && sessions.allSatisfy { $0.asks.allSatisfy { $0.state != .waiting } }
    }
}
