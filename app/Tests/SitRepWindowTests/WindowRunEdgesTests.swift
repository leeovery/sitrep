import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// A wash ends wherever the window is: with a page filling the window, which lists nothing, or closed.
struct WashEndsTests {
    private static let goose = "ask:sr-gs7kq2:k1"

    /// A new ask washing while a page fills the window: once its two seconds are up and the window settles, the window
    /// waits for nothing of it, so no wait already past spins the window.
    @Test(arguments: [Location.project("switchboard"), .session("sr-rq7dgr", from: .project("switchboard"))])
    func aWashEndedIsWaitedForNoMoreWithAPageFillingTheWindow(page: Location) {
        let run = opened()
        let ended = printedAt.addingTimeInterval(3)

        run.go(to: page, by: .sidebar)
        run.show(heard(line(0), line(new: [Self.goose])), at: printedAt, reducesMotion: false)
        #expect(run.nextChange == printedAt.addingTimeInterval(2))
        run.settle(at: ended)
        #expect(run.nextChange.map { $0 > ended } ?? true)
    }

    @Test func aWashEndedIsWaitedForNoMoreWithTheWindowClosed() {
        let run = opened()
        let ended = printedAt.addingTimeInterval(3)

        run.go(to: .project("switchboard"), by: .sidebar)
        run.close()
        run.show(heard(line(0), line(new: [Self.goose])), at: printedAt, reducesMotion: false)
        run.settle(at: ended)
        #expect(run.nextChange.map { $0 > ended } ?? true)
    }
}

/// The list's hold under the pointer, as the list goes with a page filling the window, whose view goes saying nothing.
struct ListHoldTests {
    /// Held while the pointer is over it, the list's hold ends a second after the page fills the window; then the
    /// window waits only on what it waited on before, Your turn's next row folding.
    @Test func theListsHoldEndsAsAPageFillsTheWindow() {
        let run = opened()
        let before = run.nextChange

        run.pointer(over: .list, isIn: true, at: printedAt)
        run.settle(at: printedAt)
        #expect(run.nextChange == before)
        run.go(to: .project("switchboard"), by: .sidebar)
        run.settle(at: printedAt)
        #expect(run.nextChange == printedAt.addingTimeInterval(1))
        run.settle(at: printedAt.addingTimeInterval(1))
        #expect(run.nextChange == before)
    }
}

/// The folds at the lists' feet: closed as their rows go, whatever place shows; as they were as the filter clears;
/// open over a pick the window opens on.
struct ListFoldsTests {
    /// "1 snoozed" opened on Needs you; on Working its ask wakes, so the fold goes; another snoozed, back on Needs you
    /// its fold is folded, not open as it was.
    @Test func aFoldGoneWhileAnotherPlaceShowsComesBackFolded() {
        let run = opened(on: .line(Lines.snoozed[0]), boards: [:])

        run.click(.place(.needsYou))
        run.toggleFold(of: .needsYou)
        #expect(run.list(at: printedAt)?.fold?.isOpen == true)
        run.click(.place(.working))
        run.show(heard(.line(Self.allAwake)), at: printedAt, reducesMotion: false)
        run.show(heard(.line(Lines.snoozed[0])), at: printedAt, reducesMotion: false)
        run.click(.place(.needsYou))
        #expect(run.list(at: printedAt)?.fold?.isOpen == false)
    }

    /// A click on a fold while the filter holds text, which shows it open, changes nothing: as the filter clears, the
    /// fold is folded, as it was.
    @Test func aFoldClickedWhileFilteringIsAsItWasAsTheFilterClears() {
        let run = opened(on: .line(Lines.snoozed[0]), boards: [:])

        run.click(.place(.needsYou))
        run.filter = Filter("harness")
        run.toggleFold(of: .needsYou)
        #expect(run.list(at: printedAt)?.fold?.isOpen == true)
        run.filter = Filter()
        #expect(run.list(at: printedAt)?.fold?.isOpen == false)
    }

    /// Closed on an ask asleep, picked under "N snoozed": the window opening again opens the fold over it, so it shows
    /// picked.
    @Test func reopenedOnAPickUnderAFoldItOpens() throws {
        let run = WindowRun(wall: { printedAt })

        run.show(heard(.line(asleepAlone)), at: printedAt, reducesMotion: false)
        run.open()
        run.toggleFold(of: .needsYou)

        let asleep = try #require(run.list(at: printedAt)?.fold?.rows.first?.pick)

        run.pickInList(asleep, at: printedAt)
        run.close()
        run.open()
        #expect(run.location.picked?.pick == asleep)
        #expect(run.list(at: printedAt)?.fold?.isOpen == true)
        #expect(run.list(at: printedAt)?.row(asleep) != nil)
    }

    /// `watch-snoozed`'s line with Harness's asks all awake.
    private static let allAwake = edited(Lines.snoozed[0]) { $0["snoozed"] = [] }

