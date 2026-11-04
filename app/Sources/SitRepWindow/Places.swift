import SitRepPanel

/// A place in the sidebar, above the projects: what the middle column lists. The window's own, apart from the card's
/// sections (`BoardSection`), which the panel and the menu share.
public enum Place: String, CaseIterable, Codable, Hashable, Sendable {
    case needsYou, working, yourTurn, parked

    public var title: String {
        section?.title ?? "Parked"
    }

    /// The card's section whose rows it lists: none for Parked, whose items are no session's row.
    var section: BoardSection? {
        switch self {
        case .needsYou: .needsYou
        case .working: .working
        case .yourTurn: .yourTurn
        case .parked: nil
        }
    }

    /// Its count on the board: Needs you's its lines waiting on Lee, each ask and stop; Working's and Your turn's their
    /// rows, "N earlier"'s among them; Parked's the items every session parked.
    func count(in listed: Listed) -> Int {
        switch self {
        case .needsYou: listed.needsYou.map(\.lines.count).reduce(0, +)
        case .working, .yourTurn: listed.rows.filter { $0.section == section }.count
        case .parked: listed.projects.map(\.parked).reduce(0, +)
        }
    }
}

/// A project's mark in the sidebar: a line waiting on Lee in a session a window holds, the orange dot; only lines of
/// sessions no window holds, the away ring; nothing waiting, the quiet grey dot.
public enum ProjectMark: Sendable, Equatable {
    case needs, awayAsk, nothingWaiting
}

/// The sidebar under the Filter field: the four places, each with its count, then every project on the board, quiet
/// ones too, in the order given. The counts are the whole board's, whatever the filter holds; the projects narrow to
/// those whose names hold every word typed.
public struct Places: Equatable, Sendable {
    /// A project's row, which opens its page.
    public struct Project: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let mark: ProjectMark
        /// Its current sessions.
        public let sessions: Int
        /// Nothing open in it, waiting, asleep or parked: its name soft, its count hidden.
        public let isQuiet: Bool

        /// Its grey count: its current sessions, none where it is quiet.
        public var count: Int? { isQuiet ? nil : sessions }
    }

    private let counts: [Place: Int]
    public internal(set) var projects: [Project]

    public init(_ listed: Listed, filter: Filter = Filter()) {
        let marks = Self.marks(listed)

        counts = Dictionary(uniqueKeysWithValues: Place.allCases.map { ($0, $0.count(in: listed)) })
        projects = listed.projects.filter { filter.matches($0.name) }.map { project in
            Project(
                id: project.id, name: project.name, mark: marks[project.id] ?? .nothingWaiting,
                sessions: project.sessions, isQuiet: project.isQuiet
            )
        }
    }

    public func count(of place: Place) -> Int {
        counts[place] ?? 0
    }

    /// The marks of the projects with lines waiting on Lee, by their keys: the dot where any is of a session a window
    /// holds, else the away ring.
    private static func marks(_ listed: Listed) -> [String: ProjectMark] {
        listed.needsYou.reduce(into: [:]) { marks, row in
            guard let project = listed.homes[row.id], marks[project] != .needs else {
                return
            }
            marks[project] = row.isAway ? .awayAsk : .needs
        }
    }
}

private extension Listed.Project {
    /// Nothing open in it, waiting, asleep or parked, as core folds a project (`isFolded`): an ask asleep keeps it
    /// current, though nothing waits on Lee now.
    var isQuiet: Bool { open == 0 && waiting == 0 && snoozed == 0 && parked == 0 }
}
