import Foundation
@testable import SitRepCore
import SitRepTestSupport
import Testing

/// Lee's answers (DESIGN, "Answering from the panel"): the asks panel's held two seconds, Undo taking it back with
/// nothing written, one held at a time; a banner's sent at once; a refusal from the CLI posted as "Not answered" in its
/// words. On a clock the test moves, and a CLI that runs nothing.
@MainActor
@Suite(.backstop)
struct AnswersTests {
    private static let heldAt = Date(timeIntervalSince1970: 1_792_486_181)
    private static let approve = Answering(.words("Approve"), to: "k1", of: "sr-4t2kq8")
    private static let ignore = Answering(.ignore, to: "k2", of: "sr-4t2kq8")

    @Test func aHeldAnswerGoesTwoSecondsOn() async {
        let (answers, clock, cli) = Self.made()

        #expect(answers.hold(Self.approve))
        await until(turns: 100_000) { clock.sleeps == [.seconds(2)] }

        let held = HeldAnswer(answering: Self.approve, heldAt: Self.heldAt, goesAt: Self.heldAt.addingTimeInterval(2))

        #expect(answers.held == held)
        #expect(cli.news == [.held(held)])
        #expect(cli.ran.isEmpty, "nothing runs within the hold")

        clock.pass(Answers.hold)
        await until(turns: 100_000) { cli.news.count == 3 }

        #expect(cli.ran == [Self.approve])
        #expect(cli.news == [.held(held), .went(Self.approve), .ended(Self.approve, .written)])
        #expect(answers.held == nil)
        #expect(cli.banners.isEmpty)
    }

    /// The clock holds a cancelled sleep until it is passed, so only the sender's own check keeps an answer taken back
    /// from going.
    @Test func undoWithinTheHoldTakesItBackAndNothingIsWritten() async {
        let (answers, clock, cli) = Self.made()

        answers.hold(Self.ignore)
        await until(turns: 100_000) { clock.sleeps.count == 1 }
        answers.undo()

        #expect(answers.held == nil)
        clock.pass(Answers.hold)
        await Self.settle()
        #expect(cli.ran.isEmpty)
        #expect(cli.news.dropFirst() == [.undone(Self.ignore)])
    }

    @Test func undoWithNothingHeldDoesNothing() async {
        let (answers, _, cli) = Self.made()

        answers.undo()

        #expect(cli.news.isEmpty)
    }

    /// While one is held the asks panel takes no other: the second is refused, unheld and never sent; once the first
    /// has gone, another is held.
    @Test func anAnswerHeldWhileAnotherIsIsRefused() async {
        let (answers, clock, cli) = Self.made()

        answers.hold(Self.approve)
        await until(turns: 100_000) { clock.sleeps.count == 1 }

        #expect(!answers.hold(Self.ignore))
        #expect(answers.held?.answering == Self.approve)

        clock.pass(Answers.hold)
        await until(turns: 100_000) { cli.ran.count == 1 }
        #expect(cli.ran == [Self.approve])
        #expect(answers.hold(Self.ignore))
    }

    /// A banner's answer goes at once, with no hold, one held meanwhile standing as it was.
    @Test func anAnswerSentGoesAtOnceWithNoHold() async {
        let (answers, clock, cli) = Self.made()

        answers.hold(Self.ignore)
        await until(turns: 100_000) { clock.sleeps.count == 1 }
        answers.send(Self.approve)
        await until(turns: 100_000) { cli.ran.count == 1 }

        #expect(cli.ran == [Self.approve])
        #expect(clock.sleeps == [.seconds(2)], "the held one's alone")
        #expect(cli.news.dropFirst() == [.went(Self.approve), .ended(Self.approve, .written)])
        #expect(answers.held?.answering == Self.ignore)
    }

    @Test func aRefusalPostsNotAnsweredInTheCLIsWords() async {
        let why = "k1 is answered already: its answer is on its way."
        let (answers, _, cli) = Self.made(answering: .refused(why))

        answers.send(Self.approve)
        await until(turns: 100_000) { cli.news.count == 2 }

        #expect(cli.banners == [Banner(title: "Not answered", subtitle: nil, body: why, work: nil)])
        #expect(cli.news.last == .ended(Self.approve, .refused(why)))
    }

    private static func made(answering written: WriteAnswer = .written) -> (Answers, TestClock, CLI) {
        let clock = TestClock(passing: [], holdsCancelled: true)
        let cli = CLI(written)
        let answers = Answers(
            answer: { cli.run($0) }, post: { cli.banners.append($0) }, sleep: { try await clock.sleep(for: $0) },
            now: { heldAt }
        )

        answers.heard = { cli.news.append($0) }
        return (answers, clock, cli)
    }

    /// Lets every task run that would.
    private static func settle() async {
        for _ in 0 ..< 1000 {
            await Task.yield()
        }
    }
}

/// A CLI answering every run as given, and what it heard: the answers run, the news told, and the banners posted.
@MainActor
private final class CLI {
    private let written: WriteAnswer
    private(set) var ran: [Answering] = []
    var news: [AnswerNews] = []
    var banners: [Banner] = []

    init(_ written: WriteAnswer) {
        self.written = written
    }

    func run(_ answering: Answering) -> WriteAnswer {
        ran.append(answering)
        return written
    }
}
