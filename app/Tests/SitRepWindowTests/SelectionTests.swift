import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// Where the window is as Lee moves, over the first line the real `watch` printed: a row picked in the list, the
/// arrows through it, a place or a project clicked in the sidebar, a session opened from a project's page or from
/// outside, and Back and Forward.
struct SelectionTests {
    /// A row clicked is the list's pick, its session's page beside the list; it replaces the step, making none.
    @Test func aRowClickedIsThePickItsSessionsPageBesideTheList() throws {
        let run = opened()
        let back = run.canGoBack

        run.pickInList(needsYouLines[2], at: printedAt)
        #expect(run.location.picked?.pick == needsYouLines[2])
        #expect(run.list(at: printedAt)?.position(of: run.location.picked?.pick)?.text == "3 / 6")
        #expect(try #require(run.page(at: printedAt).detail).id == "sr-dash02")
        #expect(run.canGoBack == back)
    }

    @Test func aRowTheListDoesNotHoldPicksNothing() {
        let run = opened()

        run.pickInList(.session("sr-rq7dgr"), at: printedAt)
        #expect(run.location.picked?.pick == macAppK1)
    }

    /// ↓ and ↑ walk the rows as the list shows them, and nowhere past either end.
    @Test func theArrowsWalkTheListAndGoNowherePastItsEnds() {
        let run = opened()

        run.step(down: false, at: printedAt)
        #expect(run.location.picked?.pick == needsYouLines[0])
        run.step(down: false, at: printedAt)
        #expect(run.location.picked?.pick == needsYouLines[0])
        (0 ..< 9).forEach { _ in run.step(down: true, at: printedAt) }
        #expect(run.location.picked?.pick == needsYouLines[5])
    }

    /// The Mac app's lines answered: nothing shows picked, the page staying on its session; ↓ goes on from where its
    /// line stood, under Switchboard's stop, not from the top.
    @Test func fromALineAnsweredDownGoesOnFromWhereItStood() {
        let run = opened()

        run.show(heard(answered("sr-macapp")), at: printedAt, reducesMotion: false)
        #expect(run.list(at: printedAt)?.row(run.location.picked?.pick) == nil)
        #expect(run.page(at: printedAt).session?.id == "sr-macapp")
        run.step(down: true, at: printedAt)
        #expect(run.location.picked?.pick == needsYouLines[2])
    }

    @Test func withNothingPickedDownGoesToTheFirstRowAndUpNowhere() {
        let run = opened()

        run.click(.place(.yourTurn))
        run.step(down: false, at: printedAt)
        #expect(run.location == .place(.yourTurn))
        run.step(down: true, at: printedAt)
        #expect(run.location.picked?.pick == .session("sr-rq7dgr"))
    }

    /// A place clicked shows its list, nothing picked, as a step Back returns from.
    @Test func aPlaceClickedShowsItsListAsAStep() {
        let run = opened()
        let before = run.location

        run.click(.place(.yourTurn))
        #expect(run.location == .place(.yourTurn))
        #expect(run.list(at: printedAt)?.picks == [.session("sr-rq7dgr")])
        run.goBack()
        #expect(run.location == before)
    }

    /// As Mail does for the mailbox already open: its pick stays, and no step is made.
    @Test func aClickOnThePlaceShowingChangesNothing() {
        let run = opened()
        let before = run.location
        let back = run.canGoBack

        run.click(.place(.needsYou))
        #expect(run.location == before)
        #expect(run.canGoBack == back)
    }

    /// A project's page fills the window, no list beside it, the project picked in the sidebar.
    @Test func aProjectClickedFillsTheWindowWithItsPage() throws {
        let run = opened()

        run.click(.project("switchboard"))
        #expect(run.location.root == .project("switchboard"))
        #expect(run.list(at: printedAt) == nil)
        #expect(try #require(run.page(at: printedAt).project).key == "switchboard")
    }

    /// From a project's page a session's page is pushed over it, the project still picked in the sidebar; a click on
    /// the project's row goes back to its page; the session page's project, its breadcrumb, opens it as a step too.
    @Test func aSessionOpenedFromItsProjectIsPushedTheProjectPickedInTheSidebar() throws {
        let run = opened()

        run.click(.project("switchboard"))
        run.go(to: .session("sr-rq7dgr", from: .project("switchboard")), by: .projectSession)
        #expect(run.location.root == .project("switchboard"))
        #expect(run.list(at: printedAt) == nil)
        #expect(try #require(run.page(at: printedAt).fullSession).id == "sr-rq7dgr")
        run.click(.project("switchboard"))
        #expect(run.location == .project("switchboard"))
        run.goBack()
        run.go(to: .project("switchboard"), by: .breadcrumb)
        #expect(run.location == .project("switchboard"))
        run.goBack()
        #expect(run.location == .session("sr-rq7dgr", from: .project("switchboard")))
    }

