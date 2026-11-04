import Foundation
import SitRepCore

/// What the right of the window shows: the session or the project Lee picked; else a line saying why there is none,
/// as the head does before the board is read, or that no session is open at all.
public enum Page: Equatable, Sendable {
    case empty(String)
    case session(SessionPage)
    case project(ProjectPage)

    static let nothingOpen = Page.empty("No session is open.")
}

/// What Lee picked to read on the right: a session or a project from the board's list. A session with asks snoozed
/// has a row in Snoozed too, its own pick, which shows the session's page as its row beside it does.
public enum Pick: Hashable, Sendable {
    case session(String)
    /// A session's row in Snoozed.
    case snoozed(String)
    case project(String)

    /// What it shows on the right, whichever of a session's rows holds it: the session.
    public var page: Pick {
        if case let .snoozed(id) = self {
            return .session(id)
        }
        return self
    }
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
