import Foundation

/// The card's sections, in their order: Needs you, Your turn, Working, then Snoozed (DESIGN, "The rows", and
/// "Snooze"). A row is in one, by its session's state; on its own work is in Working, at its end. A session with asks
/// snoozed has a row in Snoozed too, beside any it has in another.
public enum BoardSection: String, CaseIterable, Codable, Comparable, Sendable {
    case needsYou, yourTurn, working, snoozed

    public static func < (lhs: BoardSection, rhs: BoardSection) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }

    /// Its eyebrow's words.
    public var title: String {
        switch self {
        case .needsYou: "Needs you"
        case .working: "Working"
        case .yourTurn: "Your turn"
        case .snoozed: "Snoozed"
        }
    }

    /// Waiting on Lee, above the menu's separator: Needs you, and Your turn, Lee's to write in.
    public var waitsOnLee: Bool { self == .needsYou || self == .yourTurn }

    /// Counted by its lines, the asks and stops waiting or the asks asleep, not its rows.
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
        case .needs: .needsYou
        case .working, .onItsWork: .working
        case .turn: .yourTurn
        case .snoozed, .snoozedTurn: .snoozed
        }
    }
}

/// A section's eyebrow: its name, its count, and whether it is folded to the eyebrow alone.
public struct Eyebrow: Equatable, Sendable {
    public let section: BoardSection
    /// Needs you's counts its waiting lines, the asks and stops, and Snoozed's the asks asleep; the others count their
    /// rows.
    public let count: Int
    public let isFolded: Bool
    /// The room over its 28: 4 under the card's top, else 14 under the row or the eyebrow above it, which is all that
    /// tells the sections apart (board J).
    public let above: Double

    public init(section: BoardSection, count: Int, isFolded: Bool, above: Double) {
        self.section = section
        self.count = count
        self.isFolded = isFolded
        self.above = above
    }

    /// The room over the first eyebrow, under the card's top, and over each after it.
    public static let first = 4.0, after = 14.0
}

/// Your turn's "N earlier" in the SitRep window's sidebar: the sessions whose turn ended longer ago than the fold
/// period, in one line, which opens in place to show them. The card shows every your-turn row (board J).
public struct Earlier: Equatable, Sendable {
    public let count: Int
    /// Their projects, each once, in the rows' order.
    public let projects: [String]
    public let isOpen: Bool

    public init(_ sessions: [Session], isOpen: Bool) {
        self.init(projects: sessions.map(\.project), isOpen: isOpen)
    }

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

/// How long a your-turn row stays in the SitRep window's sidebar before it folds into "N earlier".
public enum FoldPeriod: String, CaseIterable, Codable, Sendable {
    case hour, fourHours, today, never

    /// When on the wall clock, ms, a turn that ended at `since` folds: an hour or four after it, at the local midnight
    /// after it, or never.
    public func folds(_ since: Double, in calendar: Calendar) -> Double? {
        switch self {
        case .hour: since + Self.anHour
        case .fourHours: since + 4 * Self.anHour
        case .today: Self.midnight(after: since, in: calendar)
        case .never: nil
        }
    }

    /// Whether a turn that ended at `since` is folded at `now`, both ms on the wall clock.
    public func isPast(_ since: Double, at now: Double, in calendar: Calendar) -> Bool {
        folds(since, in: calendar).map { $0 <= now } ?? false
    }

    private static let anHour = 3_600_000.0

    private static func midnight(after time: Double, in calendar: Calendar) -> Double? {
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: time / 1000))

        return calendar.date(byAdding: .day, value: 1, to: day).map { $0.timeIntervalSince1970 * 1000 }
    }
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
    /// under its eyebrow, or its eyebrow alone where it is folded, every row on one line, Your turn's every one. Only
    /// the room over each eyebrow tells the sections apart, with no hairline (board J).
    public static func card(_ sessions: [Session], folds: CardFolds) -> [Item] {
        BoardSection.allCases.map { section in (section, sessions.filter { $0.section == section }) }
            .filter { !$0.1.isEmpty }
            .enumerated()
            .flatMap { index, shown in
                let (section, rows) = shown
                let isFolded = folds.sections.contains(section)
                let above = index == 0 ? Eyebrow.first : Eyebrow.after
                let eyebrow = Eyebrow(section: section, count: count(rows, in: section), isFolded: isFolded, above: above)

                return [Item.eyebrow(eyebrow)] + (isFolded ? [] : rows.map(Item.line))
            }
    }

    private static func count(_ rows: [Session], in section: BoardSection) -> Int {
        section.countsLines ? rows.map(\.lines.count).reduce(0, +) : rows.count
    }
}
