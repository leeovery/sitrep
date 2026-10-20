import Foundation
import SitRepCore

/// An ask as the window's card shows it: its title, where to look and what its words are; its buttons; and a line
/// under them saying where Lee's answer is, as its press and then the board's `reply` say.
public struct Card: Equatable, Sendable, Identifiable {
    public enum Button: Hashable, Sendable {
        /// A yes ask's yes, a white pill in Claude's words.
        case yes(String)
        /// One of a choice ask's options, outlined.
        case option(String)
        /// Needs Claude Code's prompt, so it jumps to the session's window: "Comment in Claude ↗", "Answer in
        /// Claude ↗".
        case inClaude(InClaude)
        /// Quiet grey text.
        case ignore

        /// The answer it gives, for those answered here.
        public var answer: Answer? {
            switch self {
            case let .yes(words), let .option(words): .words(words)
            case .ignore: .ignore
            case .inClaude: nil
            }
        }

        /// A yes or an option: Lee's answer, given here, which waits in the inbox while no window holds the session.
        public var isAnswer: Bool {
            switch self {
            case .yes, .option: true
            case .inClaude, .ignore: false
            }
        }
    }

    public enum InClaude: Sendable {
        case comment, answer
    }

    public enum Line: Equatable, Sendable {
        /// Pressed, its two seconds under way: "→ Approve  sending · Esc to undo", a line draining under it.
        case waiting(Pending)
        /// Gone to `sitrep answer`, before the board has it on its way.
        case sending(String)
        /// On its way, in its session's inbox: "→ Approve  on its way", and why it waits, where it does.
        case onItsWay(String, Wait)
        /// A comment of Lee's on its way, which bars no answer.
        case commentOnItsWay(String)
        /// Claude has Lee's answer, but the ask changed since and it fits no more: the ask waits on Lee again.
        case changedSince(String)
        /// `sitrep answer` refused the answer, in its words.
        case refused(String)
        /// No window holds the session: "Your answer waits in its inbox, and goes in when a window takes the session
        /// up again."
        case inbox
        /// Closed while it showed: how.
        case closed(Closed)
    }

    /// Why an answer on its way has not gone in yet.
    public enum Wait: Sendable {
        /// Its window takes it in now.
        case none
        /// Its window is mid-turn: "waits for the turn to end".
        case turn
        /// No window holds the session: it waits in the inbox for one.
        case window
    }

    /// How an ask closed while its card showed.
    public enum Closed: Equatable, Sendable {
        /// Lee's answer reached Claude, and closed it: "sent, and Claude has it".
        case sent
        /// Claude resolved it, with Claude's reason where Claude gave one.
        case resolved(String?)
        /// Claude closed it before Lee's answer went in.
        case notDelivered(String)
        /// Lee's ignore went in, and dropped it.
        case ignored
    }

    public let id: AskAddress
    public let title: String
    public let `where`: String?
    /// What a words ask's words are: "the command's output".
    public let needs: String?
    /// When it was asked.
    public let since: Date
    /// Faint, with no buttons, saying how it closed.
    public let isClosed: Bool
    public let buttons: [Button]
    public let lines: [Line]
    /// New while its session showed: washed orange from then (`Wash`).
    public let washed: Date?
}

extension Card {
    /// What the card says of an ask: closed while it showed, else its press if there is one, else the board's
    /// `reply`. An answer pressed, sending or on its way bars a second, so the card offers no buttons; a comment on
    /// its way bars nothing. Comment and words need Claude Code's prompt, which only a window holding the session
    /// has.
    init(_ ask: Board.Ask, of session: String, doing: Doing, pending: Pending?, closed: Closed?, washed: Date?) {
        let offered = Self.buttons(ask, isAway: doing.isAway)
        let (buttons, lines) = if let closed {
            ([Button](), [Line.closed(closed)])
        } else if let pending {
            Self.pressed(pending, offering: offered, doing: doing)
        } else {
            Self.replied(ask.reply, offering: offered, doing: doing)
        }
        let inbox = doing.isAway && buttons.contains(where: \.isAnswer)

        self.init(
            id: AskAddress(session: session, ask: ask.id), title: ask.title, where: ask.where, needs: ask.needs,
            since: ask.at, isClosed: closed != nil, buttons: buttons, lines: lines + (inbox ? [.inbox] : []),
            washed: washed
        )
    }

