import Foundation
import SitRepCore
import SitRepPanel

/// The board `watch` last printed, in the panel's terms: its rows as the panel's sessions, in core's order, its
/// Snoozed rows apart from them, its head, whether anything needs Lee, and what is new. Core decided every one of them;
/// this decides nothing, and only says them as the panel does.
public struct PanelBoard: Equatable, Sendable {
    /// In core's order: the strip's and the menu's, and the card's but for Snoozed.
    public let sessions: [Session]
    /// The card's Snoozed rows, the soonest to wake first, which the strip and the menu leave out.
    public let snoozed: [Session]
    public let head: Head
    public let needsLee: Bool
    /// The rows holding a line needing Lee that is new on this board, by their sessions: the notch's swell, and each
    /// row's wash.
    public let new: Set<String>
    /// The strip's words for the board, which it has no head to say: before any board, the head's title; while the
    /// board is stale, when it was last known current, "as of 12:04".
    public let unread: String?
    public let asOf: String?

    /// Until `watch` prints its first line.
    static let looking = Head(title: "Looking for sessions…", count: "")
    /// `watch` stopped before it printed any.
    public static let unread = Head(title: "SitRep can't read the board", count: "")

    /// Before `watch` prints its first line.
    public init() {
        self.init(LastBoard())
    }

    /// With no `watch` to run, its head says why.
    public init(unrun why: String) {
        self.init(
            sessions: [], snoozed: [], head: Head(title: why, count: ""), needsLee: false, new: [], unread: why, asOf: nil
        )
    }

    /// The board as last heard. While it is stale, its rows stay as they were and its head says when it was last
    /// known current, "as of 12:04", as the menu's does.
    public init(_ last: LastBoard, clock: Date.FormatStyle = .init(date: .omitted, time: .shortened)) {
        guard let board = last.board else {
            let head = last.stale == nil ? Self.looking : Self.unread

            self.init(sessions: [], snoozed: [], head: head, needsLee: false, new: [], unread: head.title, asOf: nil)
            return
        }

        let head = Head(needYou: board.head.needYou, sessions: board.head.sessions)
        let asOf = last.staleSince.map { "as of \($0.formatted(clock))" }

        self.init(
            sessions: board.rows.map(Session.init),
            snoozed: board.snoozed.map(Session.init),
            head: asOf.map { Head(title: head.title, count: $0) } ?? head,
            needsLee: !board.head.isAllClear,
            // stale, the last line's new rows are not new again
            new: last.stale == nil ? board.newRows : [],
            unread: nil,
            asOf: asOf
        )
    }

    /// A board of these rows, in this order, none in Snoozed, as a picture of the edge shows one: its head from their
    /// counts, and the rows new on it by their sessions.
    public init(rows: [Session], new: Set<String> = []) {
        let needYou = rows.filter(\.needsLee).count

        self.init(
            sessions: rows, snoozed: [], head: Head(needYou: needYou, sessions: rows.count), needsLee: needYou > 0,
            new: new, unread: nil, asOf: nil
        )
    }

    private init(
        sessions: [Session], snoozed: [Session], head: Head, needsLee: Bool, new: Set<String>, unread: String?,
        asOf: String?
    ) {
        self.sessions = sessions
        self.snoozed = snoozed
        self.head = head
        self.needsLee = needsLee
        self.new = new
        self.unread = unread
        self.asOf = asOf
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

    /// The card's rows: core's, then Snoozed's.
    public var cardSessions: [Session] { sessions + snoozed }

    /// Nothing for the card to list: no row, nor any in Snoozed.
    public var isEmpty: Bool { sessions.isEmpty && snoozed.isEmpty }
}

extension Session {
    /// A row as the panel draws it, keyed by its session so it keeps its place: its project by name, and core's
    /// letters for it; its session's name; its lines; and beneath them, needing Lee, its project, else core's second
    /// line, an away one's saying no window holds it.
    init(_ row: Board.Row) {
        let isNamed = row.needsLee && !row.isAway

        self.init(
            id: row.session, project: row.projectName, name: row.name, letters: row.letters,
            kind: Kind(row.newest.kind), away: row.isAway, lines: row.lines.map(Line.init),
            sub: isNamed ? row.projectName : row.second
        )
    }

    /// A Snoozed row as the card draws it, its asks' or its turn's, named as a Needs you row is: its project beneath
    /// its name; when its soonest line wakes in its time's place, none for a turn snoozed until it moves.
    init(_ row: Board.SnoozedRow) {
        self.init(
            id: row.session, project: row.projectName, name: row.name, letters: row.letters,
            kind: row.isTurn ? .snoozedTurn : .snoozed, away: row.isAway, lines: row.lines.map(Line.init),
            sub: row.projectName, wakesAt: row.wakesAt.map { $0.timeIntervalSince1970 * 1000 }
        )
    }
}

private extension Session.Line {
    /// A line as the panel draws it: its lead, then after a space its subject, in mono or plain, or the wake it counts
    /// down to, and a question's "+2"; its time from `since`.
    init(_ line: Board.Row.Line) {
        let words = line.first
        let isFollowed = words.mono != nil || words.subject != nil || words.until != nil

        self.init(
            ask: line.ask, title: isFollowed ? words.lead + " " : words.lead, code: words.mono, subject: words.subject,
            until: words.until.map { $0.timeIntervalSince1970 * 1000 }, more: words.more,
            since: line.since.timeIntervalSince1970 * 1000
        )
    }

    /// An ask asleep, or a turn, its title its words, its time from `since`.
    init(_ line: Board.SnoozedRow.Line) {
        self.init(ask: line.ask, title: line.first.lead, since: line.since.timeIntervalSince1970 * 1000)
    }
}

private extension Session.Kind {
    init(_ kind: Board.Row.Line.Kind) {
        switch kind {
        case .ask, .permission, .question: self = .needs
        case .yourTurn: self = .turn
        case .working: self = .working
        case .onItsWork: self = .onItsWork
        }
    }
}
