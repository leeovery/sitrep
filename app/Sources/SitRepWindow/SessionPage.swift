import Foundation
import SitRepCore

/// A session at window size, as the pane's session view: its project above it, its name and summary, what its window
/// is doing, then Asks, Status, Notes, Parked and Resolved.
public struct SessionPage: Equatable, Sendable {
    public let id: String
    /// Its project, by its key, and its name, which opens the project.
    public let projectKey: String
    public let projectName: String
    public let name: String
    public let summary: String
    public let doing: Doing
    /// "Open in Ghostty ↗": only while a window holds it.
    public let jumps: Bool
    /// Its asks waiting on Lee.
    public let waiting: Int
    /// Its asks asleep.
    public let snoozed: Int
    /// Those waiting first, then those asleep.
    public let asks: [Card]
    public let status: Status
    /// Its latest log lines, newest first.
    public let notes: [Note]
    /// Oldest first.
    public let parked: [Parked]
    /// The newest closed first, those still keeping their place in Asks aside.
    public let resolved: [Resolved]
    /// "✓ Finish this session", only while no window holds it.
    public let finish: Finish?
    /// A board of it is kept: its asks, Notes, Parked and Resolved show as last kept.
    public let hasBoard: Bool
    /// Why the latest line to carry its board carried none, over its board as last kept, if there is one.
    public let failure: String?
    /// The items of Status, Notes, Parked and Resolved opened in place.
    public let opened: Set<Item>

    /// Its mark beside what it is doing: with asks waiting while no window holds it, the away ring, as its row's and
    /// its cards'; else what it is doing's.
    public var mark: Mark {
        doing.isAway && waiting > 0 ? .awayAsk : doing.mark
    }
}

public struct Status: Equatable, Sendable {
    public let now: [String]
    public let next: String?
    /// When its status last changed, as its log has it.
    public let updated: Date?
}

/// A resolved ask: its title, when it closed and how; closed by Lee's answer, the answer, as the board words it.
public struct Resolved: Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let closed: Date
    public let how: Card.Closed
    public let answer: String?

    /// It always opens to more than its line: how it closed.
    public var hasMore: Bool { true }
}

/// Finishing an away session, which asks first, in place.
public enum Finish: Equatable, Sendable {
    /// "✓ Finish this session".
    case offered
    /// "Finish …? Its open asks stop counting." with Yes, finish it and Cancel.
    case asking
    /// Yes pressed: `sitrep finish` runs.
    case finishing
    /// `sitrep finish` refused, in its words.
    case refused(String)
}
