import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// The window's toolbar as the run has it, over the lines the real `watch` printed: Back and Forward from the history,
/// and on a place its title, where the pick stands, and up and down as ↑ and ↓ would step.
struct ToolbarTests {
    /// Open on `watch`'s first line, on Needs you's first line, with nowhere to go back to.
    private static func run() -> WindowRun {
        let run = WindowRun(wall: { printedAt })

        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        run.open()
        return run
    }

    // MARK: Back and Forward

    @Test func openedThereIsNowhereBackNorForward() {
        let toolbar = Self.run().toolbar

        #expect(!toolbar.canGoBack)
        #expect(!toolbar.canGoForward)
    }

    /// A place clicked in the sidebar is a step: Back goes, and leaves Forward a step to go again.
    @Test func backAfterASidebarClickThenForward() {
        let run = Self.run()

        run.click(.place(.yourTurn))
        #expect(run.toolbar.canGoBack && !run.toolbar.canGoForward)
        run.goBack()
        #expect(run.location.place == .needsYou)
        #expect(!run.toolbar.canGoBack && run.toolbar.canGoForward)
        run.goForward()
        #expect(run.location == .place(.yourTurn))
        #expect(run.toolbar.canGoBack && !run.toolbar.canGoForward)
    }

    /// Another row picked in the list, by a click, an arrow or up and down, replaces the step: nothing to go back to.
    @Test func aPickInTheListReplacesTheStep() {
        let run = Self.run()

        run.pickInList(needsYouLines[3], at: printedAt)
        run.step(down: true, at: printedAt)
        #expect(!run.toolbar.canGoBack)
        run.click(.project("kit"))
        run.goBack()
        #expect(run.location.picked?.pick == needsYouLines[4])
        #expect(!run.toolbar.canGoBack)
    }

    /// Closed and opened again, the window starts afresh: nowhere back nor forward.
    @Test func reopenedThereIsNowhereBackNorForward() {
        let run = Self.run()

        run.click(.place(.yourTurn))
        run.goBack()
        run.close()
        run.open()
        #expect(!run.toolbar.canGoBack && !run.toolbar.canGoForward)
    }

    /// Going somewhere new after Back lets go of what lay forward.
    @Test func goingSomewhereAfterBackLetsGoOfForward() {
        let run = Self.run()

        run.click(.place(.yourTurn))
        run.goBack()
        run.click(.project("kit"))
        #expect(run.toolbar.canGoBack && !run.toolbar.canGoForward)
    }

    // MARK: The list

    /// Needs you, the Mac app's newest line picked, second of six: its title and where it stands, rows both ways.
    @Test func onAPlaceItHasThePlacesTitleAndWhereThePickStands() throws {
        let toolbar = opened().toolbar
        let listing = try #require(toolbar.listing)

        #expect(toolbar.title == "Needs you")
        #expect(toolbar.showsTitle)
        #expect(listing.position?.text == "2 / 6")
        #expect(listing.position?.spoken == "2 of 6")
        #expect(listing.canStepUp && listing.canStepDown)
    }

    @Test func upIsDimmedOnTheFirstRowAndDownOnTheLast() throws {
        let run = Self.run()
        let first = try #require(run.toolbar.listing)

        #expect(first.position?.text == "1 / 6")
        #expect(!first.canStepUp && first.canStepDown)
        run.pickInList(needsYouLines[5], at: printedAt)

        let last = try #require(run.toolbar.listing)

        #expect(last.position?.text == "6 / 6")
        #expect(last.canStepUp && !last.canStepDown)
    }

    /// The Mac app's lines answered: nothing shows picked, so no position, the page staying on its session; up and down
    /// go on from where its line stood, under Switchboard's stop.
    @Test func afterAnAnswerThereIsNoPositionAndUpAndDownGoOnFromWhereThePickStood() throws {
        let run = opened()

        run.show(heard(answered("sr-macapp")), at: printedAt, reducesMotion: false)

        let left = try #require(run.toolbar.listing)

        #expect(left.position == nil)
        #expect(run.page(at: printedAt).session?.id == "sr-macapp")
        #expect(left.canStepUp && left.canStepDown)
        run.step(down: true, at: printedAt)
        #expect(run.location.picked?.pick == needsYouLines[2])
        #expect(run.toolbar.listing?.position?.text == "2 / 3")
    }

    /// Nothing picked: no position; down goes to the first row, up nowhere.
    @Test func withNothingPickedThereIsNoPositionDownGoesToTheFirstRowUpNowhere() throws {
        let run = Self.run()

        run.click(.place(.yourTurn))

        let listing = try #require(run.toolbar.listing)

        #expect(run.toolbar.title == "Your turn")
        #expect(listing.position == nil)
        #expect(!listing.canStepUp && listing.canStepDown)
    }

    /// A pick under a fold closed over it: no position, as the list shows nothing picked; up and down act from where
    /// the pick stood, under the line above it.
    @Test func aFoldClosedOverThePickLeavesNoPositionAndTheStepsGoOnFromWhereItStood() throws {
        let run = WindowRun(wall: { printedAt })
        var asleep = Built(id: "s2", project: "contoso")

        asleep.snoozed = [(age: 40, wakesIn: 60), (age: 50, wakesIn: 120)]
        run.show(
            heard(Built.printed([Built(id: "s1", project: "northwind", waiting: [30]), asleep])), at: printedAt,
            reducesMotion: false
        )
        run.open()
        run.toggleFold(of: .needsYou)
        run.pickInList(.snoozed(asleep.asleep(0)), at: printedAt)
        #expect(run.toolbar.listing?.position?.text == "2 / 3")
        run.toggleFold(of: .needsYou)

        let folded = try #require(run.toolbar.listing)

        #expect(folded.position == nil)
        #expect(folded.canStepUp && !folded.canStepDown)
        run.step(down: false, at: printedAt)
        #expect(run.location.picked?.pick == .line("ask:s1:k0"))
        #expect(run.toolbar.listing?.position?.text == "1 / 1")
    }

    // MARK: A page filling the window

    /// A project's page, and a session's pushed from it, fill the window: Back and Forward alone, the page's name the
    /// window's title, not shown.
    @Test func aPageFillingTheWindowHasBackAndForwardAloneTitledByThePage() {
        let run = Self.run()

        run.click(.project("switchboard"))
        #expect(run.toolbar == Toolbar(title: "Switchboard", canGoBack: true, canGoForward: false, listing: nil))
        #expect(!run.toolbar.showsTitle)
        run.go(to: .session("sr-rq7dgr", from: .project("switchboard")), by: .projectSession)
        #expect(run.toolbar.listing == nil)
        #expect(run.toolbar.title == "Request ledger")
    }

    /// Before any board, a page left on is not on one: the window's own name.
    @Test func aPageNotOnTheBoardIsTitledByTheWindowsName() {
        let run = WindowRun(remembered: .project("kit"))

        run.open()
        #expect(run.toolbar.title == "SitRep")
    }
}
