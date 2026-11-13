import Foundation
import SitRepCore
import SitRepPanel

/// The board `watch` last printed, in the panel's terms: its rows as the panel's sessions, in the panel's order, its
/// Snoozed rows apart from them, its head, what lights the notch, and what is new. Core decided the rows; this orders
/// Needs you's asks and turns (`inPanelOrder`), counts what needs Lee, asks and turns alike, and says them as the panel
/// does.
public struct PanelBoard: Equatable, Sendable {
    /// In the panel's order: the strip's and the menu's, and the card's but for Snoozed.
    public let sessions: [Session]
    /// The card's Snoozed rows, the soonest to wake first, which the strip and the menu leave out.
    public let snoozed: [Session]
    /// "11 need you": the asks and stops waiting, and the sessions at Lee's turn.
    public let head: Head
    /// What lights the notch: an ask while any waits, else Lee's turn while any session stands at it; nil with
    /// neither (DESIGN, "The notch and its panel", 13 November 2026).
    public let need: Need?
    /// The rows holding a line needing Lee that is new on this board, by their sessions: the notch's pulse, and each
    /// row's wash.
    public let new: Set<String>
    /// The sessions this board moved into Lee's turn, by their ids (`LastBoard.newTurns`): the notch's pulse.
    public let newTurns: Set<String>
    /// What pulses the notch as it comes, as Lee set it: a new ask, Lee's turn, or both.
    public let pulses: Set<Need>
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
        self.init(sessions: [], snoozed: [], head: Head(title: why, count: ""), unread: why)
    }

    /// The board as last heard, the sessions a window holds that this Mac does not show (`notHere`) drawn as away ones
    /// are (DESIGN, stage 8, "The rows"), and what pulses the notch, a new ask alone unless Lee set otherwise. While it
    /// is stale, its rows stay as they were and its head says when it was last known current, "as of 12:04", as the
    /// menu's does.
    public init(
        _ last: LastBoard, notHere: Set<String> = [], pulses: Set<Need> = [.ask],
        clock: Date.FormatStyle = .init(date: .omitted, time: .shortened)
    ) {
        guard let board = last.board else {
            let head = last.stale == nil ? Self.looking : Self.unread

            self.init(sessions: [], snoozed: [], head: head, unread: head.title)
            return
        }

        let turns = board.rows.filter { $0.section == .yourTurn }.count
        let head = Head(needYou: board.head.needYou + turns, sessions: board.head.sessions)
        let asOf = last.staleSince.map { "as of \($0.formatted(clock))" }
        // stale, the last line's arrivals are not new again
        let isCurrent = last.stale == nil

        self.init(
            sessions: board.rows.map { Session($0, isHere: !notHere.contains($0.session)) }.inPanelOrder(),
            snoozed: board.snoozed.map { Session($0, isHere: !notHere.contains($0.session)) },
            head: asOf.map { Head(title: head.title, count: $0) } ?? head,
            need: board.head.needYou > 0 ? .ask : turns > 0 ? .turn : nil,
            new: isCurrent ? board.newRows : [],
            newTurns: isCurrent ? last.newTurns : [],
            pulses: pulses,
            asOf: asOf
        )
    }

    /// A board of these rows, none in Snoozed, as a picture of the edge shows one, in the panel's order: its head from
    /// their counts, and the rows new on it by their sessions, which pulse the notch.
    public init(rows: [Session], new: Set<String> = []) {
        let waiting = rows.filter { $0.section == .needsYou }

        self.init(
            sessions: rows.inPanelOrder(), snoozed: [],
            head: Head(needYou: waiting.map(\.lines.count).reduce(0, +), sessions: rows.count),
            need: waiting.contains(where: \.needsLee) ? .ask : waiting.isEmpty ? nil : .turn, new: new
        )
    }

    private init(
        sessions: [Session], snoozed: [Session], head: Head, need: Need? = nil, new: Set<String> = [],
        newTurns: Set<String> = [], pulses: Set<Need> = [.ask], unread: String? = nil, asOf: String? = nil
    ) {
        self.sessions = sessions
        self.snoozed = snoozed
        self.head = head
        self.need = need
        self.new = new
        self.newTurns = newTurns
        self.pulses = pulses
        self.unread = unread
        self.asOf = asOf
    }

    /// Whether anything needs Lee, an ask or his turn: the notch lit, at its size for it.
    public var needsLee: Bool { need != nil }

    /// Tells the notch what this board brings after the last: a row new on it, or a session moved into Lee's turn,
    /// pulses the notch where Lee has that pulse on; something needing Lee where nothing did, with no pulse, as on
    /// every run's first line, lights it with none. Nothing needing Lee any more the notch hears from its frames'
    /// `needsLee`.
    public func tell(_ notch: any Notch, after last: PanelBoard) {
        if pulses.contains(.ask) && !new.isEmpty || pulses.contains(.turn) && !newTurns.isEmpty {
            notch.newAsk()
        } else if needsLee, !last.needsLee {
            notch.needsLeeQuietly()
        }
    }

    /// The board told again, as what this Mac shows changes: nothing on it new again, so nothing pulses or washes
    /// twice for one line.
    public var retold: PanelBoard {
        PanelBoard(
            sessions: sessions, snoozed: snoozed, head: head, need: need, pulses: pulses, unread: unread, asOf: asOf
        )
    }

    /// The card's rows: the panel's, then Snoozed's.
    public var cardSessions: [Session] { sessions + snoozed }

    /// Nothing for the card to list: no row, nor any in Snoozed.
    public var isEmpty: Bool { sessions.isEmpty && snoozed.isEmpty }
}

extension Session {
    /// A row as the panel draws it, keyed by its session so it keeps its place: its project by name, and core's
    /// letters for it; its session's name; its lines; and beneath them, needing Lee, its project, else core's second
    /// line, an away one's saying no window holds it. Not here, a held one is drawn away, keeping its words.
    init(_ row: Board.Row, isHere: Bool = true) {
        let isNamed = row.needsLee && !row.isAway

        self.init(
            id: row.session, project: row.projectName, name: row.name, letters: row.letters,
            kind: Kind(row.newest.kind), away: row.isAway || !isHere, lines: row.lines.map(Line.init),
            sub: isNamed ? row.projectName : row.second
        )
    }

    /// A Snoozed row as the card draws it, its asks' or its turn's, named as a Needs you row is: its project beneath
    /// its name; when its soonest line wakes in its time's place, none for a turn snoozed until it moves.
    init(_ row: Board.SnoozedRow, isHere: Bool = true) {
        self.init(
            id: row.session, project: row.projectName, name: row.name, letters: row.letters,
            kind: row.isTurn ? .snoozedTurn : .snoozed, away: row.isAway || !isHere, lines: row.lines.map(Line.init),
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
