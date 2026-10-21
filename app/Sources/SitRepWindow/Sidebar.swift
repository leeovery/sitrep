import SitRepCore
import SitRepEdge

/// The sidebar's two views of the board, Lee's choice at its top: Projects, each project's sessions under its name,
/// as the board reads; Needs you, every session in one flat list, in the panel's order.
public enum Sidebar: String, Codable, CaseIterable, Sendable, Identifiable {
    case projects, needsYou

    public var id: Self { self }

    public var title: String {
        switch self {
        case .projects: "Projects"
        case .needsYou: "Needs you"
        }
    }
}

/// What Lee sets in the SitRep window itself, saved as one value of its own: the sidebar's view, kept across
/// launches.
public struct WindowSettings: SavedValue {
    public static let key = "window"

    public var sidebar = Sidebar.projects

    public init() {}

    public init(from decoder: any Decoder) {
        let defaults = WindowSettings()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        sidebar = given.value(.sidebar, or: defaults.sidebar)
    }
}

extension Listed {
    /// Every session on the board in the panel's order, core's rows': by where its first row sits, so what needs Lee
    /// comes first, the oldest ask first and an away session's after the live ones, then your turn, then working. Those
    /// with no row, away with nothing waiting, come after, in the board's order.
    static func flat(_ board: Board) -> [Row] {
        let every = board.projects.flatMap { project in project.sessions.map { Row($0, of: project) } }
        let byID = Dictionary(every.map { ($0.id, $0) }) { first, _ in first }
        var placed = Set<String>()
        let withRows = board.rows.map(\.session).filter { placed.insert($0).inserted }.compactMap { byID[$0] }

        return withRows + every.filter { !placed.contains($0.id) }
    }

    /// The first session this view lists, or with none the first quiet project: what Return in the Filter field opens.
    public func first(in sidebar: Sidebar) -> Pick? {
        switch sidebar {
        case .projects: sessions.first.map { .session($0.id) } ?? quiet.first?.pick
        case .needsYou: flat.first.map { .session($0.id) }
        }
    }

    /// This view lists nothing.
    public func isEmpty(in sidebar: Sidebar) -> Bool {
        first(in: sidebar) == nil
    }
}
