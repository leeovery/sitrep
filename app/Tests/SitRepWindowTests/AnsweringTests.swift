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

    /// When `sitrep answer` answered, two seconds after the press.
    private static let wrote = printedAt.addingTimeInterval(2)

    /// The line of `watch`'s next look after the write.
    private static let lookAfter = line(lookedAt: wrote.addingTimeInterval(1))

    /// The answer pressed, its wait out, and written.
    private static func written() -> WindowRun {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: Self.wrote)
        _ = run.answered(Self.yes, .written, at: Self.wrote)
        return run
    }

    @Test func writtenItAsksForALookNowAndItsSessionsNextBoardSaysWhereTheAnswerIs() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: Self.wrote)
        #expect(run.answered(Self.yes, .written, at: Self.wrote))
        #expect(try Self.card(Self.yes, run).lines == [.sending("→ Approve")])
        take(["sr-macapp": Lines.onItsWay], in: run, on: Self.lookAfter)
        #expect(try Self.card(Self.yes, run).lines == [.onItsWay("→ Approve", .turn)])
        #expect(run.answers.pending.isEmpty)
    }

    /// A board from a look begun before the write answered, as a look under way as `sitrep answer` wrote, or a line
    /// printed before it and heard after: the ask waiting with no reply, it says nothing of the answer, which stays
    /// as it was, its buttons gone.
    @Test func aBoardFromALookBeforeTheWriteLeavesItSending() throws {
        let run = Self.written()

        take(["sr-macapp": Lines.board], in: run)
        #expect(run.answers.pending[Self.yes]?.stage == .written(Self.wrote))
        #expect(try Self.card(Self.yes, run).lines == [.sending("→ Approve")])
        #expect(try Self.card(Self.yes, run).buttons.isEmpty)
    }

    /// The look that began as the write landed, the line heard after the write answered: its board shows Lee's
    /// answer on its way, so it says where the answer is, as no later board of an unchanged session comes.
    @Test func aBoardFromALookBeforeTheWriteThatShowsTheAnswerSaysWhereItIs() throws {
        let run = Self.written()

        take(["sr-macapp": Lines.onItsWay], in: run)
        #expect(run.answers.pending.isEmpty)
        #expect(try Self.card(Self.yes, run).lines == [.onItsWay("→ Approve", .turn)])
    }

    /// The first board from a look begun after the write says where the answer is, whatever it says: k1 waiting with
    /// no reply, as an edit by Claude since, or the ask reopened, leaves it, offers its buttons again.
    @Test func theFirstBoardFromALookAfterTheWriteSaysWhereTheAnswerIsWhateverItSays() throws {
        let voided = Self.written()

        take(["sr-macapp": Lines.board], in: voided, on: Self.lookAfter)
        #expect(voided.answers.pending.isEmpty)
        #expect(try Self.card(Self.yes, voided).lines.isEmpty)
        #expect(try Self.card(Self.yes, voided).buttons.first == .yes("Approve"))

        let onItsWay = Self.written()

        take(["sr-macapp": Lines.onItsWay], in: onItsWay, on: Self.lookAfter)
        #expect(onItsWay.answers.pending.isEmpty)
        #expect(try Self.card(Self.yes, onItsWay).lines == [.onItsWay("→ Approve", .turn)])
    }

    /// On its way as a line carried no board of its session, an answer is settled as a written one is: a board from
    /// a look before the write leaves it, and the first after says where it is, whatever it says.
    @Test func onItsWayItIsSettledAsAWrittenAnswerIs() throws {
        let run = Self.written()

        take(["sr-macapp": nil], in: run)
        take(["sr-macapp": Lines.board], in: run)
        #expect(run.answers.pending[Self.yes]?.stage == .onItsWay(Self.wrote))
        #expect(try Self.card(Self.yes, run).lines == [.onItsWay("→ Approve", .turn)])
        take(["sr-macapp": Lines.board], in: run, on: Self.lookAfter)
        #expect(run.answers.pending.isEmpty)
        #expect(try Self.card(Self.yes, run).buttons.first == .yes("Approve"))
    }

    /// Before the answer is written, a board is no sign of it either way: the answer is still sending.
    @Test func aBoardBeforeTheWriteLeavesItSending() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        take(["sr-macapp": Lines.board], in: run)
        #expect(try Self.card(Self.yes, run).lines == [.sending("→ Approve")])
    }

    /// `watch` down, no board can come, so the answer written is on its way, as the write proved, whichever comes
    /// first; the next run's board says more.
    @Test func writtenWhileTheBoardIsStaleItIsOnItsWayEitherWayRoundTheyCome() throws {
        let staleFirst = opened()
        let ended = heard(line(0), .exited(.status(1), stderr: ""))

        _ = staleFirst.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = staleFirst.due(at: printedAt.addingTimeInterval(2))
        staleFirst.show(ended, at: printedAt, reducesMotion: false)
        #expect(try Self.card(Self.yes, staleFirst).lines == [.sending("→ Approve")])
        _ = staleFirst.answered(Self.yes, .written, at: Self.wrote)
        #expect(try Self.card(Self.yes, staleFirst).lines == [.onItsWay("→ Approve", .turn)])
        take(["sr-macapp": Lines.onItsWay], in: staleFirst)
        #expect(staleFirst.answers.pending.isEmpty)

        let writtenFirst = opened()

        _ = writtenFirst.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = writtenFirst.due(at: printedAt.addingTimeInterval(2))
        _ = writtenFirst.answered(Self.yes, .written, at: Self.wrote)
        writtenFirst.show(ended, at: printedAt, reducesMotion: false)
        #expect(try Self.card(Self.yes, writtenFirst).lines == [.onItsWay("→ Approve", .turn)])
    }

    @Test func writtenWhileAnotherPageShowsAnotherSessionsBoardLeavesItWritten() {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        run.pick(.session("sr-dash02"))
        #expect(run.answered(Self.yes, .written, at: Self.wrote))
        take(["sr-dash02": Lines.dashboard], in: run)
        #expect(run.answers.pending[Self.yes]?.stage == .written(Self.wrote))
    }

    @Test func writtenAndTheNextLineCarryingNoBoardOfItsSessionItIsOnItsWayAsTheWriteProvedUntilABoardSaysMore() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        take(["sr-macapp": nil], in: run)
        #expect(try Self.card(Self.yes, run).lines == [.sending("→ Approve")])
        _ = run.answered(Self.yes, .written, at: Self.wrote)
        take(["sr-macapp": nil], in: run)
        #expect(try Self.card(Self.yes, run).lines == [.onItsWay("→ Approve", .turn)])
        #expect(try Self.card(Self.yes, run).buttons.isEmpty)
        overThePage(run)
        take(["sr-macapp": Lines.delivered], in: run)
        #expect(run.answers.pending.isEmpty)
        #expect(try Self.card(Self.yes, run).lines == [.closed(.sent)])
    }

    @Test func writtenWhileAnotherPageShowsItIsSettledByItsBoardAsItShowsAgain() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        run.pick(.session("sr-dash02"))
        _ = run.answered(Self.yes, .written, at: Self.wrote)
        run.pick(.session("sr-macapp"))
        take(["sr-macapp": Lines.onItsWay], in: run, on: Self.lookAfter)
        #expect(run.answers.pending.isEmpty)
        #expect(try Self.card(Self.yes, run).lines == [.onItsWay("→ Approve", .turn)])
    }

    /// Another session picked inside the two seconds, the write lands while the session is not followed, and
    /// Claude edits k1 meanwhile, voiding the answer: back on its page, the board `watch` carries anew, from a look
    /// after the write, shows k1 waiting with no reply, and its buttons come back.
    @Test func writtenWhileAnotherPageShowsAndVoidedSinceItOffersItsButtonsAgainAsItShows() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        run.pick(.session("sr-dash02"))
        _ = run.due(at: Self.wrote)
        _ = run.answered(Self.yes, .written, at: Self.wrote)
        run.pick(.session("sr-macapp"))
        take(["sr-macapp": Lines.board], in: run, on: Self.lookAfter)
        #expect(run.answers.pending.isEmpty)
        #expect(try Self.card(Self.yes, run).buttons.first == .yes("Approve"))
    }

    @Test func aRefusalGivesWayToABoardWithLeesAnswerOnItsWayEitherWayRoundTheyCome() throws {
        let refusedFirst = opened()

        _ = refusedFirst.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = refusedFirst.due(at: printedAt.addingTimeInterval(2))
        _ = refusedFirst.answered(Self.yes, .refused("An answer to k1 is on its way already."), at: Self.wrote)
        take(["sr-macapp": Lines.onItsWay], in: refusedFirst)
        #expect(try Self.card(Self.yes, refusedFirst).lines == [.onItsWay("→ Approve", .turn)])
        #expect(try Self.card(Self.yes, refusedFirst).buttons.isEmpty)

        let boardFirst = opened()

        _ = boardFirst.press(.yes("Approve"), on: Self.yes, at: printedAt)
        take(["sr-macapp": Lines.onItsWay], in: boardFirst)
        _ = boardFirst.due(at: printedAt.addingTimeInterval(2))
        _ = boardFirst.answered(Self.yes, .refused("An answer to k1 is on its way already."), at: Self.wrote)
        #expect(try Self.card(Self.yes, boardFirst).lines == [.onItsWay("→ Approve", .turn)])
        #expect(try Self.card(Self.yes, boardFirst).buttons.isEmpty)
    }

    @Test func escapeTakesBackOnlyAnAnswerOnThePageShowingOneOnAPageLeftGoesAsItWould() {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        run.pick(.session("sr-dash02"))
        #expect(!run.undo())
        #expect(run.due(at: printedAt.addingTimeInterval(2)).map(\.ask) == [Self.yes])
    }

    @Test func refusedTheCardSaysWhyAndOffersItsButtonsAgainAskingForNoLook() throws {
        let run = opened()
        let why = "k2 wants a choice: answer it with “Left, the notch's edge” or “Right”."

        _ = run.press(.option("Upward"), on: Self.choice, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        #expect(!run.answered(Self.choice, .refused(why), at: Self.wrote))

        let card = try Self.card(Self.choice, run)

        #expect(card.lines == [.refused(why)])
        #expect(card.buttons.first == .option("Left, the notch's edge"))
    }

    @Test func aRefusalIsLetGoOnceAnotherSessionIsPicked() throws {
        let run = opened()

        _ = run.press(.option("Upward"), on: Self.choice, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        _ = run.answered(Self.choice, .refused("No."), at: Self.wrote)
        run.pick(.session("sr-dash02"))
        run.pick(.session("sr-macapp"))
        take(["sr-macapp": Lines.board], in: run)
        #expect(try Self.card(Self.choice, run).lines.isEmpty)
    }

    /// So the board `watch` carries next has the write, as soon as it can, whatever page shows.
    @Test func eachOfTheWindowsWritesWrittenAsksForALookNowAndRefusedNone() {
        let run = opened()

        run.pick(.session("sr-dash02"))
        #expect(run.answered(Self.yes, .written, at: Self.wrote))
        #expect(!run.answered(Self.yes, .refused("No."), at: Self.wrote))
        #expect(run.snoozed(Self.yes, .written))
        #expect(!run.snoozed(Self.yes, .refused("No.")))
        #expect(run.woke(Self.yes, .written))
        #expect(!run.woke(Self.yes, .refused("No.")))
        #expect(run.finished("sr-gs7kq2", .written))
        #expect(!run.finished("sr-gs7kq2", .refused("No.")))
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

        overThePage(run)
        take(["sr-macapp": Lines.delivered], in: run)

        let asks = try #require(run.page(at: printedAt).session?.asks)

        #expect(asks.map(\.id.ask) == ["k1", "k3", "k2"])
        #expect(asks.map(\.isClosed) == [true, true, false])
        #expect(asks.map(\.buttons.isEmpty) == [true, true, false])
        #expect(asks[0].lines == [.closed(.sent)])
        #expect(asks[1].lines == [.closed(.ignored)])
    }

    @Test func resolvedLeavesItToAsksWhileItKeepsItsPlace() throws {
        let run = opened()

        overThePage(run)
        take(["sr-macapp": Lines.delivered], in: run)
        #expect(run.page(at: printedAt).session?.resolved.map(\.id) == ["k5", "k4"])
    }

    @Test func anotherSessionPickedTheClosedAskMovesToResolved() throws {
        let run = opened()

        overThePage(run)
        take(["sr-macapp": Lines.delivered], in: run)
        run.pick(.session("sr-dash02"))
        run.pick(.session("sr-macapp"))
        take(["sr-macapp": Lines.delivered], in: run)

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
        overThePage(run)
        take(["sr-macapp": resolved], in: run)
        #expect(run.page(at: printedAt).session?.asks.first { $0.id.ask == "k2" }?.lines == [.closed(.resolved("you said \"left\" in the chat"))])
    }

    @Test func aNewAskLandsAtTheTopWashed() throws {
        let run = opened(boards: ["sr-macapp": Lines.delivered])
        let later = printedAt.addingTimeInterval(5)

        take(["sr-macapp": Lines.board], in: run, at: later)

        let asks = try #require(run.page(at: later).session?.asks)

        #expect(asks.map(\.id.ask) == ["k1", "k3", "k2"])
        #expect(asks.map(\.washed) == [later, later, nil])
        #expect(run.page(at: later.addingTimeInterval(2)).session?.asks.compactMap(\.washed) == [])
    }

    @Test func underReducedMotionANewAskIsNotWashed() throws {
        let run = opened(boards: ["sr-macapp": Lines.delivered])

        take(["sr-macapp": Lines.board], in: run, reducesMotion: true)
        #expect(run.page(at: printedAt).session?.asks.compactMap(\.washed) == [])
    }
}

/// Finishing an away session asks first, in place.
struct FinishTests {
    private static let away = "sr-gs7kq2"

    private static func run() -> WindowRun {
        let run = opened()

        run.pick(.session(away))
        take([away: Lines.away], in: run)
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
        #expect(!run.finished(Self.away, .refused("This session is already finished.")))
        #expect(run.page(at: printedAt).session?.finish == .refused("This session is already finished."))
    }

    @Test func finishedItLeavesWithWatchsNextLineAndTheWindowOpensOnWhatNeedsLee() {
        let run = Self.run()

        run.askToFinish(Self.away)
        _ = run.confirmFinish(Self.away)
        #expect(run.finished(Self.away, .written))
        #expect(run.page(at: printedAt).session?.finish == .finishing)
        run.show(heard(line(0), line(3)), at: printedAt, reducesMotion: false)
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
        picked.pick(.session("sr-macapp"))
        picked.pick(.session(Self.away))
        #expect(picked.page(at: printedAt).session?.finish == .offered)

        let closed = Self.run()

        closed.askToFinish(Self.away)
        closed.close()
        closed.open()
        closed.pick(.session(Self.away))
        #expect(closed.page(at: printedAt).session?.finish == .offered)
    }

    @Test func askingLapsesAsTheSessionComesBackOpen() {
        let run = Self.run()

        run.askToFinish(Self.away)
        run.show(heard(line(0), line(with: Self.away, doing: .yourTurn)), at: printedAt, reducesMotion: false)
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.page(at: printedAt).session?.finish == .offered)
    }
}

