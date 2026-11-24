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

        clock.pass(Answers.goesAfter)
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
        clock.pass(Answers.goesAfter)
        await Self.settle()
        #expect(cli.ran.isEmpty)
        #expect(cli.news.dropFirst() == [.undone(Self.ignore)])
    }

    /// The hold has run out but its task has not yet run: Undo still takes it back.
    @Test func undoAsTheHoldRunsOutTakesItBackAndNothingIsWritten() async {
        let (answers, clock, cli) = Self.made()

        answers.hold(Self.ignore)
        await until(turns: 100_000) { clock.sleeps.count == 1 }
        clock.pass(Answers.goesAfter)
        answers.undo()
        await Self.settle()

        #expect(cli.ran.isEmpty)
        #expect(cli.news.dropFirst() == [.undone(Self.ignore)])
    }

    /// A listener taking it back as it hears it held takes it back.
    @Test func undoOnHearingItHeldTakesItBackAndNothingIsWritten() async {
        let (answers, clock, cli) = Self.made()

        answers.heard = { news in
            cli.news.append(news)
            if case .held = news {
                answers.undo()
            }
        }
        answers.hold(Self.ignore)
        await until(turns: 100_000) { clock.sleeps.count == 1 }
        clock.pass(Answers.goesAfter)
        await Self.settle()

        #expect(cli.ran.isEmpty)
        #expect(cli.news.dropFirst() == [.undone(Self.ignore)])
        #expect(answers.held == nil)
    }

    @Test func undoWithNothingHeldDoesNothing() async {
        let (answers, _, cli) = Self.made()

        answers.undo()

        #expect(cli.news.isEmpty)
    }

    /// Gone, it is past taking back: Undo tells nothing.
    @Test func undoOnceItHasGoneTellsNothing() async {
        let (answers, clock, cli) = Self.made()

        answers.hold(Self.approve)
        await until(turns: 100_000) { clock.sleeps.count == 1 }
        clock.pass(Answers.goesAfter)
        await until(turns: 100_000) { cli.news.count == 3 }
        answers.undo()

        #expect(cli.ran == [Self.approve])
        #expect(cli.news.count == 3)
        #expect(!cli.news.contains(.undone(Self.approve)))
    }

    /// A banner's answer to the ask held takes the hold back first, as Undo does, then goes at once: the held one
    /// never goes after it, for the CLI to refuse as answered already.
    @Test func anAnswerSentToTheAskHeldTakesTheHoldBackThenGoes() async {
        let (answers, clock, cli) = Self.made()
        let banners = Answering(.words("Approve"), to: Self.ignore.ask, of: Self.ignore.session)

        answers.hold(Self.ignore)
        await until(turns: 100_000) { clock.sleeps.count == 1 }
        answers.send(banners)
        await until(turns: 100_000) { cli.news.count == 4 }
        clock.pass(Answers.goesAfter)
        await Self.settle()

        #expect(answers.held == nil)
        #expect(cli.ran == [banners])
        #expect(cli.news.dropFirst() == [.undone(Self.ignore), .went(banners), .ended(banners, .written)])
    }

    /// While one is held the asks panel takes no other: the second is refused, unheld and never sent; once the first
    /// has gone, another is held.
    @Test func anAnswerHeldWhileAnotherIsIsRefused() async {
        let (answers, clock, cli) = Self.made()

        answers.hold(Self.approve)
        await until(turns: 100_000) { clock.sleeps.count == 1 }

        #expect(!answers.hold(Self.ignore))
        #expect(answers.held?.answering == Self.approve)
        #expect(cli.news.count == 1, "the refused one tells nothing")

        clock.pass(Answers.goesAfter)
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

    /// Quitting sends the answer held at once, its hold cut short, and is back only once the CLI is done with it; the
    /// hold running out after sends nothing more.
    @Test func finishingSendsTheAnswerHeldAtOnceAndIsBackOnceTheCLIIsDone() async {
        let (answers, clock, cli) = Self.made()

        answers.hold(Self.approve)
        await until(turns: 100_000) { clock.sleeps.count == 1 }
        #expect(answers.isAnswering)
        await answers.finish()

        #expect(!answers.isAnswering)
        #expect(cli.ran == [Self.approve])
        #expect(cli.news.dropFirst() == [.went(Self.approve), .ended(Self.approve, .written)])

        clock.pass(Answers.goesAfter)
        await Self.settle()
        #expect(cli.ran == [Self.approve])
    }

    @Test func withNothingHeldOrGoingFinishingSendsNothing() async {
        let (answers, _, cli) = Self.made()

        #expect(!answers.isAnswering)
        await answers.finish()

        #expect(cli.ran.isEmpty)
        #expect(cli.news.isEmpty)
    }

    /// An answer whose hold ran out just before quitting, gone to the CLI and not yet written, is waited on: quitting
    /// is back only once the CLI is done with it.
    @Test func finishingWaitsOnAnAnswerTheCLIIsNotDoneWith() async {
        let gate = Gate()
        let (answers, clock, cli) = Self.made(gate: gate)
        var finished = false

        answers.hold(Self.approve)
        await until(turns: 100_000) { clock.sleeps.count == 1 }
        clock.pass(Answers.goesAfter)
        await until(turns: 100_000) { gate.waiting == 1 }
        #expect(answers.held == nil && answers.isAnswering)

        let finishing = Task {
            await answers.finish()
            finished = true
        }

        await Self.settle()
        #expect(!finished)
        gate.open()
        await finishing.value
        #expect(cli.ran == [Self.approve] && !answers.isAnswering)
    }

    /// The hold running out as quitting begins: the answer goes once, and quitting waits on it.
    @Test func theHoldRunningOutAsFinishingBeginsSendsItOnce() async {
        let gate = Gate()
        let (answers, clock, cli) = Self.made(gate: gate)

        answers.hold(Self.approve)
        await until(turns: 100_000) { clock.sleeps.count == 1 }
        clock.pass(Answers.goesAfter)

        let finishing = Task { await answers.finish() }

        await until(turns: 100_000) { gate.waiting == 1 }
        gate.open()
        await finishing.value
        await Self.settle()
        #expect(cli.ran == [Self.approve])
        #expect(cli.news.filter { $0 == .went(Self.approve) }.count == 1)
        #expect(!answers.isAnswering)
    }

    @Test func aRefusalPostsNotAnsweredInTheCLIsWords() async {
        let why = "k1 is answered already: its answer is on its way."
        let (answers, _, cli) = Self.made(answering: .refused(why))

        answers.send(Self.approve)
        await until(turns: 100_000) { cli.news.count == 2 }

        #expect(cli.banners == [Banner(title: "Not answered", subtitle: nil, body: why, work: nil)])
        #expect(cli.news.last == .ended(Self.approve, .refused(why)))
    }

    /// Answers on a clock the test moves, to a CLI answering as given, at once or, through `gate`, once it opens.
    private static func made(
        answering written: WriteAnswer = .written, gate: Gate? = nil
    ) -> (Answers, TestClock, CLI) {
        let clock = TestClock(passing: [], holdsCancelled: true)
        let cli = CLI(written)
        let answers = Answers(
            answer: { answering in
                await gate?.pass()
                return cli.run(answering)
            },
            post: { cli.banners.append($0) }, sleep: { try await clock.sleep(for: $0) }, now: { heldAt }
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

/// A CLI's run held until the test lets it through: how many wait, and the way through for every one.
@MainActor
private final class Gate {
    private var through: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    var waiting: Int { through.count }

    func pass() async {
        guard !isOpen else {
            return
        }

        await withCheckedContinuation { through.append($0) }
    }

    func open() {
        isOpen = true
        through.forEach { $0.resume() }
        through = []
    }
}
