import Foundation
import SitRepCore

/// An ask by its session and its own id, as two sessions' asks may share an id.
public struct AskAddress: Hashable, Sendable {
    public let session: String
    public let ask: String

    public init(session: String, ask: String) {
        self.session = session
        self.ask = ask
    }
}

/// An answer pressed on a card, from the press until the board says where it is.
public struct Pending: Equatable, Sendable {
    public enum Stage: Equatable, Sendable {
        /// Its two seconds under way, Escape undoing it.
        case waiting
        /// Gone to `sitrep answer`, until it is written, or the board says it is on its way.
        case sending
        /// Written, `sitrep answer` answering at this time, until a board of its session says where it is: one from a
        /// look begun after then, whatever it says, or any that shows the answer.
        case written(Date)
        /// Written at this time, and since then a line carried no board of its session, or `watch` went down: on its
        /// way, as the write proved, until a board says more, as for `written`.
        case onItsWay(Date)
        /// `sitrep answer` refused it, in these words: nothing was written.
        case refused(String)
    }

    public let answer: Answer
    public let pressed: Date
    public internal(set) var stage: Stage

    /// The answer as the card says it: `→ Approve`, `✕ Ignore`.
    public var words: String {
        switch answer {
        case let .words(words): "→ \(words)"
        case .ignore: "✕ Ignore"
        }
    }

    /// How far its wait has run at this time, from 0 as it is pressed to 1 as it goes.
    public func waited(at time: Date) -> Double {
        min(max(time.timeIntervalSince(pressed) / Answers.wait, 0), 1)
    }
}

/// The answers pressed in the window: each waits two seconds, Escape undoing the latest, before it goes to `sitrep
/// answer`; then it is sending until the board says where it is, and the board's word is the card's from then on.
/// The board never closes an ask on the press alone.
public struct Answers: Equatable, Sendable {
    /// How long an answer waits after its press, for Escape to undo it.
    public static let wait: TimeInterval = 2

    public private(set) var pending: [AskAddress: Pending] = [:]

    public init() {}

    /// An answer pressed on an ask, waiting from this time; a refusal shown for it before gives way.
    mutating func press(_ answer: Answer, on ask: AskAddress, at time: Date) {
        pending[ask] = Pending(answer: answer, pressed: time, stage: .waiting)
    }

    /// Escape: the answer pressed last of those still waiting on these sessions' asks is taken back. The ask it was
    /// on, if there was one.
    mutating func undo(on sessions: Set<String>) -> AskAddress? {
        let latest = pending
            .filter { sessions.contains($0.key.session) && $0.value.stage == .waiting }
            .max { $0.value.pressed < $1.value.pressed }?.key

        latest.map { pending[$0] = nil }
        return latest
    }

    /// The answers whose wait has run out by this time, now sending.
    mutating func due(at time: Date) -> [(ask: AskAddress, answer: Answer)] {
        let due = pending.filter { $0.value.stage == .waiting && $0.value.waited(at: time) >= 1 }

        for ask in due.keys {
            pending[ask]?.stage = .sending
        }
        return due.map { ($0.key, $0.value.answer) }.sorted { $0.ask.ask < $1.ask.ask }
    }

    /// When the next wait runs out, while one is under way.
    var nextDue: Date? {
        pending.values.filter { $0.stage == .waiting }.map { $0.pressed.addingTimeInterval(Self.wait) }.min()
    }

    /// `sitrep answer` wrote the answer, answering at this time: a board of its session says where it is.
    mutating func written(_ ask: AskAddress, at time: Date) {
        pending[ask]?.stage = .written(time)
    }

    /// `sitrep answer` refused the answer: the card says why, its buttons back; unless its session's board as last
    /// kept, if there is one, has the ask settled, which bars them.
    mutating func refused(_ ask: AskAddress, _ why: String, on asks: [Board.Ask]?) {
        if let asks, Self.isSettled(ask.ask, in: asks) {
            pending[ask] = nil
        } else {
            pending[ask]?.stage = .refused(why)
        }
    }

    /// The session's open asks as a board of it has them, from a look `watch` began at this time: an answer sending,
    /// or refused, gives way to the board's word once the ask has settled. One written, or on its way, gives way to a
    /// board from a look begun after the write answered, whatever it says, an edit or a reopen since leaving the ask
    /// waiting with no reply; and to an earlier board that shows the answer, as a look under way as the write landed
    /// does. An earlier board without it was read before the write, and leaves it.
    mutating func settle(_ asks: [Board.Ask], of session: String, lookedAt look: Date) {
        pending = pending.filter { ask, pending in
            guard ask.session == session else {
                return true
            }

            switch pending.stage {
            case .waiting: return true
            case .sending, .refused: return !Self.isSettled(ask.ask, in: asks)
            case let .written(answered), let .onItsWay(answered):
                return look <= answered && !Self.showsAnswer(ask.ask, pressed: pending.pressed, in: asks)
            }
        }
    }

    /// A line carried no board of the session: an answer written to it is on its way, as the write proved.
    mutating func noBoard(of session: String) {
        writtenOnItsWay { $0 == session }
    }

    /// No `watch` runs to carry boards: every answer written is on its way, as the write proved.
    mutating func unwatched() {
        writtenOnItsWay { _ in true }
    }

    /// Each answer written to a session given is on its way, settled as it was to be, from the write.
    private mutating func writtenOnItsWay(_ isOf: (String) -> Bool) {
        for (ask, pending) in pending where isOf(ask.session) {
            if case let .written(answered) = pending.stage {
                self.pending[ask]?.stage = .onItsWay(answered)
            }
        }
    }

    /// The board shows Lee's answer: the ask closed, gone from the open asks, or Lee's reply to it since the press.
    private static func showsAnswer(_ ask: String, pressed: Date, in asks: [Board.Ask]) -> Bool {
        guard let now = asks.first(where: { $0.id == ask }) else {
            return true
        }

        return now.reply.map { $0.isAnswer && $0.since >= pressed } ?? false
    }

    /// Settled, so that no answer may go to it: closed, gone from the open asks, or Lee's answer to it on its way.
    private static func isSettled(_ ask: String, in asks: [Board.Ask]) -> Bool {
        guard let now = asks.first(where: { $0.id == ask }) else {
            return true
        }

        return now.reply?.standing == .onItsWay && now.reply?.isAnswer == true
    }

    /// Another session picked: the refusals shown on the last one's cards are let go.
    mutating func forgetRefusals() {
        pending = pending.filter {
            if case .refused = $0.value.stage {
                return false
            }
            return true
        }
    }
}
