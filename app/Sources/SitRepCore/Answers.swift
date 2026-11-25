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
/// `goesAfter` before it goes, so Undo can take it back with nothing written; once held it goes whatever the panel does
/// meanwhile, closed or moved to another row. One is held at a time: the asks panel takes no other while it is, and
/// one asked to be held meanwhile is refused. A banner's goes at once, held or not; held to the same ask, the hold is
/// taken back first, so the CLI never refuses it as answered already. A refusal from the CLI posts a banner in its
/// words.
@MainActor
public final class Answers {
    /// How long the asks panel's answer is held before it goes.
    public static let goesAfter = Duration.seconds(2)

    /// Each answer's news, as it is held, taken back, goes, and ends.
    public var heard: (AnswerNews) -> Void = { _ in }
    /// The answer held, nil while none is.
    public private(set) var held: HeldAnswer?

    private let answer: @MainActor (Answering) async -> WriteAnswer
    private let post: @MainActor (Banner) -> Void
    private let sleep: @Sendable (Duration) async throws -> Void
    private let now: () -> Date
    private var holding: Task<Void, Never>?
    /// The answers gone to the CLI that it is not yet done with, each by its place in the order they went.
    private var sends: [Int: Task<Void, Never>] = [:]
    private var nextSend = 0

    /// Whether an answer is held, or gone to the CLI and not yet written or refused: quitting waits on it.
    public var isAnswering: Bool { held != nil || !sends.isEmpty }

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

    /// Holds the answer `goesAfter`, then sends it, unless Undo takes it back first; whether it is held, which it is not
    /// while another is.
    @discardableResult
    public func hold(_ answering: Answering) -> Bool {
        guard held == nil else {
            return false
        }

        let heldAt = now()
        let held = HeldAnswer(
            answering: answering, heldAt: heldAt, goesAt: heldAt.addingTimeInterval(Self.goesAfter / .seconds(1))
        )

        self.held = held
        holding = Task { [sleep] in
            guard (try? await sleep(Self.goesAfter)) != nil, !Task.isCancelled else {
                return
            }

            self.release()
            self.run(answering)
        }
        heard(.held(held))
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

    /// Sends the answer now, with no hold: a banner's. One held to the same ask of the session is taken back first, as
    /// Undo takes it.
    public func send(_ answering: Answering) {
        if let held, held.answering.ask == answering.ask, held.answering.session == answering.session {
            undo()
        }
        run(answering)
    }

    /// Every answer seen through, as quitting does, which cancels none: the one held sent now, its hold cut short;
    /// back once the CLI is done with it and with every one gone before, each within the CLI's own time limit, or at
    /// once with none.
    public func finish() async {
        if let held {
            holding?.cancel()
            release()
            run(held.answering)
        }
        while let send = sends.values.first {
            await send.value
        }
    }

    private func run(_ answering: Answering) {
        let send = nextSend

        nextSend += 1
        heard(.went(answering))
        sends[send] = Task {
            let written = await answer(answering)

            if case let .refused(why) = written {
                post(.unanswered(why))
            }
            heard(.ended(answering, written))
            sends[send] = nil
        }
    }

    private func release() {
        held = nil
        holding = nil
    }
}
