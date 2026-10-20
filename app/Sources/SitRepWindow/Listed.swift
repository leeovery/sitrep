import Foundation
import SitRepCore
import SitRepEdge
import SitRepPanel

/// A session's mark, in the panel row's lane: needs you an orange dot, your turn an open ring, working the turning
/// arc; away, with nothing waiting, a faint dot.
public enum Mark: Sendable, Equatable {
    case needs, turn, working, away

    init(_ state: Board.Session.State) {
        switch state {
        case .needsYou: self = .needs
        case .yourTurn: self = .turn
        case .working: self = .working
        case .away, .finished: self = .away
        }
    }
}

/// The board down the window's left: its head; every project with something open, in `watch`'s order, its sessions
/// under it in theirs; and the quiet projects, folded into a line at the foot.
public struct Listed: Equatable, Sendable {
    public struct Project: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// What waits on Lee there: its rows that need Lee, asks and stops alike.
        public let waiting: Int
        public var sessions: [Row]
    }

    /// A session's row: a small panel row, its name on one line and the panel row's time.
    public struct Row: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let mark: Mark
        /// No window holds it: its name is faint, whatever its mark.
        public let isAway: Bool
        /// When its state began, which its time counts from.
        public let since: Date
        /// New to needing Lee: washed orange from then (`Wash`).
        public var washed: Date?
    }

    public let head: Head
    public var projects: [Project]
    /// The quiet projects' names, in `watch`'s order.
    public let quiet: [String]

    /// Before `watch` prints its first line.
    public init() {
        self.init(LastBoard())
    }

    /// With no `watch` to run, its head says why.
    public init(unrun why: String) {
        head = PanelBoard(unrun: why).head
        projects = []
        quiet = []
    }

    /// The board as last heard, its head as the panel's says it, stale or not.
    public init(_ last: LastBoard) {
        let board = last.board
        let needs = Dictionary(grouping: board?.rows.filter(\.needsLee) ?? [], by: \.project).mapValues(\.count)
        let shown = board?.projects.filter { !$0.isQuiet } ?? []

        head = PanelBoard(last).head
        projects = shown.map { project in
            Project(id: project.key, name: project.name, waiting: needs[project.key] ?? 0, sessions: project.sessions.map(Row.init))
        }
        quiet = board?.projects.filter(\.isQuiet).map(\.name) ?? []
    }

    /// Every session it lists, in its order.
    public var sessions: [Row] { projects.flatMap(\.sessions) }
}

extension Listed.Row {
    init(_ session: Board.Session) {
        self.init(id: session.id, name: session.name, mark: Mark(session.state), isAway: session.doing.isAway, since: session.since)
    }
}

extension Board.Row {
    /// An ask, a permission prompt or a question: the rows that need Lee.
    var needsLee: Bool {
        switch kind {
        case .ask, .permission, .question: true
        case .yourTurn, .working: false
        }
    }
}

extension Board.Project {
    /// Nothing open: no window on any of its sessions, no ask waiting on Lee and nothing parked, as core folds a
    /// project into All projects' one line (core/views.ts's `isFolded`).
    var isQuiet: Bool {
        open == 0 && parked == 0 && sessions.allSatisfy { $0.asks.allSatisfy { $0.state != .waiting } }
    }
}
