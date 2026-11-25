import Foundation

/// An answer to an ask of a session, or its ignore, as `sitrep answer` takes it, with what the ask wanted as Lee saw
/// it, which the CLI refuses should the ask want something else by the time it writes.
public struct Answering: Sendable, Hashable {
    public let ask: String
    public let session: String
    public let answer: Answer
    public let wants: Board.Ask.Wants

    public init(_ answer: Answer, to ask: String, of session: String, wanting wants: Board.Ask.Wants) {
        self.ask = ask
        self.session = session
        self.answer = answer
        self.wants = wants
    }
}

/// An ask of a session, by their ids.
public struct AskOf: Hashable, Sendable {
    public let session: String
    public let ask: String

    public init(session: String, ask: String) {
        self.session = session
        self.ask = ask
    }

    public init(_ answering: Answering) {
        self.init(session: answering.session, ask: answering.ask)
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

/// Lee's answers from the asks panel (DESIGN, "Answering from the panel"). Each is held `goesAfter` before it goes, so
/// Undo can take it back with nothing written; once held it goes whatever the panel does meanwhile, closed or moved to
/// another row. One is held at a time: the asks panel takes no other while it is, and one asked to be held meanwhile is
/// refused. A refusal from the CLI posts a banner in its words.
@MainActor
public final class Answers {
    /// How long an answer is held before it goes.
    public static let goesAfter = Duration.seconds(2)

    /// Each answer's news, as it is held, taken back, goes, and ends.
    public var heard: (AnswerNews) -> Void = { _ in }
    /// The answer held, nil while none is.
    public private(set) var held: HeldAnswer?

    private let answer: @MainActor (Answering) async -> WriteAnswer
    private let post: @MainActor (Banner) -> Void
    private let board: @MainActor () -> Board?
    private let sleep: @Sendable (Duration) async throws -> Void
    private let now: () -> Date
    private var holding: Task<Void, Never>?
    /// The ask held, named as the board showed it as it was held.
    private var heldNamed: AskNamed?
    /// The answers gone to the CLI that it is not yet done with, each by its place in the order they went.
    private var sends: [Int: Task<Void, Never>] = [:]
    private var nextSend = 0

    /// Whether an answer is held, or gone to the CLI and not yet written or refused: quitting waits on it.
    public var isAnswering: Bool { held != nil || !sends.isEmpty }

    /// `answer` runs an answer through the CLI; `post` posts a refusal's banner, naming the ask as `board`, the last
    /// one heard, shows it as the answer is held or sent; `sleep` waits out the hold and `now` tells the wall clock:
    /// the tests' clocks, in place of the real ones.
    public init(
        answer: @escaping @MainActor (Answering) async -> WriteAnswer,
        post: @escaping @MainActor (Banner) -> Void,
        board: @escaping @MainActor () -> Board? = { nil },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> Date = Date.init
    ) {
        self.answer = answer
        self.post = post
        self.board = board
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

        let named = naming(answering)

        self.held = held
        heldNamed = named
        holding = Task { [sleep] in
            guard (try? await sleep(Self.goesAfter)) != nil, !Task.isCancelled else {
                return
            }

            self.release()
            self.run(answering, named: named)
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

    /// Every answer seen through, as quitting does, which cancels none: the one held sent now, its hold cut short;
    /// back once the CLI is done with it and with every one gone before, each within the CLI's own time limit, or at
    /// once with none.
    public func finish() async {
        if let held {
            let named = heldNamed

            holding?.cancel()
            release()
            run(held.answering, named: named)
        }
        while let send = sends.values.first {
            await send.value
        }
    }

    /// The ask answered, as the board names it now; nil where it holds it no more.
    private func naming(_ answering: Answering) -> AskNamed? {
        board()?.naming(answering.ask, of: answering.session)
    }

    /// Sent, its refusal naming the ask as `named` has it, as the board showed it when it was held or sent; else as
    /// the board shows it by the time the CLI refuses, as for one held before SitRep had heard a board.
    private func run(_ answering: Answering, named: AskNamed?) {
        let send = nextSend

        nextSend += 1
        heard(.went(answering))
        sends[send] = Task {
            let written = await answer(answering)

            if case let .refused(why) = written {
                post(.unanswered(why, of: named ?? naming(answering)))
            }
            heard(.ended(answering, written))
            sends[send] = nil
        }
    }

    private func release() {
        held = nil
        heldNamed = nil
        holding = nil
    }
}
