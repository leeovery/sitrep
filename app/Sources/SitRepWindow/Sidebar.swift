import SitRepCore
import SitRepEdge
import SitRepPanel

/// A part of the sidebar's list that folds under its heading: one of the card's sections, or Projects; or Your turn's
/// "N earlier", which opens in place.
public enum Fold: Hashable, Sendable {
    case section(BoardSection)
    case projects
    case earlier
}

/// What is folded: the sections Lee folded and whether Projects is, kept across launches; and whether "N earlier" is
/// open, never kept, as what it holds is stale. At first only Snoozed and Projects are folded.
public struct Folds: Codable, Equatable, Sendable {
    public var sections = BoardSection.foldedAtFirst
    public var projects = true
    public var isEarlierOpen = false

    /// Everything open, "N earlier" too: the list as it shows while the filter holds text.
    public static let open = Folds(sections: [], projects: false, isEarlierOpen: true)

    public init(
        sections: Set<BoardSection> = BoardSection.foldedAtFirst, projects: Bool = true, isEarlierOpen: Bool = false
    ) {
        self.sections = sections
        self.projects = projects
        self.isEarlierOpen = isEarlierOpen
    }

    public init(from decoder: any Decoder) {
        let defaults = Folds()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        // one by one, so a section another version saved that this one doesn't know leaves the rest folded; and one
        // folded at first, as Snoozed, that a value saved before it has no word of, folded
        sections = BoardSection.folded(saved: given.value(.sections, or: []), unfolded: given.value(.unfolded, or: []))
        projects = given.value(.projects, or: defaults.projects)
    }

    public func encode(to encoder: any Encoder) throws {
        var saved = encoder.container(keyedBy: CodingKeys.self)

        try saved.encode(BoardSection.allCases.filter(sections.contains).map(\.rawValue), forKey: .sections)
        try saved.encode(BoardSection.unfolded(sections), forKey: .unfolded)
        try saved.encode(projects, forKey: .projects)
    }

    /// What of them is kept across launches: "N earlier" folded, as each time the window opens.
    public var kept: Folds {
        Folds(sections: sections, projects: projects)
    }

    public func contains(_ fold: Fold) -> Bool {
        switch fold {
        case let .section(section): sections.contains(section)
        case .projects: projects
        case .earlier: !isEarlierOpen
        }
    }

    /// Folded, or unfolded where it was.
    public mutating func toggle(_ fold: Fold) {
        switch fold {
        case let .section(section):
            if sections.remove(section) == nil {
                sections.insert(section)
            }
        case .projects: projects.toggle()
        case .earlier: isEarlierOpen.toggle()
        }
    }

    /// Unfolded, where it was folded.
    mutating func unfold(_ fold: Fold) {
        if contains(fold) {
            toggle(fold)
        }
    }

    /// Unfolded wherever the list would hide the row showing this pick (`Listed.listedRow(showing:)`): a session's
    /// section, or Snoozed for its row there, and "N earlier" where its row is under it; Projects, for a project, or a
    /// session with no row of its own.
    mutating func unfold(toShow pick: Pick, in listed: Listed) {
        switch listed.listedRow(showing: pick) {
        case .project?:
            unfold(.projects)
        case let shown?:
            if let row = listed.rows.first(where: { $0.pick == shown }) {
                unfold(.section(row.section))
                if row.isEarlier {
                    unfold(.earlier)
                }
            }
        case nil:
            break
        }
    }

    private enum CodingKeys: String, CodingKey {
        case sections, unfolded, projects
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

/// The sidebar's list as it shows, the card's list at the window's size: each section with rows, Needs you, Working,
/// Your turn and Snoozed, under its heading, a session's row in one of the first three only, and in Snoozed beside it
/// where it has asks asleep; then Projects, every project on the board, under its own. A folded section shows its
/// heading alone; Your turn's rows past the fold period sit under "N earlier" at its end, shown only while it is
/// open. While the filter holds text, the folds Lee set stand aside
/// (`WindowRun.filter`).
public struct Sidebar: Equatable, Sendable {
    /// A heading that folds what is under it, a section's or Projects': its count, and which way it is.
    public struct Heading: Equatable, Sendable {
        public let fold: Fold
        /// Needs you's counts its lines waiting on Lee, the asks and stops, and Snoozed's its asks asleep; Working's
        /// and Your turn's their rows, "N earlier"'s among them; Projects' its projects.
        public let count: Int
        public let isFolded: Bool

        public var title: String {
            if case let .section(section) = fold {
                return section.title
            }
            return Words.projects
        }

        /// Its count in orange, as what needs Lee is.
        public var isNeedsYou: Bool { fold == .section(.needsYou) }
    }

    public enum Line: Equatable, Sendable, Identifiable {
        case heading(Heading)
        case session(Listed.Row)
        /// Your turn's "N earlier", which opens in place, as the card's does.
        case earlier(Earlier)
        case project(Listed.Project)

        public var id: ID {
            switch self {
            case let .heading(heading): .fold(heading.fold)
            case .earlier: .fold(.earlier)
            case let .session(row): .pick(row.pick)
            case let .project(project): .pick(project.pick)
            }
        }

        /// What a click on it picks; none on a heading or "N earlier", which fold.
        public var pick: Pick? {
            if case let .pick(pick) = id {
                return pick
            }
            return nil
        }

        public enum ID: Hashable, Sendable {
            case fold(Fold)
            case pick(Pick)
        }
    }

