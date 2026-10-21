import SitRepCore
import SitRepEdge
import SitRepPanel

/// A part of the sidebar's list that folds under its heading: a project, by its key, or the quiet projects.
public enum Fold: Hashable, Sendable {
    case project(String)
    case quiet
}

/// What is folded: the projects, by their keys, and whether the quiet projects are. Nothing is, at first.
public struct Folds: Codable, Equatable, Sendable {
    public var projects: Set<String> = []
    public var quiet = false

    public init() {}

    public init(from decoder: any Decoder) {
        let defaults = Folds()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        projects = given.value(.projects, or: defaults.projects)
        quiet = given.value(.quiet, or: defaults.quiet)
    }

    public func contains(_ fold: Fold) -> Bool {
        switch fold {
        case let .project(key): projects.contains(key)
        case .quiet: quiet
        }
    }

    /// Folded, or unfolded where it was.
    public mutating func toggle(_ fold: Fold) {
        switch fold {
        case let .project(key):
            if projects.remove(key) == nil {
                projects.insert(key)
            }
        case .quiet: quiet.toggle()
        }
    }
}

/// What Lee sets in the sidebar, saved as one value of its own under the key "window": its folds, kept across
/// launches.
public struct SidebarSettings: SavedValue {
    public static let key = "window"

    public var folds = Folds()

    public init() {}

    public init(from decoder: any Decoder) {
        let defaults = SidebarSettings()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        folds = given.value(.folds, or: defaults.folds)
    }
}

extension SavedSettings where Value == SidebarSettings {
    /// The folds as Lee left them, kept with whatever else the sidebar's settings hold.
    public func save(_ folds: Folds) {
        var settings = read()

        settings.folds = folds
        save(settings)
    }
}

/// A row of the sidebar's list that shows the pick: a session's under Needs you, or the pick's own place on the
/// board, a session under its project, a project's heading or a quiet project's row. A session with an ask shows
/// twice, so the selection says which of its rows is picked, while the page follows the session.
public enum Spot: Hashable, Sendable {
    case needsYou(String)
    case board(Pick)

    public var pick: Pick {
        switch self {
        case let .needsYou(session): .session(session)
        case let .board(pick): pick
        }
    }

    /// Where a pick made outside the list shows, by a restore at launch, the menu or the Filter field's Return: a
    /// session under Needs you while it has an ask, else under its project; Settings on no row of the board.
    static func of(_ pick: Pick?, in listed: Listed) -> Spot? {
        switch pick {
        case let .session(id)? where listed.needsYou.contains { $0.id == id }: .needsYou(id)
        case .settings?, nil: nil
        case let pick?: .board(pick)
        }
    }
}

/// The sidebar's list as it shows, one list, in order: Needs you, every session with an ask, the oldest first, under
/// a plain heading; then each project under its heading, in the board's order; then the quiet projects under theirs.
/// A folded project or the quiet projects show their heading alone; while the filter holds text, the folds Lee set
/// stand aside (`WindowRun.folds`).
public struct Sidebar: Equatable, Sendable {
    /// A heading that folds what is under it: a project's, or the quiet projects'.
    public struct Heading: Equatable, Sendable {
        public let fold: Fold
        public let name: String
        public let isFolded: Bool
        /// Its sessions with an ask, of all of them, filtered or not.
        public let asking: Int
        /// What waits on Lee there, asks and stops alike, as VoiceOver reads it.
        public let waiting: Int

        /// The orange count: only while it is folded, and only when it holds asks.
        public var count: Int? {
            isFolded && asking > 0 ? asking : nil
        }
    }

    public enum Line: Equatable, Sendable, Identifiable {
        /// "Needs you": plain words, which neither fold nor pick.
        case needsYou
        case asking(Listed.Row)
        case heading(Heading)
        case session(Listed.Row)
        case quiet(Listed.Quiet)

        public var id: ID {
            if let spot {
                return .spot(spot)
            }
            return self == .needsYou ? .needsYou : .quietHeading
        }

        /// The row of it that shows the pick, if it can show one.
        public var spot: Spot? {
            switch self {
            case .needsYou: nil
            case let .asking(row): .needsYou(row.id)
            case let .heading(heading):
                if case let .project(key) = heading.fold { .board(.project(key)) } else { nil }
            case let .session(row): .board(.session(row.id))
            case let .quiet(project): .board(project.pick)
            }
        }

        public enum ID: Hashable, Sendable {
            case needsYou, quietHeading
            case spot(Spot)
        }
    }

    /// How the board stands, for the list's place where it lists nothing.
    public let head: Head
    public let lines: [Line]

    public init() {
        self.init(Listed(), folds: Folds())
    }

    /// The list, folded as given.
    public init(_ listed: Listed, folds: Folds) {
        head = listed.head
        lines = Self.needsYou(listed) + listed.projects.flatMap { Self.lines(of: $0, folds: folds) }
            + Self.quiet(listed.quiet, isFolded: folds.quiet)
    }

    private static func needsYou(_ listed: Listed) -> [Line] {
        listed.needsYou.isEmpty ? [] : [.needsYou] + listed.needsYou.map(Line.asking)
    }

    private static func lines(of project: Listed.Project, folds: Folds) -> [Line] {
        let fold = Fold.project(project.id)
        let heading = Heading(
            fold: fold, name: project.name, isFolded: folds.contains(fold), asking: project.asking,
            waiting: project.waiting
        )

        return [.heading(heading)] + (heading.isFolded ? [] : project.sessions.map(Line.session))
    }

    private static func quiet(_ quiet: [Listed.Quiet], isFolded: Bool) -> [Line] {
        guard !quiet.isEmpty else {
            return []
        }

        let heading = Heading(fold: .quiet, name: Words.quietProjects, isFolded: isFolded, asking: 0, waiting: 0)

        return [.heading(heading)] + (isFolded ? [] : quiet.map(Line.quiet))
    }

    /// It lists nothing.
    public var isEmpty: Bool { lines.isEmpty }
}

extension Listed {
    /// Every session with an ask, the oldest first: by where its first row needing Lee sits in the panel's order,
    /// core's rows', an away session's after the live ones.
    static func needsYou(_ board: Board) -> [Row] {
        let every = board.projects.flatMap { project in project.sessions.map { (session: $0, project: project) } }
        let byID = Dictionary(every.map { ($0.session.id, $0) }) { first, _ in first }
        var placed = Set<String>()

        return board.rows.filter(\.needsLee).map(\.session).filter { placed.insert($0).inserted }
            .compactMap { byID[$0] }.map { Row($0.session, of: $0.project) }
    }

    /// The first session it lists, or with none the first quiet project: what Return in the Filter field opens, the
    /// filter holding text showing every project open.
    public var first: Pick? {
        (needsYou.first ?? sessions.first).map { .session($0.id) } ?? quiet.first?.pick
    }
}
