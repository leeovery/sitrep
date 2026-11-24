import Foundation

/// An answer to an ask of a session, or its ignore, as `sitrep answer` takes it.
public struct Answering: Sendable, Hashable {
    public let ask: String
    public let session: String
    public let answer: Answer

    public init(_ answer: Answer, to ask: String, of session: String) {
        self.ask = ask
        self.session = session
        self.answer = answer
    }
}

/// An answer held before it goes, which Undo takes back: when it was held, and when it goes, on the wall clock.
public struct HeldAnswer: Sendable, Equatable {
    public let answering: Answering
    public let heldAt: Date
    public let goesAt: Date
}

/// What an answer tells as it goes: held, which the asks panel's sending line counts down; taken back by Undo; gone
/// to the CLI, the hold run out or sent at once; then what the CLI made of it.
public enum AnswerNews: Sendable, Equatable {
    case held(HeldAnswer)
    case undone(Answering)
    case went(Answering)
    case ended(Answering, WriteAnswer)
}

/// Lee's answers from the asks panel and the banners (DESIGN, "Answering from the panel"). The asks panel's is held
/// `hold` before it goes, so Undo can take it back with nothing written; once held it goes whatever the panel does
/// meanwhile, closed or moved to another row. One is held at a time: the asks panel takes no other while it is, and
/// one asked to be held meanwhile is refused. A banner's goes at once, held or not. A refusal from the CLI posts a
/// banner in its words.
@MainActor
public final class Answers {
    /// How long the asks panel's answer is held before it goes.
    public static let hold = Duration.seconds(2)

    /// Each answer's news, as it is held, taken back, goes, and ends.
    public var heard: (AnswerNews) -> Void = { _ in }
    /// The answer held, nil while none is.
    public private(set) var held: HeldAnswer?

    private let answer: @MainActor (Answering) async -> WriteAnswer
    private let post: @MainActor (Banner) -> Void
    private let sleep: @Sendable (Duration) async throws -> Void
    private let now: () -> Date
    private var holding: Task<Void, Never>?

    /// `answer` runs an answer through the CLI; `post` posts a refusal's banner; `sleep` waits out the hold and `now`
    /// tells the wall clock: the tests' clocks, in place of the real ones.
    public init(
        answer: @escaping @MainActor (Answering) async -> WriteAnswer,
        post: @escaping @MainActor (Banner) -> Void,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> Date = Date.init
    ) {
        self.answer = answer
        self.post = post
        self.sleep = sleep
        self.now = now
    }

    /// Holds the answer `hold`, then sends it, unless Undo takes it back first; whether it is held, which it is not
    /// while another is.
    @discardableResult
    public func hold(_ answering: Answering) -> Bool {
        guard held == nil else {
            return false
        }

        let heldAt = now()
        let held = HeldAnswer(
            answering: answering, heldAt: heldAt, goesAt: heldAt.addingTimeInterval(Self.hold / .seconds(1))
        )

        self.held = held
        heard(.held(held))
        holding = Task { [sleep] in
            guard (try? await sleep(Self.hold)) != nil, !Task.isCancelled else {
                return
            }

            self.release()
            self.send(answering)
        }
        return true
    }

    /// Takes back the answer held, which then never goes; nothing while none is.
    public func undo() {
        guard let held else {
            return
        }

        holding?.cancel()
        release()
        heard(.undone(held.answering))
    }

    /// Sends the answer now, with no hold: a banner's.
    public func send(_ answering: Answering) {
        heard(.went(answering))
        Task {
            let written = await answer(answering)

            if case let .refused(why) = written {
                post(.unanswered(why))
            }
            heard(.ended(answering, written))
        }
    }

    private func release() {
        held = nil
        holding = nil
    }
}
