import Foundation
import SitRepCore
import SitRepPanel

/// The board `watch` last printed, in the panel's terms: its rows as the panel's sessions, in core's order, its head,
/// whether anything needs Lee, and what is new. Core decided every one of them; this decides nothing, and only says
/// them as the panel does.
public struct PanelBoard: Equatable, Sendable {
    /// In core's order.
    public let sessions: [Session]
    public let head: Head
    public let needsLee: Bool
    /// The rows needing Lee that are new on this board, by their keys: the notch's swell, and each row's wash.
    public let new: Set<String>
    /// The strip's words for the board, which it has no head to say: before any board, the head's title; while the
    /// board is stale, when it was last known current, "as of 12:04".
    public let unread: String?
    public let asOf: String?
    /// Each row's session, by the row's key, for the jump.
    private let sessionOf: [String: String]

    /// Until `watch` prints its first line.
    static let looking = Head(title: "Looking for sessions…", count: "")
    /// `watch` stopped before it printed any.
    static let unread = Head(title: "SitRep can't read the board", count: "")

    /// Before `watch` prints its first line.
    public init() {
        self.init(LastBoard())
    }

    /// With no `watch` to run, its head says why.
    public init(unrun why: String) {
        self.init(sessions: [], head: Head(title: why, count: ""), needsLee: false, new: [], unread: why, asOf: nil)
    }

    /// The board as last heard. While it is stale, its rows stay as they were and its head says when it was last
    /// known current, "as of 12:04", as the menu's does.
    public init(_ last: LastBoard, clock: Date.FormatStyle = .init(date: .omitted, time: .shortened)) {
        guard let board = last.board else {
            let head = last.stale == nil ? Self.looking : Self.unread

            self.init(sessions: [], head: head, needsLee: false, new: [], unread: head.title, asOf: nil)
            return
        }

        let head = Head(needYou: board.head.needYou, sessions: board.head.sessions)
        let asOf = last.staleSince.map { "as of \($0.formatted(clock))" }
        let names = Dictionary(board.projects.map { ($0.key, $0.name) }) { first, _ in first }

        self.init(
            sessions: board.rows.map { Session($0, project: names[$0.project] ?? $0.project) },
            head: asOf.map { Head(title: head.title, count: $0) } ?? head,
            needsLee: !board.head.isAllClear,
            // stale, the last line's new rows are not new again
            new: last.stale == nil ? Set(board.new) : [],
            unread: nil,
            asOf: asOf,
            sessionOf: Dictionary(board.rows.map { ($0.key, $0.session) }) { first, _ in first }
        )
    }

    private init(
        sessions: [Session], head: Head, needsLee: Bool, new: Set<String>, unread: String?, asOf: String?,
        sessionOf: [String: String] = [:]
    ) {
        self.sessions = sessions
        self.head = head
        self.needsLee = needsLee
        self.new = new
        self.unread = unread
        self.asOf = asOf
        self.sessionOf = sessionOf
    }

    /// Tells the notch what this board brings after the last: a row new on it swells the notch; something needing
    /// Lee where nothing did, with nothing new, as on every run's first line, lights it with no swell. Nothing
    /// needing Lee any more the notch hears from its frames' `needsLee`.
    public func tell(_ notch: any Notch, after last: PanelBoard) {
        if !new.isEmpty {
            notch.newAsk()
        } else if needsLee, !last.needsLee {
            notch.needsLeeQuietly()
        }
    }

    /// The session a click on this row jumps to; nil for an away one, which no window holds.
    public func jump(_ row: Session) -> String? {
        row.jumps ? sessionOf[row.id] : nil
    }
}

extension Session {
    /// A row as the panel draws it, keyed by the row's key so it keeps its place: its project by name, and core's
    /// letters for it; its first line's lead, then its subject in mono after a space, and a question's "+2"; core's
    /// second line beneath, an away ask's saying so; its time from `since`.
    init(_ row: Board.Row, project: String) {
        self.init(
            id: row.key, project: project, letters: row.letters, kind: Kind(row.kind), away: row.isAway,
            title: row.first.mono == nil ? row.first.lead : row.first.lead + " ", code: row.first.mono,
            more: row.first.more, sub: row.second, since: row.since.timeIntervalSince1970 * 1000
        )
    }
}

private extension Session.Kind {
    init(_ kind: Board.Row.Kind) {
        switch kind {
        case .ask, .permission, .question: self = .needs
        case .yourTurn: self = .turn
        case .working: self = .working
        }
    }
}