    /// Two sessions need Lee, each a window holds: the window opens on the top of Needs you, the newest line,
    /// Contoso's ask 5 minutes old, over Northwind's, whose newest is 20 minutes old though its oldest, 90, is the
    /// oldest of all.
    @Test func theWindowOpensOnTheTopOfNeedsYouTheNewestLine() {
        let run = WindowRun(wall: { printedAt })
        let contoso = Built(id: "s2", project: "contoso", waiting: [5])

        run.show(heard(Built.printed([
            Built(id: "s1", project: "northwind", waiting: [90, 60, 20]), contoso,
        ])), at: printedAt, reducesMotion: false)
        run.open()
        #expect(run.location.place == .needsYou)
        #expect(run.location.picked?.pick == .line(contoso.line(0)))
    }

    // MARK: Opened from outside

    /// "Open in SitRep" on the Mac app picks its newest line by its time, k1, though core lists it last of its three.
    @Test func openedFromOutsideASessionNeedingLeeLandsOnItsNewestLine() {
        let run = opened()

        run.click(.project("kit"))
        run.land("sr-macapp")
        #expect(run.location.picked?.pick == macAppK1)
        #expect(run.following == ["sr-macapp"])
        run.goBack()
        #expect(run.location == .project("kit"))
    }

    @Test func openedFromOutsideASessionOnItsTurnLandsOnItsRow() {
        let run = opened()

        run.land("sr-rq7dgr")
        #expect(run.location.picked?.pick == .session("sr-rq7dgr"))
        #expect(run.location.place == .yourTurn)
    }

    /// Kit's away session, nothing waiting, has no row: its project's page, then its own pushed over it, two steps.
    @Test func openedFromOutsideASessionWithNoRowPushesItsPageOverItsProjects() {
        let run = opened()

        run.land("sr-k7t001")
        #expect(run.location == .session("sr-k7t001", from: .project("kit")))
        run.goBack()
        #expect(run.location == .project("kit"))
    }

    /// Under "N earlier", its row shows: the fold opens for it.
    @Test func openedFromOutsideARowUnderNEarlierOpensTheFold() {
        let run = opened(wall: { printedAt.addingTimeInterval(3600) })

        run.land("sr-rq7dgr")
        #expect(run.list(at: printedAt)?.row(.session("sr-rq7dgr")) != nil)
        #expect(run.list(at: printedAt)?.fold?.isOpen == true)
    }

    /// Before a board is heard the open waits, and lands on the first one.
    @Test func openedFromOutsideBeforeABoardLandsOnTheFirst() {
        let run = WindowRun()

        run.open()
        run.land("sr-rq7dgr")
        #expect(run.location == .place(.needsYou))
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.location.picked?.pick == .session("sr-rq7dgr"))
        #expect(run.following == ["sr-rq7dgr"])
    }

    @Test func aSessionNotOnTheBoardOpensNothing() {
        let run = opened()
        let before = run.location

        run.land("sr-gone")
        #expect(run.location == before)
    }

    // MARK: Back and Forward

    /// Back returns through the steps, rows picked within the list replacing theirs; Forward goes again.
    @Test func backSkipsTheRowsSteppedThroughForwardGoesAgain() {
        let run = opened()

        run.click(.project("kit"))
        run.click(.place(.needsYou))
        run.pickInList(needsYouLines[1], at: printedAt)
        run.pickInList(needsYouLines[3], at: printedAt)
        run.goBack()
        #expect(run.location == .project("kit"))
        #expect(run.canGoForward)
        run.goForward()
        #expect(run.location.picked?.pick == needsYouLines[3])
        #expect(!run.canGoForward)
    }

    /// Back returns to a pick as it last stood, so ↓ after Back goes on from there.
    @Test func afterBackDownGoesOnFromWhereThePickStood() {
        let run = opened()

        run.pickInList(needsYouLines[3], at: printedAt)
        run.click(.project("kit"))
        run.goBack()
        run.step(down: true, at: printedAt)
        #expect(run.location.picked?.pick == needsYouLines[4])
    }

    /// Closed and opened again, the window starts its history afresh.
    @Test func backIsForTheWindowOpenNotKeptAcrossACloseOrALaunch() {
        let run = opened()

        run.click(.project("kit"))
        run.close()
        run.open()
        #expect(!run.canGoBack)
        #expect(!WindowRun().canGoBack)
    }
}

private extension Page {
    var detail: SessionPage? {
        if case let .detail(page) = self {
            return page
        }
        return nil
    }

    var fullSession: SessionPage? {
        if case let .session(page) = self {
            return page
        }
        return nil
    }
}
