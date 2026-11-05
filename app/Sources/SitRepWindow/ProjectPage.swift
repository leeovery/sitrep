import Foundation
import SitRepCore

/// A project, filling the window (A3 revised): its title and its counts; its sessions, each with where it stands; the
/// lines waiting on Lee across them; what each is doing now; its log, grouped by session; and how many items it parked.
/// A project's page follows every one of its sessions, so each one's board, and its log, is there as it comes.
public struct ProjectPage: Equatable, Sendable {
    /// One of its current sessions, as its row in Sessions, its card in Now and its group in Log show it.
    public struct Session: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let mark: Mark
        /// No window holds it: its name and where it stands dim as one.
        public let isAway: Bool
        /// The last look at the screen says no terminal shows it: "not on screen", and the pip on its mark.
        public let isOffScreen: Bool
        public let standing: Standing
        /// When its state began, its row's time.
        public let since: Date
        /// Its status's first now line, as A3 draws its card, and what comes next.
        public let now: String?
        public let next: String?
        /// When its status last changed: its newest status line as its board last kept it, else when the session last
        /// changed.
        public let updated: Date
        /// The newest of its log's lines, as its board last kept them; none before a board of it comes.
        public let log: [Note]
    }

    /// Where a session stands, in the middle of its row: what waits on Lee there, else what its window is doing.
    public enum Standing: Equatable, Sendable {
        /// A window stopped on a prompt or a question, and its asks waiting on Lee.
        case waits(stop: Doing.Kind?, asks: Int)
        /// Its window working, or on its own work, as the line under its name has it.
        case doing(Doing.Kind, Board.Row.Words)
        case yourTurn
        case away
    }

    /// A line waiting on Lee in one of its sessions, an ask or a window's stop; or, while the page is held, an ask that
    /// closed meanwhile, kept in its place, faint.
    public struct Line: Equatable, Sendable, Identifiable {
        public let line: Listed.Line
        public let session: String
        public let sessionName: String
        public let isAway: Bool
        public let isOffScreen: Bool
        public let isClosed: Bool

        public var id: String { line.id }

        /// The orange dot, or the away ring while no window holds its session; a closed one shows the tick instead.
        public var mark: Mark { isAway ? .awayAsk : .needs }
    }

    public let key: String
    public let name: String
    public let sessions: [Session]
    /// In the order Needs you lists them.
    public let waiting: [Line]
    /// The items its sessions parked.
    public let parked: Int

    /// The lines still waiting on Lee, those closed while the page is held aside.
    public var waitingCount: Int {
        waiting.filter { !$0.isClosed }.count
    }

    /// Waiting on you's count after its heading, in orange: none, not 0, where every line has closed while the page
    /// held.
    public var waitingBadge: Int? {
        waitingCount > 0 ? waitingCount : nil
    }

    /// Under its title: its sessions, what waits on Lee and what it parked, each left out where it is none.
    public var counts: [String] {
        [
            sessions.isEmpty ? nil : Words.count(sessions.count, "session"),
            waitingCount > 0 ? Words.waitingOnYou(waitingCount) : nil,
            parked > 0 ? Words.parkedCount(parked) : nil,
        ].compactMap { $0 }
    }

    /// At the page's foot, under a rule: "N parked", which opens Parked narrowed to the project; none while it parked
    /// nothing.
    public var parkedRow: String? {
        parked > 0 ? Words.parkedCount(parked) : nil
    }

    /// The Log shows while a session's board has a line of it.
    public var hasLog: Bool {
        sessions.contains { !$0.log.isEmpty }
    }

    /// How many of a session's newest log lines its group in Log shows.
    static let logLines = 3

    /// Now's cards and Log's groups, as many across as fit at their narrowest in this width, three at the most; the
    /// two always the same, so a session's log sits under its card.
    public static func columns(across width: Double) -> Int {
        let fit = Int(((width + gridGap) / (narrowestCard + gridGap)).rounded(.down))

        return min(max(fit, 1), mostColumns)
    }

    /// A card of Now, and a group of Log, at its narrowest, and the gap between two.
    public static let narrowestCard = 240.0
    public static let gridGap = 12.0
    static let mostColumns = 3
}