/// A project opened from its name.
struct ProjectPageTests {
    private static func page() throws -> ProjectPage {
        let run = opened()

        run.pick(.project("sitrep"))
        take(["sr-macapp": Lines.board], in: run)
        return try #require(run.page(at: printedAt).project)
    }

    @Test func itListsItsSessionsEachWithWhatItIsDoingAndWhatWaitsThere() throws {
        let run = opened()

        run.pick(.project("switchboard"))

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

        run.pick(.project("switchboard"))
        take(["sr-dash02": Lines.dashboard, "sr-rq7dgr": Lines.ledger], in: run)

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

        run.pick(.project("sitrep"))
        take(["sr-macapp": Lines.board], in: run)
        run.toggle(ask)
        #expect(run.page(at: printedAt).project?.asks.filter(\.isOpened).map(\.id) == [ask])
        run.toggle(ask)
        #expect(run.page(at: printedAt).project?.asks.filter(\.isOpened).isEmpty == true)
    }

    @Test func anAskSentWhileTheProjectsViewStandsKeepsItsPlaceSayingClaudeHasIt() throws {
        let run = opened()

        run.pick(.project("sitrep"))
        take(["sr-macapp": Lines.board], in: run)
        overThePage(run)
        take(["sr-macapp": Lines.delivered], in: run, on: line(2))

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