    private static func pressed(_ pending: Pending, offering offered: [Button], doing: Doing) -> ([Button], [Line]) {
        switch pending.stage {
        case .waiting: ([], [.waiting(pending)])
        case .sending, .written: ([], [.sending(pending.words)])
        case .onItsWay: ([], [.onItsWay(pending.words, wait(doing))])
        case let .refused(why): (offered, [.refused(why)])
        }
    }

    private static func replied(_ reply: Board.Reply?, offering offered: [Button], doing: Doing) -> ([Button], [Line]) {
        guard let reply else {
            return (offered, [])
        }

        switch (reply.standing, reply.isAnswer) {
        case (.onItsWay, true): return ([], [.onItsWay(reply.words, wait(doing))])
        case (.onItsWay, false): return (offered, [.commentOnItsWay(reply.words)])
        case (.delivered, _): return (offered, [.changedSince(reply.words)])
        case (.notDelivered, _): return (offered, [])
        }
    }

    /// What an open ask offers: a yes in Claude's words, or each option, else Claude Code's prompt; a comment beside a
    /// yes or a choice; ignore on every one. What needs the prompt is offered only while a window holds the session.
    private static func buttons(_ ask: Board.Ask, isAway: Bool) -> [Button] {
        let answers: [Button] = switch ask.wants {
        case .yes: [.yes(ask.yes ?? "yes")]
        case .choice: ask.options.map(Button.option)
        case .words: []
        }
        let prompt: [Button] = isAway ? [] : [.inClaude(answers.isEmpty ? .answer : .comment)]

        return answers + prompt + [.ignore]
    }

    /// How a card lays out its buttons.
    public enum Arrangement: Equatable, Sendable {
        /// On one line, each a pill.
        case pills
        /// The buttons at these offsets a column of rows as wide as the card, their words wrapping; the rest on a line
        /// after them.
        case rows([Int])
    }

    /// Pills, while every button fits on one line at its one-line width, measured, with the space between; else its
    /// answers as rows, as Claude's long options wrapped inside their pills, the rest on a line after them while that
    /// line fits, and every button a row where it does not, so nothing runs past the card.
    public static func arrangement(of buttons: [Button], widths: [Double], spacing: Double, in width: Double) -> Arrangement {
        let all = Array(buttons.indices)

        guard line(widths, spacing) > width else {
            return .pills
        }

        let answers = all.filter { buttons[$0].isAnswer }
        let rest = all.filter { !buttons[$0].isAnswer && widths.indices.contains($0) }

        return .rows(answers.isEmpty || line(rest.map { widths[$0] }, spacing) > width ? all : answers)
    }

    /// How wide these are side by side.
    private static func line(_ widths: [Double], _ spacing: Double) -> Double {
        widths.reduce(0, +) + spacing * Double(max(0, widths.count - 1))
    }

    private static func wait(_ doing: Doing) -> Wait {
        doing.isAway ? .window : doing.isMidTurn ? .turn : .none
    }

    /// How an ask that left the open asks closed, as the session's board now has it: among its resolved asks by Lee's
    /// answer or by Claude; else Lee's ignore, which drops an ask without a place in Resolved.
    static func closed(_ ask: String, in board: SessionBoard) -> Closed {
        guard let resolved = board.resolved.first(where: { $0.id == ask }) else {
            return .ignored
        }

        switch resolved.ask.reply {
        case let reply? where reply.standing == .delivered && reply.isAnswer:
            return .sent
        case let reply? where reply.standing == .notDelivered:
            return .notDelivered(reply.words)
        default:
            return .resolved(resolved.reason)
        }
    }
}
