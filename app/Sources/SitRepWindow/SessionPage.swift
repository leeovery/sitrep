import Foundation
import SitRepCore

/// A session's page, beside a place's list, the detail, or filling the window (Paper's "Window redesign", A1 and A2
/// revised): its project and its name; filling the window, a line saying where its window is and when it started;
/// what its window is doing; beside the list, the picked line's card leading, or filling the window, every ask's card;
/// then Now, and What happened.
public struct SessionPage: Equatable, Sendable {
    /// Where it shows: beside a place's list, the detail of the row picked, or filling the window.
    public enum Mode: Sendable {
        case detail, full
    }

    /// What leads the detail: the card of the line picked in Needs you, an ask's, asleep or closed while the page holds
    /// as it may be, or a window's stop, as its line says it.
    public enum Lead: Equatable, Sendable {
        case ask(Card)
        case stop(Stop)
    }

    /// A window stopped on Lee, a permission prompt or a question: the tool and what it would run, and since when.
    public struct Stop: Equatable, Sendable {
        public let kind: Doing.Kind
        public let line: Board.Row.Words
        public let since: Date
    }

    /// What stands under the page's head for what its window is doing.
    public enum DoingLine: Equatable, Sendable {
        /// The line, its mark beside it.
        case line
        /// A window's stop, as its card, washed orange, in the line's place.
        case stop(Stop)
        /// Nothing: the meta line says it is away, or the stop leads the detail already.
        case none
    }

    /// Filling the window, under its name: the terminal app its window is in and whether a window of it is on screen,
    /// and when it started; or, away, that no window holds it.
    public struct Meta: Equatable, Sendable {
        /// The terminal its window is in, as its `$TERM_PROGRAM` names it: `ghostty`, `iTerm.app`; in tmux, `tmux`; in an
    /// editor's terminal, the editor, `vscode`.
        public let terminal: String?
        /// The terminal app showing it, as the last look at the screen said, which tells the app in tmux too.
        public let app: String?
        /// Whether a jump could reach it, as the last look at the screen said; none with no reading of it.
        public let onScreen: OnScreen?
        public let started: Date?
        /// No window holds it: the away line, in place of the rest.
        public let away: String?
    }

    /// An ask still open, in What happened: "Asked …", by when it was asked.
    public struct Asked: Equatable, Sendable {
        public let id: AskAddress
        public let title: String
        public let at: Date
    }

    /// An entry of What happened: an ask still open, or a line of its log, a note or a status line.
    public enum Happened: Equatable, Sendable, Identifiable {
        case asked(Asked)
        case line(Note)

        public var id: String {
            switch self {
            case let .asked(asked): "asked:\(asked.id.ask)"
            case let .line(note): note.id
            }
        }

        public var at: Date {
            switch self {
            case let .asked(asked): asked.at
            case let .line(note): note.at
            }
        }
    }

    public let id: String
    public let mode: Mode
    /// Its project, by its key, and its name, which opens the project.
    public let projectKey: String
    public let projectName: String
    public let name: String
    /// Filling the window, its meta line; none beside the list, which draws none.
    public let meta: Meta?
    public let doing: Doing
    /// "Open in Ghostty ↗": only while a window holds it.
    public let jumps: Bool
    /// Its asks waiting on Lee.
    public let waiting: Int
    /// Beside Needs you's list, the picked line's card; none filling the window, nor for a session's row.
    public let lead: Lead?
    /// Its asks as cards, those waiting first, then those asleep: filling the window, each shows; beside the list, only
    /// the lead's, as the session's other lines are rows of their own.
    public let asks: [Card]
    /// Now: what is under way, and what comes next.
    public let status: Status
    /// "later N parked ›": how many items it parked, none at nought.
    public let parked: Int
    /// What happened, the newest first: its log's lines, as many as its board carries, and its asks still open.
    public let happened: [Happened]
    /// Where among them Lee last looked, "You looked 2h ago", where entries stand on both sides of it.
    public let looked: YouLooked?
    /// The newest closed first, those still keeping their place among its cards aside: "N resolved", folded at the end
    /// of What happened.
    public let resolved: [Resolved]
    /// "✓ Finish this session", only while no window holds it.
    public let finish: Finish?
    /// A board of it is kept: its cards, its log and what it resolved show as last kept.
    public let hasBoard: Bool
    /// Why the latest line to carry its board carried none, over its board as last kept, if there is one.
    public let failure: String?
    /// The lines of Now, What happened and its resolved asks opened in place.
    public let opened: Set<Item>

