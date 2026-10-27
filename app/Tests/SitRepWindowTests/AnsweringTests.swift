import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// An answer pressed waits two seconds, Escape undoing it, then goes to `sitrep answer`; from then on the card says
/// what the board's `reply` says. The board never closes an ask on the press alone.
struct AnsweringTests {
    private static let yes = AskAddress(session: "sr-macapp", ask: "k1")
    private static let choice = AskAddress(session: "sr-macapp", ask: "k2")

    private static func card(_ ask: AskAddress, _ run: WindowRun, at time: Date = printedAt) throws -> Card {
        try #require(run.page(at: time).session?.asks.first { $0.id == ask })
    }

    @Test func aPressWaitsTwoSecondsTheCardSayingSoWithNoButtons() throws {
        let run = opened()

        #expect(run.press(.yes("Approve"), on: Self.yes, at: printedAt) == nil)

        let card = try Self.card(Self.yes, run)

        #expect(card.buttons.isEmpty)
        #expect(card.lines.map { if case let .waiting(pending) = $0 { pending.words } else { "" } } == ["→ Approve"])
        #expect(run.due(at: printedAt.addingTimeInterval(1.99)).isEmpty)
        #expect(run.nextChange == printedAt.addingTimeInterval(2))
    }

    @Test func theWaitDrainsOverItsTwoSeconds() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        #expect(run.answers.pending[Self.yes]?.waited(at: printedAt.addingTimeInterval(0.5)) == 0.25)
        #expect(run.answers.pending[Self.yes]?.waited(at: printedAt.addingTimeInterval(3)) == 1)
    }

    @Test func onceTheWaitIsOutTheAnswerGoesToSitrepAnswerAndIsSending() throws {
        let run = opened()

        _ = run.press(.option("Right"), on: Self.choice, at: printedAt)

        let due = run.due(at: printedAt.addingTimeInterval(2))

        #expect(due.map(\.ask) == [Self.choice])
        #expect(due.map(\.answer) == [.words("Right")])
        #expect(run.due(at: printedAt.addingTimeInterval(3)).isEmpty)
        #expect(try Self.card(Self.choice, run).lines == [.sending("→ Right")])
        #expect(try Self.card(Self.choice, run).buttons.isEmpty)
    }

    @Test func escapeTakesBackTheLatestAnswerStillWaiting() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.press(.ignore, on: Self.choice, at: printedAt.addingTimeInterval(0.5))
        #expect(run.undo())
        #expect(try Self.card(Self.choice, run).buttons.contains(.ignore))
        #expect(try Self.card(Self.yes, run).buttons.isEmpty)
        #expect(run.undo())
        #expect(!run.undo())
        #expect(run.due(at: printedAt.addingTimeInterval(5)).isEmpty)
    }

    @Test func escapeTakesNothingBackOnceTheAnswerHasGone() {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        #expect(!run.undo())
    }

    @Test func writtenTheSessionIsReadAgainAndItsReplyOnItsWayIsTheCardsWord() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))

        let reads = run.answered(Self.yes, .written)

        #expect(reads.map(\.session) == ["sr-macapp"])
        #expect(try Self.card(Self.yes, run).lines == [.sending("→ Approve")])
        answer(reads, in: run, with: ["sr-macapp": Lines.onItsWay])
        #expect(try Self.card(Self.yes, run).lines == [.onItsWay("→ Approve", .turn)])
        #expect(run.answers.pending.isEmpty)
    }

    @Test func aReadAskedForBeforeItWasWrittenLeavesItSendingTheFirstAfterSettlesItWhateverItSays() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))

        let before = run.pick(.session("sr-macapp"))
        let after = run.answered(Self.yes, .written)

        answer(before, in: run, with: ["sr-macapp": Lines.board])
        #expect(try Self.card(Self.yes, run).lines == [.sending("→ Approve")])
        answer(after, in: run, with: ["sr-macapp": Lines.board])
        #expect(run.answers.pending.isEmpty)
        #expect(try Self.card(Self.yes, run).buttons.first == .yes("Approve"))
    }

    @Test func writtenWhileAnotherPageShowsAReadStillOnItsWayFromBeforeLeavesItSending() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))

        let inFlight = run.pick(.session("sr-macapp"))

        _ = run.pick(.session("sr-dash02"))
        #expect(run.answered(Self.yes, .written).isEmpty)
        answer(inFlight, in: run, with: ["sr-macapp": Lines.board])
        #expect(run.answers.pending[Self.yes]?.stage == .written(after: try #require(inFlight.first).ticket))
    }

    @Test func writtenAndEveryReadSinceFailedItIsOnItsWayAsTheWriteProvedUntilAReadSaysMore() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))

        let before = run.pick(.session("sr-macapp"))
        let after = run.answered(Self.yes, .written)

        for read in before {
            run.read(read, gave: .failed("sitrep board ended with status 1."), at: printedAt, reducesMotion: false)
        }
        #expect(try Self.card(Self.yes, run).lines == [.sending("→ Approve")])
        for read in after {
            run.read(read, gave: .failed("sitrep board ended with status 1."), at: printedAt, reducesMotion: false)
        }
        #expect(try Self.card(Self.yes, run).lines == [.onItsWay("→ Approve", .turn)])
        #expect(try Self.card(Self.yes, run).buttons.isEmpty)
        overTheAsks(run)
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": Lines.delivered])
        #expect(run.answers.pending.isEmpty)
        #expect(try Self.card(Self.yes, run).lines == [.closed(.sent)])
    }

    @Test func writtenWhileAnotherPageShowsItIsSettledByTheReadAsItShowsAgain() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        _ = run.pick(.session("sr-dash02"))
        #expect(run.answered(Self.yes, .written).isEmpty)
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": Lines.onItsWay])
        #expect(run.answers.pending.isEmpty)
        #expect(try Self.card(Self.yes, run).lines == [.onItsWay("→ Approve", .turn)])
    }

    @Test func aRefusalGivesWayToABoardWithLeesAnswerOnItsWayEitherWayRoundTheyCome() throws {
        let refusedFirst = opened()

        _ = refusedFirst.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = refusedFirst.due(at: printedAt.addingTimeInterval(2))
        _ = refusedFirst.answered(Self.yes, .refused("An answer to k1 is on its way already."))
        answer(refusedFirst.pick(.session("sr-macapp")), in: refusedFirst, with: ["sr-macapp": Lines.onItsWay])
        #expect(try Self.card(Self.yes, refusedFirst).lines == [.onItsWay("→ Approve", .turn)])
        #expect(try Self.card(Self.yes, refusedFirst).buttons.isEmpty)

        let readFirst = opened()

        _ = readFirst.press(.yes("Approve"), on: Self.yes, at: printedAt)
        answer(readFirst.pick(.session("sr-macapp")), in: readFirst, with: ["sr-macapp": Lines.onItsWay])
        _ = readFirst.due(at: printedAt.addingTimeInterval(2))
        _ = readFirst.answered(Self.yes, .refused("An answer to k1 is on its way already."))
        #expect(try Self.card(Self.yes, readFirst).lines == [.onItsWay("→ Approve", .turn)])
        #expect(try Self.card(Self.yes, readFirst).buttons.isEmpty)
    }

    @Test func escapeTakesBackOnlyAnAnswerOnThePageShowingOneOnAPageLeftGoesAsItWould() {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.pick(.session("sr-dash02"))
        #expect(!run.undo())
        #expect(run.due(at: printedAt.addingTimeInterval(2)).map(\.ask) == [Self.yes])
    }

    @Test func refusedTheCardSaysWhyAndOffersItsButtonsAgain() throws {
        let run = opened()
        let why = "k2 wants a choice: answer it with “Left, the notch's edge” or “Right”."

        _ = run.press(.option("Upward"), on: Self.choice, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        #expect(run.answered(Self.choice, .refused(why)).isEmpty)

        let card = try Self.card(Self.choice, run)

        #expect(card.lines == [.refused(why)])
        #expect(card.buttons.first == .option("Left, the notch's edge"))
    }

    @Test func aRefusalIsLetGoOnceAnotherSessionIsPicked() throws {
        let run = opened()

        _ = run.press(.option("Upward"), on: Self.choice, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        _ = run.answered(Self.choice, .refused("No."))
        _ = run.pick(.session("sr-dash02"))
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": Lines.board])
        #expect(try Self.card(Self.choice, run).lines.isEmpty)
    }

    @Test func aButtonNeedingClaudesPromptJumpsToTheSessionsWindowAndAnswersNothing() {
        let run = opened()

        #expect(run.press(.inClaude(.comment), on: Self.yes, at: printedAt) == "sr-macapp")
        #expect(run.answers.pending.isEmpty)
    }

    @Test func anIgnoreWaitsAsAnAnswerDoes() {
        let run = opened()

        _ = run.press(.ignore, on: Self.yes, at: printedAt)
        #expect(run.due(at: printedAt.addingTimeInterval(2)).map(\.answer) == [.ignore])
    }
}

/// The session open on the right never shifts under Lee's pointer.
struct OpenSessionTests {
    private static let yes = AskAddress(session: "sr-macapp", ask: "k1")

    @Test func anAskClosedMeanwhileKeepsItsPlaceWithoutButtonsSayingHowItClosed() throws {
        let run = opened()

        overTheAsks(run)
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": Lines.delivered])

        let asks = try #require(run.page(at: printedAt).session?.asks)

        #expect(asks.map(\.id.ask) == ["k1", "k3", "k2"])
        #expect(asks.map(\.isClosed) == [true, true, false])
        #expect(asks.map(\.buttons.isEmpty) == [true, true, false])
        #expect(asks[0].lines == [.closed(.sent)])
        #expect(asks[1].lines == [.closed(.ignored)])
    }

    @Test func resolvedLeavesItToAsksWhileItKeepsItsPlace() throws {
        let run = opened()

        overTheAsks(run)
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": Lines.delivered])
        #expect(run.page(at: printedAt).session?.resolved.map(\.id) == ["k5", "k4"])
    }

    @Test func anotherSessionPickedTheClosedAskMovesToResolved() throws {
        let run = opened()

        overTheAsks(run)
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": Lines.delivered])
        _ = run.pick(.session("sr-dash02"))
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": Lines.delivered])

        let page = try #require(run.page(at: printedAt).session)

        #expect(page.asks.map(\.id.ask) == ["k2"])
        #expect(page.resolved.map(\.id) == ["k1", "k5", "k4"])
    }

    @Test func anAskClaudeResolvedMeanwhileSaysClaudesReason() throws {
        let resolved = Lines.board
            .replacingOccurrences(of: #""id": "k5""#, with: #""id": "k2""#)
            .replacingOccurrences(of: #""id": "k2",\#n      "wants": "choice""#, with: #""id": "k9",\#n      "wants": "choice""#)
        let run = opened()

        try #require(resolved.contains(#""id": "k9""#))
        overTheAsks(run)
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": resolved])
        #expect(run.page(at: printedAt).session?.asks.first { $0.id.ask == "k2" }?.lines == [.closed(.resolved("you said \"left\" in the chat"))])
    }

    @Test func aNewAskLandsAtTheTopWashed() throws {
        let run = opened(boards: ["sr-macapp": Lines.delivered])
        let later = printedAt.addingTimeInterval(5)

        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": Lines.board], at: later)

        let asks = try #require(run.page(at: later).session?.asks)

        #expect(asks.map(\.id.ask) == ["k1", "k3", "k2"])
        #expect(asks.map(\.washed) == [later, later, nil])
        #expect(run.page(at: later.addingTimeInterval(2)).session?.asks.compactMap(\.washed) == [])
    }

    @Test func underReducedMotionANewAskIsNotWashed() throws {
        let run = opened(boards: ["sr-macapp": Lines.delivered])

        for read in run.pick(.session("sr-macapp")) {
            run.read(read, gave: board(Lines.board), at: printedAt, reducesMotion: true)
        }
        #expect(run.page(at: printedAt).session?.asks.compactMap(\.washed) == [])
    }
}

/// Finishing an away session asks first, in place.
struct FinishTests {
    private static let away = "sr-gs7kq2"

    private static func run() -> WindowRun {
        let run = opened()

        answer(run.pick(.session(away)), in: run, with: [away: Lines.away])
        return run
    }

    @Test func itAsksFirstThenRunsSitrepFinishOnce() {
        let run = Self.run()

        #expect(!run.confirmFinish(Self.away))
        run.askToFinish(Self.away)
        #expect(run.page(at: printedAt).session?.finish == .asking)
        #expect(run.confirmFinish(Self.away))
        #expect(run.page(at: printedAt).session?.finish == .finishing)
        #expect(!run.confirmFinish(Self.away))
    }

    @Test func cancelledItOffersToFinishAgain() {
        let run = Self.run()

        run.askToFinish(Self.away)
        run.cancelFinish(Self.away)
        #expect(run.page(at: printedAt).session?.finish == .offered)
    }

    @Test func refusedItSaysWhyInPlace() {
        let run = Self.run()

        run.askToFinish(Self.away)
        _ = run.confirmFinish(Self.away)
        run.finished(Self.away, .refused("This session is already finished."))
        #expect(run.page(at: printedAt).session?.finish == .refused("This session is already finished."))
    }

    @Test func finishedItLeavesWithWatchsNextLineAndTheWindowOpensOnWhatNeedsLee() {
        let run = Self.run()

        run.askToFinish(Self.away)
        _ = run.confirmFinish(Self.away)
        run.finished(Self.away, .written)
        #expect(run.page(at: printedAt).session?.finish == .finishing)
        _ = run.show(heard(line(0), line(3)), at: printedAt, reducesMotion: false)
        #expect(run.pick == .session("sr-macapp"))
    }

    @Test func cancelDoesNothingWhileSitrepFinishRuns() {
        let run = Self.run()

        run.askToFinish(Self.away)
        _ = run.confirmFinish(Self.away)
        run.cancelFinish(Self.away)
        #expect(run.page(at: printedAt).session?.finish == .finishing)
        #expect(!run.confirmFinish(Self.away))
    }

    @Test func askingLapsesWithAPickOrAClose() {
        let picked = Self.run()

        picked.askToFinish(Self.away)
        _ = picked.pick(.session("sr-macapp"))
        _ = picked.pick(.session(Self.away))
        #expect(picked.page(at: printedAt).session?.finish == .offered)

        let closed = Self.run()

        closed.askToFinish(Self.away)
        closed.close()
        _ = closed.open()
        _ = closed.pick(.session(Self.away))
        #expect(closed.page(at: printedAt).session?.finish == .offered)
    }

    @Test func askingLapsesAsTheSessionComesBackOpen() {
        let run = Self.run()

        run.askToFinish(Self.away)
        _ = run.show(heard(line(0), line(with: Self.away, doing: .yourTurn)), at: printedAt, reducesMotion: false)
        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.page(at: printedAt).session?.finish == .offered)
    }
}

/// A project opened from its name.
struct ProjectPageTests {
    private static func page() throws -> ProjectPage {
        let run = opened()

        answer(run.pick(.project("sitrep")), in: run, with: ["sr-macapp": Lines.board])
        return try #require(run.page(at: printedAt).project)
    }

    @Test func itListsItsSessionsEachWithWhatItIsDoingAndWhatWaitsThere() throws {
        let run = opened()

        _ = run.pick(.project("switchboard"))

        let page = try #require(run.page(at: printedAt).project)

        #expect(page.name == "Switchboard")
        #expect(page.waiting == 2)
        #expect(page.open == 2)
        #expect(page.sessions.map(\.name) == ["Dashboard redesign", "Request ledger"])
        #expect(page.sessions.map(\.waiting) == [2, 0])
        #expect(page.sessions.map(\.mark) == [.needs, .turn])
    }

    @Test func itsAsksComeTheNewestFirstClosedUntilOpened() throws {
        let page = try Self.page()

        #expect(page.asks.map(\.card.id.ask) == ["k1", "k3", "k2"])
        #expect(page.asks.map(\.isOpened) == [false, false, false])
        #expect(page.asksWaiting == 3)
    }

    @Test func inAProjectOfSeveralSessionsEachLineNamesItsSession() throws {
        let run = opened()

        answer(run.pick(.project("switchboard")), in: run, with: ["sr-dash02": Lines.dashboard, "sr-rq7dgr": Lines.ledger])

        let page = try #require(run.page(at: printedAt).project)

        #expect(page.asks.map(\.session) == ["Dashboard redesign"])
        #expect(page.notes.map(\.session) == ["Request ledger", "Dashboard redesign"])
    }

    /// The one session's name could only name that session.
    @Test func inAProjectOfOneSessionNoLineNamesIt() throws {
        let page = try Self.page()

        #expect(page.asks.map(\.session) == [nil, nil, nil])
        #expect(page.notes.map(\.session) == [nil, nil, nil])
        #expect(page.parked.map(\.session) == [nil])
    }

    @Test func anAskOpensInPlaceIntoItsCardAndClosesAgain() throws {
        let run = opened()
        let ask = AskAddress(session: "sr-macapp", ask: "k2")

        answer(run.pick(.project("sitrep")), in: run, with: ["sr-macapp": Lines.board])
        run.toggle(ask)
        #expect(run.page(at: printedAt).project?.asks.filter(\.isOpened).map(\.id) == [ask])
        run.toggle(ask)
        #expect(run.page(at: printedAt).project?.asks.filter(\.isOpened).isEmpty == true)
    }

    @Test func anAskSentWhileTheProjectsViewStandsKeepsItsPlaceSayingClaudeHasIt() throws {
        let run = opened()

        answer(run.pick(.project("sitrep")), in: run, with: ["sr-macapp": Lines.board])
        overTheAsks(run)
        answer(run.show(heard(line(0), line(2)), at: printedAt, reducesMotion: false), in: run, with: ["sr-macapp": Lines.delivered])

        let asks = try #require(run.page(at: printedAt).project?.asks)

        #expect(asks.map(\.card.id.ask) == ["k1", "k3", "k2"])
        #expect(asks.first?.card.lines == [.closed(.sent)])
        #expect(asks.first?.card.isClosed == true)
    }

    @Test func itsNotesComeTheNewestFirstAndItsParkedTheOldest() throws {
        let page = try Self.page()

        #expect(page.notes.map(\.text).first == "The strip written into DESIGN.md")
        #expect(page.parked.map(\.title) == ["Try a shy notch"])
    }
}