extension ProjectPage.Standing {
    /// Its parts, which the row joins with " · " and VoiceOver with commas: a stop, then the asks waiting; else its
    /// window's line, its lead and what it acts on, a wake counted down at this time; else your turn, or away.
    public func parts(at now: Date) -> [String] {
        switch self {
        case let .waits(stop, asks):
            [stop.flatMap(Words.stoppedOn), asks > 0 ? Words.asksWaiting(asks) : nil].compactMap { $0 }
        case let .doing(_, line):
            [([line.lead] + [line.mono ?? Words.subject(line, at: now)].compactMap { $0 }).joined(separator: " ")]
        case .yourTurn: [Words.yourTurn]
        case .away: [Words.noWindow]
        }
    }
}

extension Words {
    /// A project's header: what waits on Lee across its sessions.
    public static func waitingOnYou(_ count: Int) -> String {
        "\(count) waiting on you"
    }

    /// Where a session stands on its project's page: its asks waiting on Lee.
    public static func asksWaiting(_ count: Int) -> String {
        "\(Words.count(count, "ask")) waiting"
    }

    /// Where a session stands on its project's page: its window stopped, which Claude Code's prompt answers.
    public static func stoppedOn(_ kind: Doing.Kind) -> String? {
        switch kind {
        case .permission: "Stopped on a prompt"
        case .question: "Stopped on a question"
        case .working, .onItsWork, .yourTurn, .away: nil
        }
    }

    public static let yourTurn = "Your turn"
    public static let noWindow = "No window holds it"
    public static let notOnScreen = "not on screen"

    /// How long ago something was, as a card of a project's Now says its session's status changed and a thread says
    /// Lee last looked: "1h ago", or "just now".
    public static func ago(_ since: Date, at now: Date) -> String {
        let age = age(since, at: now)

        return age == "now" ? "just now" : "\(age) ago"
    }
}

extension Spoken {
    /// A project's page's header, its counts as words: "3 sessions, 3 waiting on you, 4 parked".
    public static func counts(_ page: ProjectPage) -> String {
        page.counts.joined(separator: ", ")
    }

    /// A session's row on its project's page, one element: its name, "away" where no window holds it and where it
    /// stands does not say so, where it stands, "not on screen" where no terminal shows it, and its time, as "Tidy the
    /// test fixtures, Stopped on a prompt, not on screen, 3 minutes". Where it stands says what its mark would.
    public static func session(_ session: ProjectPage.Session, at now: Date) -> String {
        let away = session.isAway && session.standing != .away ? ["away"] : []
        let screen = session.isOffScreen ? [Words.notOnScreen] : []

        return ([session.name] + away + session.standing.parts(at: now) + screen + [age(session.since, at: now)])
            .joined(separator: ", ")
    }

    /// A line of Waiting on you, one element: its words, its session, "away" where no window holds it, "not on screen"
    /// where no terminal shows it, "closed" where it closed while the page held, and how long it has waited.
    public static func waiting(_ line: ProjectPage.Line, at now: Date) -> String {
        let marks = [line.isAway ? "away" : nil, line.isOffScreen ? Words.notOnScreen : nil, line.isClosed ? closed : nil]

        return ([line.line.words(at: now), line.sessionName] + marks.compactMap { $0 } + [age(line.line.since, at: now)])
            .joined(separator: ", ")
    }

    /// A session's card in Now, one element: its name, "away" where no window holds it, its now line, what comes next
    /// and when its status changed.
    public static func nowCard(_ session: ProjectPage.Session, at now: Date) -> String {
        let next = session.next.map { "next \($0)" }

        return ([session.name, session.isAway ? "away" : nil, session.now, next].compactMap { $0 }
            + [updated(session.updated, at: now)]).joined(separator: ", ")
    }

    /// A line of a session's group in Log, one element: its words and how long ago.
    public static func log(_ note: Note, at now: Date) -> String {
        "\(note.text), \(age(note.at, at: now))"
    }
}