    /// Remembered on an ask asleep, opened before any board: the first board, which the pick was waiting on, opens
    /// the fold over it.
    @Test func theFirstBoardOpensTheFoldOverARememberedPick() {
        let run = WindowRun(remembered: .place(.needsYou, picked: asleepK1), wall: { printedAt })

        run.open()
        run.show(heard(.line(asleepAlone)), at: printedAt, reducesMotion: false)
        #expect(run.location.picked?.pick == asleepK1.pick)
        #expect(run.list(at: printedAt)?.row(asleepK1.pick) != nil)
    }

    /// Return in the Filter field on a match shown only as the filter opens the fold: it is picked, and stays picked
    /// as the filter clears, its fold opening.
    @Test func theFirstMatchUnderAFoldTheFilterOpenedStaysPickedAsItClears() {
        let run = opened(on: .line(Lines.snoozed[0]), boards: [:])

        run.click(.place(.needsYou))
        run.filter = Filter("review")
        run.openFirstMatch()
        #expect(run.location.picked?.pick == asleepK1.pick)
        run.filter = Filter()
        #expect(run.location.picked?.pick == asleepK1.pick)
        #expect(run.list(at: printedAt)?.row(asleepK1.pick) != nil)
    }

    /// Back, and Forward, to a place whose pick is under a fold Lee closed over it: the fold opens, so it shows.
    @Test func backAndForwardToAPickUnderAFoldOpenIt() {
        let run = WindowRun(wall: { printedAt })

        run.show(heard(.line(asleepAlone)), at: printedAt, reducesMotion: false)
        run.open()
        run.toggleFold(of: .needsYou)
        run.pickInList(asleepK1.pick, at: printedAt)
        run.toggleFold(of: .needsYou)
        #expect(run.list(at: printedAt)?.row(asleepK1.pick) == nil)
        run.click(.place(.working))
        run.goBack()
        #expect(run.list(at: printedAt)?.row(asleepK1.pick) != nil)
        run.toggleFold(of: .needsYou)
        run.goForward()
        run.goBack()
        #expect(run.list(at: printedAt)?.row(asleepK1.pick) != nil)
    }

}

/// Harness's ask k1 asleep, the soonest to wake, as a pick of "N snoozed".
private let asleepK1 = Selection(pick: .snoozed("ask:sr-4g01a7:k1"), session: "sr-4g01a7")

/// `watch-snoozed`'s line with nothing waiting on Lee, its asks asleep alone.
private let asleepAlone = edited(Lines.snoozed[0]) { board in
    board["rows"] = (board["rows"] as! [[String: Any]]).filter { $0["section"] as? String != "needsYou" }
}

/// Your turn's fold as the clock passes the period over the row picked.
struct ClockFoldsTests {
    /// The wall clock, moved on by the test.
    private final class Wall {
        var now = printedAt
    }

    /// The Mac app's turn, picked 30 minutes after it ended, passes the hour: the window settling then opens the fold
    /// it folds into, as the clock is not Lee closing it over his pick.
    @Test func aPickTheClockFoldsIntoNEarlierOpensTheFold() {
        let wall = Wall()
        let run = WindowRun(wall: { wall.now })
        let passes = minutes(before: 30).addingTimeInterval(3600)

        run.show(heard(turned(["sr-macapp": 30, "sr-dash02": 90])), at: printedAt, reducesMotion: false)
        run.open()
        run.click(.place(.yourTurn))
        run.pickInList(.session("sr-macapp"), at: printedAt)
        run.settle(at: printedAt)
        #expect(run.list(at: printedAt)?.fold?.isOpen == false)
        wall.now = passes
        run.settle(at: passes)
        #expect(run.list(at: passes)?.fold?.isOpen == true)
        #expect(run.list(at: passes)?.row(.session("sr-macapp")) != nil)
    }

    /// Lee folding "N earlier" over his pick himself keeps it folded, the clock folding nothing more in.
    @Test func aFoldLeeClosedOverHisPickStaysClosed() {
        let run = WindowRun(wall: { printedAt })

        run.show(heard(turned(["sr-dash02": 90])), at: printedAt, reducesMotion: false)
        run.open()
        run.click(.place(.yourTurn))
        run.toggleFold(of: .yourTurn)
        run.pickInList(.session("sr-dash02"), at: printedAt)
        run.settle(at: printedAt)
        run.toggleFold(of: .yourTurn)
        run.settle(at: printedAt.addingTimeInterval(60))
        #expect(run.list(at: printedAt)?.fold?.isOpen == false)
    }
}

