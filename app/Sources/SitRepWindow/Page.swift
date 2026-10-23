import Foundation
import SitRepCore

/// What the right of the window shows: the session or the project Lee picked, or Settings; else a line saying why
/// there is none, as the head does before the board is read, or that no session is open at all.
public enum Page: Equatable, Sendable {
    case empty(String)
    case session(SessionPage)
    case project(ProjectPage)
    case settings

    static let nothingOpen = Page.empty("No session is open.")
}

/// What Lee picked to read on the right: a session or a project from the board's list, or Settings from the
/// sidebar's foot. A session with asks snoozed has a row in Snoozed too, its own pick, which shows the session's page
/// as its row beside it does.
public enum Pick: Hashable, Sendable {
    case session(String)
    /// A session's row in Snoozed.
    case snoozed(String)
    case project(String)
    case settings

    /// What it shows on the right, whichever of a session's rows holds it: the session.
    public var page: Pick {
        if case let .snoozed(id) = self {
            return .session(id)
        }
        return self
    }
}

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
    /// Its board has been read: its asks, Notes, Parked and Resolved show as last read.
    public let isRead: Bool
    /// Why the latest read of its board failed, over what was read before, if anything was.
    public let failure: String?
    /// The items of Status, Notes, Parked and Resolved opened in place.
    public let opened: Set<Item>
}

/// An item of Status, Notes, Parked or Resolved, which a press opens in place to the whole of it, and closes again.
public enum Item: Hashable, Sendable {
    /// A line of the status, by its place and its words, so a line rewritten is another item, closed, and two lines
    /// alike are two items.
    case status(Int, String)
    /// The status's next, by its words.
    case next(String)
    case note(String)
    case parked(String)
    case resolved(String)
}

public struct Status: Equatable, Sendable {
    public let now: [String]
    public let next: String?
    /// When its status last changed, as its log has it.
    public let updated: Date?
}

/// A line of a session's log, and in a project's view the session it is from; opened, its detail under it.
public struct Note: Equatable, Sendable, Identifiable {
    public let id: String
    public let session: String?
    public let text: String
    public let detail: [String]
    public let at: Date

    /// It opens to more than its line: its detail. Without, it opens only while its line is cut short.
    public var hasMore: Bool { !detail.isEmpty }
}

/// Something parked, and opened, where it was parked from.
public struct Parked: Equatable, Sendable, Identifiable {
    public let id: String
    public let session: String?
    public let title: String
    public let `where`: String?
    public let at: Date

    /// It opens to more than its line: where it was parked from. Without, it opens only while its line is cut short.
    public var hasMore: Bool { `where` != nil }
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

/// A project, opened from its name, as the pane's project view: its sessions, each with what it is doing and what
/// waits there; every session's asks, the newest first, each one line that opens in place into its card; their notes,
/// the newest first; their parked items, the oldest first. Each line names its session, unless the project has only
/// the one, which it can only name. There is no Resolved.
public struct ProjectPage: Equatable, Sendable {
    public struct Session: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let mark: Mark
        public let isAway: Bool
        public let doing: Doing
        /// Its rows that need Lee: asks and stops alike.
        public let waiting: Int
        public let since: Date
    }

    /// An ask, one line naming its session, or opened into its card.
    public struct Ask: Equatable, Sendable, Identifiable {
        public let session: String?
        public let card: Card
        public let isOpened: Bool

        public var id: AskAddress { card.id }
    }

    public let key: String
    public let name: String
    /// What waits on Lee there: its rows that need Lee.
    public let waiting: Int
    /// How many of its sessions a window holds.
    public let open: Int
    public let sessions: [Session]
    /// Its asks waiting on Lee.
    public let asksWaiting: Int
    public let asks: [Ask]
    public let notes: [Note]
    public let parked: [Parked]
    /// Its notes and parked items opened in place.
    public let opened: Set<Item>
}
