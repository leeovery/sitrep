import Foundation
import SitRepCore

/// What the page shows: beside a place's list, the session of the row its list picked, the detail; filling the
/// window, a project's page or a session's; else a line saying why there is none, as the head does before the board is
/// read or with nothing picked, or that no session is open at all.
public enum Page: Equatable, Sendable {
    case empty(String)
    /// Beside a place's list: the session its picked row shows, kept as the row leaves the list.
    case detail(SessionPage)
    /// A session's page, filling the window, pushed from a place or a project.
    case session(SessionPage)
    case project(ProjectPage)

    static let nothingOpen = Page.empty("No session is open.")
}

/// Which page shows, a session's or a project's, whichever way the window came to it: what the page is drawn afresh
/// by, and with where it shows, what turning to another lets go of the last one's asks kept in place by (`Leaf`).
public enum Pick: Hashable, Sendable {
    case session(String)
    case project(String)
}

extension Location {
    /// Which page shows here: the session of the row the list picked, kept as the row leaves the list; a project's;
    /// a session's pushed. None for a place with nothing picked.
    public var page: Pick? {
        switch self {
        case let .place(_, picked, _): picked.map { .session($0.session) }
        case let .project(key): .project(key)
        case let .session(id, _): .session(id)
        }
    }
}

/// A page as turning goes: which page shows, and whether it fills the window, so a session's page beside the list and
/// the same session's filling the window are two pages, Back or Forward between them turning from one to the other.
struct Leaf: Equatable {
    let page: Pick?
    let fillsWindow: Bool
}

extension Location {
    var leaf: Leaf {
        Leaf(page: page, fillsWindow: place == nil)
    }
}

/// An item that opens in place to the whole of it, and closes again: a line of a session's Now, a line of its log or
/// an ask in What happened, a line of a project's notes, a project's parked item, an ask a session resolved.
public enum Item: Hashable, Sendable {
    /// A line of the status, by its place and its words, so a line rewritten is another item, closed, and two lines
    /// alike are two items.
    case status(Int, String)
    /// The status's next, by its words.
    case next(String)
    case note(String)
    /// An ask of What happened, "Asked …".
    case asked(AskAddress)
    case parked(String)
    case resolved(String)
    /// "N resolved" at the end of a session's What happened, which opens to its resolved asks.
    case resolvedFold
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

extension Note {
    /// A session's log lines as notes, each by an id that stays as lines come: its session's and its own; for a line
    /// without one, its kind, time, writer and words, and among lines alike in all of those, which of them it is,
    /// counted from the oldest, as new lines come at the top. In a project's view of several sessions each names its
    /// session.
    static func notes(_ log: [SessionBoard.Line], of session: Board.Session, named: Bool) -> [Note] {
        var seen: [String: Int] = [:]
        let ids = log.reversed().map { line in
            let own = line.id ?? "\(line.kind.rawValue)@\(line.at.timeIntervalSince1970):\(line.by):\(line.text)"
            let repeats = seen[own, default: 0]

            seen[own] = repeats + 1
            return repeats == 0 ? own : "\(own)#\(repeats)"
        }

        return zip(log, ids.reversed()).map { line, own in
            Note(id: "\(session.id):\(own)", session: named ? session.name : nil, text: line.text, detail: line.detail, at: line.at)
        }
    }
}