    /// How the board stands, for the list's place where it lists nothing.
    public let head: Head
    public let lines: [Line]
    /// Every row it holds, in order, folded or not: what moves as the board resorts, and a fold leaves alone.
    public let order: [Pick]
    /// The picks a fold hides, each by the line it is folded under: its section's heading, or "N earlier".
    private let folded: [Pick: Line.ID]
    /// The sessions with no row of their own, each by its project's row, which shows it.
    private let homes: [String: Pick]

    public init() {
        self.init(Listed(), folds: Folds())
    }

    /// The list, folded as given.
    public init(_ listed: Listed, folds: Folds) {
        let sections = BoardSection.allCases.map { Self.section($0, listed.rows(in: $0), folds: folds) }
        let projects = Self.projects(listed.projects, isFolded: folds.projects)

        head = listed.head
        lines = (sections + [projects]).flatMap(\.lines)
        order = listed.rows.map(\.pick) + listed.projects.map(\.pick)
        folded = Dictionary((sections + [projects]).flatMap(\.hidden)) { first, _ in first }
        homes = listed.rowless.mapValues(Pick.project).filter { listed.lists($0.value) }
    }

    /// The row that shows the pick, drawn picked: its own; for a session with no row of its own, its project's in
    /// Projects, which stands in for it. A pick it lists nowhere stands for itself, showing on no row.
    public func row(showing pick: Pick?) -> Pick? {
        switch pick {
        case let .session(id)?: homes[id] ?? pick
        case nil: nil
        case .snoozed?, .project?: pick
        }
    }

    /// The list's selection for the pick: the pick itself, the row it has; none where a project's row stands in for
    /// it, so a click on that row picks the project.
    public func selection(for pick: Pick?) -> Pick? {
        row(showing: pick) == pick ? pick : nil
    }

    /// A part of the list: its lines as they show, and the picks its folds hide, by the line each is folded under.
    private typealias Part = (lines: [Line], hidden: [(Pick, Line.ID)])

    /// A section with rows: its heading, then, unless it is folded, its rows; Your turn's past the fold period under
    /// "N earlier", at its end.
    private static func section(_ section: BoardSection, _ rows: [Listed.Row], folds: Folds) -> Part {
        guard !rows.isEmpty else {
            return ([], [])
        }

        let fold = Fold.section(section)
        let count = section.countsLines ? rows.map(\.lines.count).reduce(0, +) : rows.count
        let heading = Line.heading(Heading(fold: fold, count: count, isFolded: folds.contains(fold)))

        if folds.contains(fold) {
            return ([heading], rows.map { ($0.pick, heading.id) })
        }

        let earlier = rows.filter(\.isEarlier)
        let current = rows.filter { !$0.isEarlier }.map(Line.session)
        guard !earlier.isEmpty else {
            return ([heading] + current, [])
        }

        let line = Line.earlier(Earlier(projects: earlier.map(\.project), isOpen: folds.isEarlierOpen))

        return folds.isEarlierOpen
            ? ([heading] + current + [line] + earlier.map(Line.session), [])
            : ([heading] + current + [line], earlier.map { ($0.pick, line.id) })
    }

    /// Projects, with any: its heading, then, unless it is folded, a row for each.
    private static func projects(_ projects: [Listed.Project], isFolded: Bool) -> Part {
        guard !projects.isEmpty else {
            return ([], [])
        }

        let heading = Line.heading(Heading(fold: .projects, count: projects.count, isFolded: isFolded))

        return isFolded
            ? ([heading], projects.map { ($0.pick, heading.id) })
            : ([heading] + projects.map(Line.project), [])
    }

    /// It lists nothing.
    public var isEmpty: Bool { lines.isEmpty }

    /// The heading the rule after Needs you sits over: the next one after it, while Needs you shows, folded or not,
    /// and something follows it.
    public var ruled: Line.ID? {
        guard lines.first?.id == .fold(.section(.needsYou)) else {
            return nil
        }

        return lines.dropFirst().first { line in
            guard case .heading = line else {
                return false
            }
            return true
        }?.id
    }

    /// The rows a click or an arrow key picks, in order: every row but the headings and "N earlier".
    public var picks: [Pick] {
        lines.compactMap(\.pick)
    }

    /// The first row it shows that picks, a fold's hidden rows none of them: what Return in the Filter field opens.
    public var first: Pick? {
        picks.first
    }

    /// Where an arrow key goes from the pick where the list holds no selection on it.
    public enum Step: Equatable, Sendable {
        /// To this row.
        case to(Pick)
        /// Nowhere: no row that picks lies that way.
        case stays
        /// The list's own way, from the row it selects, or from a pick it does not list, as one filtered out.
        case listsOwn
    }

    /// An arrow key from a pick the list holds no selection on: one whose row a fold hides, which stands at the line it
    /// is folded under, its section's heading or "N earlier"; or one a project's row stands in for, which stands at
    /// that row, or, folded, at Projects' heading. To the first row that picks after that line, going down, or the last
    /// before it, going up.
    public func step(from pick: Pick?, down: Bool) -> Step {
        guard let line = standing(pick), let place = lines.firstIndex(where: { $0.id == line }) else {
            return .listsOwn
        }

        let beyond = down ? Array(lines[(place + 1)...]) : lines[..<place].reversed()

        return beyond.lazy.compactMap(\.pick).first.map(Step.to) ?? .stays
    }

    /// The line a pick the list holds no selection on stands at; none for one it selects, or lists nowhere.
    private func standing(_ pick: Pick?) -> Line.ID? {
        guard let row = row(showing: pick) else {
            return nil
        }
        return folded[row] ?? (row == pick ? nil : .pick(row))
    }
}
