import Foundation

/// The card's sections, in their order: Needs you, Working, Your turn, then Snoozed (DESIGN, "The rows", and
/// "Snooze"). A row is in one, by its session's state; on its own work is in Working, at its end. A session with asks
/// snoozed has a row in Snoozed too, beside any it has in another.
public enum BoardSection: String, CaseIterable, Codable, Comparable, Sendable {
    case needsYou, working, yourTurn, snoozed

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
        case .snoozed: .snoozed
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
    /// The room over its 28: 4 under the card's top, none straight after the hairline, 10 under the section before.
    public let above: Double

    public init(section: BoardSection, count: Int, isFolded: Bool, above: Double) {
        self.section = section
        self.count = count
        self.isFolded = isFolded
        self.above = above
    }
}

/// Your turn's "N earlier": the sessions whose turn ended longer ago than the fold period, in one line, which opens in
/// place to show them.
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

/// How long a your-turn row stays on the card before it folds into "N earlier": Settings' "Your turn folds after".
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

/// What Lee folded on the card: the sections folded to their eyebrows, and whether "N earlier" is open.
public struct CardFolds: Equatable, Sendable {
    public var sections: Set<BoardSection>
    public var isEarlierOpen: Bool

    public init(sections: Set<BoardSection> = BoardSection.foldedAtFirst, isEarlierOpen: Bool = false) {
        self.sections = sections
        self.isEarlierOpen = isEarlierOpen
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
    /// under its eyebrow, or its eyebrow alone where it is folded; the hairline after Needs you where another section
    /// follows, folded or not. Needs you's, Working's and Snoozed's rows are drawn whole, Your turn's on one line each,
    /// those `isEarlier` says are past the fold period under "N earlier" at its end, shown under it only while it is
    /// open.
    public static func card(
        _ sessions: [Session], folds: CardFolds, isEarlier: (Session) -> Bool
    ) -> [Item] {
        let sections = BoardSection.allCases.map { section in (section, sessions.filter { $0.section == section }) }
            .filter { !$0.1.isEmpty }

        return sections.enumerated().flatMap { index, shown in
            let (section, rows) = shown
            let above = index == 0 ? 4.0 : sections[index - 1].0 == .needsYou ? 0 : 10
            let isFolded = folds.sections.contains(section)
            let eyebrow = Item.eyebrow(Eyebrow(section: section, count: count(rows, in: section), isFolded: isFolded, above: above))
            let after: [Item] = section == .needsYou && index < sections.count - 1 ? [.divider] : []

            return [eyebrow] + (isFolded ? [] : items(rows, in: section, folds: folds, isEarlier: isEarlier)) + after
        }
    }

    private static func count(_ rows: [Session], in section: BoardSection) -> Int {
        section.countsLines ? rows.map(\.lines.count).reduce(0, +) : rows.count
    }

    private static func items(
        _ rows: [Session], in section: BoardSection, folds: CardFolds, isEarlier: (Session) -> Bool
    ) -> [Item] {
        guard section == .yourTurn else {
            return rows.map(Item.session)
        }

        let earlier = rows.filter(isEarlier)
        let line = earlier.isEmpty ? [] : [Item.earlier(Earlier(earlier, isOpen: folds.isEarlierOpen))]

        return rows.filter { !isEarlier($0) }.map(Item.turn) + line + (folds.isEarlierOpen ? earlier.map(Item.turn) : [])
    }
}
