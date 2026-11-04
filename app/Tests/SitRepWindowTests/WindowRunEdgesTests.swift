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

        run.show(heard(.line(Self.nothingWaiting)), at: printedAt, reducesMotion: false)
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

    /// `watch-snoozed`'s line with nothing waiting on Lee, its asks asleep alone.
    private static let nothingWaiting = edited(Lines.snoozed[0]) { board in
        board["rows"] = (board["rows"] as! [[String: Any]]).filter { $0["section"] as? String != "needsYou" }
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