    /// Its mark beside what it is doing: with asks waiting while no window holds it, the away ring, as its row's and
    /// its cards'; else what it is doing's.
    public var mark: Mark {
        doing.isAway && waiting > 0 ? .awayAsk : doing.mark
    }

    /// What stands under its head for what its window is doing: a stop's card in the line's place, wherever a window
    /// is stopped, so a stop that follows the one picked still shows as one; filling the window, nothing while away, as
    /// its meta line says so; beside the list, nothing where a stop leads already.
    public var doingLine: DoingLine {
        if case .stop = lead {
            return .none
        }
        if let stop = Stop(doing) {
            return .stop(stop)
        }
        return mode == .full && doing.isAway ? .none : .line
    }

    /// Now has something to say: a line of its status, its next, or the items it parked. Without, it shows no heading.
    public var hasNow: Bool {
        !status.now.isEmpty || status.next != nil || parked > 0
    }

    /// The cards the page draws: filling the window, every ask's; beside the list, none but the lead's, which leads.
    public var cards: [Card] {
        mode == .full ? asks : []
    }
}

extension SessionPage {
    /// How many of a session's latest log lines its board carries (core's `BRIEF_LOG_LINES`).
    static let logLines = 8

    /// What happened, the newest first: the log's lines in its own order, and among them the asks given, the newest
    /// first, each before the first line older than it, so before a line as old. With the log as full as a board
    /// carries it, the asks older than its oldest line are cut, as the lines between them are gone; a log of exactly
    /// that many lines cannot tell it is not cut, so cuts too.
    static func happened(_ log: [Note], asks: [Asked]) -> [Happened] {
        let oldest = log.count >= logLines ? log.last?.at : nil
        let kept = asks.filter { ask in oldest.map { ask.at >= $0 } ?? true }
        var asked = ArraySlice(kept.enumerated().sorted { ($1.element.at, $0.offset) < ($0.element.at, $1.offset) }.map(\.element))
        var happened: [Happened] = []

        for line in log {
            while let ask = asked.first, ask.at >= line.at {
                happened.append(.asked(ask))
                asked.removeFirst()
            }
            happened.append(.line(line))
        }
        return happened + asked.map(Happened.asked)
    }
}

extension SessionPage.Asked {
    /// A card's ask, as asked, open or closed while the page holds.
    init(_ card: Card) {
        self.init(id: card.id, title: card.title, at: card.since)
    }
}

extension SessionPage.Stop {
    /// What a session is doing, where it is a stop.
    init?(_ doing: Doing) {
        guard doing.isStopped else {
            return nil
        }
        self.init(kind: doing.kind, line: doing.line, since: doing.since)
    }

    /// A stop's line of a session's row in Needs you.
    init?(_ line: Board.Row.Line) {
        switch line.kind {
        case .permission: self.init(kind: .permission, line: line.first, since: line.since)
        case .question: self.init(kind: .question, line: line.first, since: line.since)
        case .ask, .yourTurn, .working, .onItsWork: return nil
        }
    }
}

extension AskAddress {
    /// Its line's key in core's rows, the same in Needs you and Snoozed (core/rows.ts's `askKey`).
    var key: String {
        "ask:\(session):\(ask)"
    }
}

public struct Status: Equatable, Sendable {
    public let now: [String]
    public let next: String?
    /// When its status last changed, as the newest status line of its log has it; none once that line is past the
    /// lines its board carries.
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
