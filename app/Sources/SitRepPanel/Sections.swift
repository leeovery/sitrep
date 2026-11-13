import Foundation

/// What a row in Needs you waits on Lee for, which its mark's colour says (DESIGN, "The rows", 13 November 2026): an
/// ask, a permission prompt or a question, in orange; or his turn, in blue, its window having finished its turn.
public enum Need: Hashable, CaseIterable, Sendable {
    case ask, turn
}

/// The card's sections, in their order: Needs you, Working, then Snoozed (DESIGN, "The rows", and "Snooze"). A row is
/// in one, by its session's state: Needs you holds what waits on Lee, asks and turns alike (13 November 2026); on its
/// own work is in Working, at its end. A session with asks snoozed has a row in Snoozed too, beside any it has in
/// another. Your turn was a section of its own until then, whose saved fold is passed over as any name unknown is.
public enum BoardSection: String, CaseIterable, Codable, Comparable, Sendable {
    case needsYou, working, snoozed

    public static func < (lhs: BoardSection, rhs: BoardSection) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }

    /// Its eyebrow's words.
    public var title: String {
        switch self {
        case .needsYou: "Needs you"
        case .working: "Working"
        case .snoozed: "Snoozed"
        }
    }

    /// Counted by its lines, not its rows: Needs you's asks and stops waiting, and its turns, a line each; Snoozed's
    /// asks asleep, and its turns.
    public var countsLines: Bool { self == .needsYou || self == .snoozed }

    /// Folded until Lee unfolds it: Snoozed, which holds nothing waiting on Lee.
    public var isFoldedAtFirst: Bool { self == .snoozed }

    /// The sections folded where Lee has folded none.
    public static let foldedAtFirst = Set(allCases.filter(\.isFoldedAtFirst))

    /// The sections folded, as a value saved lists them: those it lists folded, and those folded at first that it
    /// does not list unfolded, as a value saved before such a section was has no word of it. Names this version does
    /// not know are passed over.
    public static func folded(saved folded: [String], unfolded: [String]) -> Set<BoardSection> {
        Set(allCases.filter { folded.contains($0.rawValue) || $0.isFoldedAtFirst && !unfolded.contains($0.rawValue) })
    }

    /// The sections not folded, by their names, which a value saved lists beside those folded.
    public static func unfolded(_ folded: Set<BoardSection>) -> [String] {
        allCases.filter { !folded.contains($0) }.map(\.rawValue)
    }
}

extension Session {
    /// The section its row is in.
    public var section: BoardSection {
        switch kind {
        case .needs, .turn: .needsYou
        case .working, .onItsWork: .working
        case .snoozed, .snoozedTurn: .snoozed
        }
    }

    /// What it waits on Lee for, needing him or snoozed: an ask, or his turn; nil while it works.
    public var need: Need? {
        switch kind {
        case .needs, .snoozed: .ask
        case .turn, .snoozedTurn: .turn
        case .working, .onItsWork: nil
        }
    }
}

extension [Session] {
    /// The board's rows in the panel's order, every surface's (13 November 2026): Needs you's asks first, then its
    /// turns, each those this Mac shows before the away ones; then the rest. Each part keeps core's order, newest first
    /// in Needs you, away by core's word last; so a session held where this Mac doesn't show it, which core puts among
    /// those it shows, leads the away ones.
    public func inPanelOrder() -> [Session] {
        let waiting = Need.allCases.flatMap { need in
            let rows = filter { $0.section == .needsYou && $0.need == need }

            return rows.filter { !$0.away } + rows.filter(\.away)
        }

        return waiting + filter { $0.section != .needsYou }
    }
}

/// A section's eyebrow: its name, its counts, and whether it is folded to the eyebrow alone.
public struct Eyebrow: Equatable, Sendable {
    /// One of its figures: how many it counts, and, in Needs you, what they wait on Lee for, which its colour says.
    public struct Count: Equatable, Sendable {
        public let value: Int
        /// Needs you's asks or its stopped, apart; nil for a section counted whole.
        public let need: Need?

        public init(_ value: Int, need: Need? = nil) {
            self.value = value
            self.need = need
        }
    }

    public let section: BoardSection
    /// Needs you's two, side by side, its asks then its stopped, each only above zero (13 November 2026): the asks
    /// counting the lines of its ask rows, the asks and the windows stopped on a prompt, and the stopped its your-turn
    /// rows, one a session. Snoozed's one counts the asks asleep, and the others' one their rows.
    public let counts: [Count]
    public let isFolded: Bool
    /// The room over its 28: 4 under the card's top, else 14 under the row or the eyebrow above it, which is all that
    /// tells the sections apart (board J).
    public let above: Double

    public init(section: BoardSection, counts: [Count], isFolded: Bool, above: Double) {
        self.section = section
        self.counts = counts
        self.isFolded = isFolded
        self.above = above
    }

    /// The room over the first eyebrow, under the card's top, and over each after it.
    public static let first = 4.0, after = 14.0
}

/// What Lee folded on the card: the sections folded to their eyebrows.
public struct CardFolds: Equatable, Sendable {
    public var sections: Set<BoardSection>

    public init(sections: Set<BoardSection> = BoardSection.foldedAtFirst) {
        self.sections = sections
    }

    /// A section folded, or unfolded.
    public mutating func toggle(_ section: BoardSection) {
        if sections.remove(section) == nil {
            sections.insert(section)
        }
    }
}

extension Item {
    /// The card's list of these sessions, in the order given: each section with any rows, in the sections' order,
    /// under its eyebrow, or its eyebrow alone where it is folded, every row on one line, every turn's however long
    /// ago it ended. Only the room over each eyebrow tells the sections apart, with no hairline (board J).
    public static func card(_ sessions: [Session], folds: CardFolds) -> [Item] {
        BoardSection.allCases.map { section in (section, sessions.filter { $0.section == section }) }
            .filter { !$0.1.isEmpty }
            .enumerated()
            .flatMap { index, shown in
                let (section, rows) = shown
                let isFolded = folds.sections.contains(section)
                let above = index == 0 ? Eyebrow.first : Eyebrow.after
                let eyebrow = Eyebrow(section: section, counts: counts(rows, in: section), isFolded: isFolded, above: above)

                return [Item.eyebrow(eyebrow)] + (isFolded ? [] : rows.map(Item.line))
            }
    }

    /// Needs you's asks, by their rows' lines, and its stopped, by their rows, apart, those above zero; another
    /// section's rows, or lines, whole.
    private static func counts(_ rows: [Session], in section: BoardSection) -> [Eyebrow.Count] {
        guard section == .needsYou else {
            return [Eyebrow.Count(count(rows, in: section))]
        }

        let asks = rows.filter { $0.need == .ask }.map(\.lines.count).reduce(0, +)
        let stopped = rows.filter { $0.need == .turn }.count

        return [Eyebrow.Count(asks, need: .ask), Eyebrow.Count(stopped, need: .turn)].filter { $0.value > 0 }
    }

    private static func count(_ rows: [Session], in section: BoardSection) -> Int {
        section.countsLines ? rows.map(\.lines.count).reduce(0, +) : rows.count
    }
}