/// Open in SitRep: opening the window afresh onto it, waiting on the first board, and over the filter.
struct OpenedFromOutsideTests {
    /// Opening afresh onto Open in SitRep: there, with no step back to Needs you's first line, which Lee never saw.
    @Test func openingAfreshOntoASessionLeavesNoStepBack() {
        let run = WindowRun(wall: { printedAt })

        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        run.open(landing: "sr-gs7kq2")
        #expect(run.location.picked?.pick == .line("ask:sr-gs7kq2:k1"))
        #expect(!run.canGoBack)
    }

    /// Opening afresh onto a session with no row of its own: its page over its project's, Back to the project.
    @Test func openingAfreshOntoASessionsPageLeavesTheStepBackToItsProject() {
        let run = WindowRun(wall: { printedAt })

        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        run.open(landing: "sr-k7t001")
        #expect(run.location == .session("sr-k7t001", from: .project("kit")))
        run.goBack()
        #expect(run.location == .project("kit"))
        #expect(!run.canGoBack)
    }

    /// Opened afresh onto a session before the first board, it opens there once the board comes, still with no step
    /// back.
    @Test func openingAfreshOntoASessionBeforeABoardLandsWithNoStepBack() {
        let run = WindowRun(wall: { printedAt })

        run.open(landing: "sr-gs7kq2")
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.location.picked?.pick == .line("ask:sr-gs7kq2:k1"))
        #expect(!run.canGoBack)
    }

    /// Opened from outside before the first board, Lee goes somewhere himself: the board coming leaves him there.
    @Test(arguments: [false, true])
    func goingSomewhereBeforeTheBoardDropsTheLandingWaiting(isAfresh: Bool) {
        let run = WindowRun(wall: { printedAt })

        if isAfresh {
            run.open(landing: "sr-gs7kq2")
        } else {
            run.open()
            run.land("sr-gs7kq2")
        }
        run.click(.project("switchboard"))
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.location == .project("switchboard"))
    }

    /// Open in SitRep on the session's page already showing makes no step, nor from its project's page more than the
    /// one to the session's.
    @Test func landingWhereTheWindowIsMakesNoStep() {
        let run = WindowRun(wall: { printedAt })

        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        run.open()
        run.land("sr-k7t001")
        run.land("sr-k7t001")
        run.goBack()
        #expect(run.location == .project("kit"))
        run.goBack()
        #expect(!run.canGoBack)
        run.click(.project("kit"))
        run.land("sr-k7t001")
        run.goBack()
        #expect(run.location == .project("kit"))
        run.goBack()
        #expect(!run.canGoBack)
    }

    /// Opened afresh onto a session before any board, Lee types in the field: the first board lands nothing, and
    /// leaves what he typed.
    @Test func typingBeforeTheBoardDropsTheLandingAndKeepsTheFilter() {
        let run = WindowRun(wall: { printedAt })

        run.open(landing: "sr-gs7kq2")
        run.filter = Filter("kit")
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.filter == Filter("kit"))
        #expect(run.landedLater == 0)
    }

    /// A landing that waited on the board lands once it comes, counted, so the list takes focus; one that lands at
    /// once is not.
    @Test func aLandingThatWaitedIsCountedAsItLands() {
        let run = WindowRun(wall: { printedAt })

        run.open(landing: "sr-gs7kq2")
        #expect(run.landedLater == 0)
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.landedLater == 1)
        run.land("sr-macapp")
        #expect(run.landedLater == 1)
    }

    /// Opened afresh onto one session before any board, then onto another: the window opens onto the second, still
    /// with no step back.
    @Test func aSecondOpenWhileTheFirstWaitsStillOpensAfresh() {
        let run = WindowRun(wall: { printedAt })

        run.open(landing: "sr-gs7kq2")
        run.land("sr-macapp")
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.location.picked?.pick == macAppK1)
        #expect(!run.canGoBack)
    }

    /// A row a board has just dropped, still drawn, clicked: nothing is picked, and the run says so.
    @Test func aRowNoLongerListedPicksNothing() {
        let run = opened()

        #expect(!run.pickInList(.line("ask:sr-gone:k1"), at: printedAt))
        #expect(run.location.picked?.pick == macAppK1)
        #expect(run.pickInList(needsYouLines[2], at: printedAt))
    }

    /// A sidebar row clicked twice, by its gesture and its selection both: one step.
    @Test func aRowClickedTwiceMakesOneStep() {
        let run = WindowRun(wall: { printedAt })

        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        run.open()
        run.click(.project("kit"))
        run.click(.project("kit"))
        run.goBack()
        #expect(run.location.place == .needsYou)
        #expect(!run.canGoBack)
    }

    /// Open in SitRep with text in the filter that would hide the row it lands on: the filter clears, and the row
    /// shows picked.
    @Test func anOpenFromOutsideClearsTheFilter() {
        let run = opened()

        run.filter = Filter("switchboard")
        run.land("sr-gs7kq2")
        #expect(run.filter.isEmpty)
        #expect(run.list(at: printedAt)?.row(.line("ask:sr-gs7kq2:k1")) != nil)
    }
}
