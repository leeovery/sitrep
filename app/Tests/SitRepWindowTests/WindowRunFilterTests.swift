import Foundation
@testable import SitRepWindow
import Testing

/// The sidebar's view and its filter as the window runs them: the filter narrows the list it shows, Return opens the
/// first match in the view chosen, and neither ever moves the pick.
struct WindowRunFilterTests {
    @Test func itOpensOnTheViewItWasGiven() {
        #expect(WindowRun().sidebar == .projects)
        #expect(WindowRun(sidebar: .needsYou).sidebar == .needsYou)
    }

    @Test func theFilterNarrowsTheListItShowsAndClearedGivesTheWholeBoardBack() {
        let run = opened()

        run.filter = Filter("ledg")
        #expect(run.listed(at: printedAt).sessions.map(\.id) == ["sr-rq7dgr"])
        #expect(run.listed(at: printedAt).flat.map(\.id) == ["sr-rq7dgr"])
        run.filter = Filter()
        #expect(run.listed(at: printedAt) == Listed(heard(line(0))))
    }

    @Test func filteringNeverMovesThePickEvenWithThePickedSessionFilteredOut() {
        let run = opened()
        let page = run.page(at: printedAt)

        run.filter = Filter("ledg")
        #expect(run.pick == .session("sr-macapp"))
        #expect(run.page(at: printedAt) == page)
        run.sidebar = .needsYou
        #expect(run.pick == .session("sr-macapp"))
        #expect(run.page(at: printedAt) == page)
    }

    @Test(arguments: [(Sidebar.projects, "sr-rq7dgr"), (.needsYou, "sr-gs7kq2")])
    func returnOpensTheFirstMatchInTheViewChosenAndReadsIt(sidebar: Sidebar, first: String) {
        let run = opened()

        run.sidebar = sidebar
        run.filter = Filter("le")
        #expect(run.openFirstMatch().map(\.session) == [first])
        #expect(run.pick == .session(first))
    }

    @Test(arguments: ["", "zzz"])
    func returnWithNoFilterOrNoMatchOpensNothing(_ typed: String) {
        let run = opened()

        run.filter = Filter(typed)
        #expect(run.openFirstMatch().isEmpty)
        #expect(run.pick == .session("sr-macapp"))
    }

    /// What the filter holds is not kept: reopened, the window lists the whole board, its pick's row among it.
    @Test func closingTheWindowClearsTheFilter() {
        let run = opened()

        run.filter = Filter("ledg")
        run.close()
        #expect(run.filter.isEmpty)
        _ = run.open()
        #expect(run.listed(at: printedAt).sessions.map(\.id).contains("sr-macapp"))
    }

    /// Settings shows, its foot picked, and Return in the field opens the first match over it.
    @Test func returnWhileSettingsShowsOpensTheFirstMatchAndLeavesSettings() {
        let run = opened()

        _ = run.pick(.settings)
        run.filter = Filter("le")
        #expect(run.page(at: printedAt) == .settings)
        #expect(run.openFirstMatch().map(\.session) == ["sr-rq7dgr"])
        #expect(run.pick == .session("sr-rq7dgr"))
        #expect(run.page(at: printedAt).session?.id == "sr-rq7dgr")
    }

    @Test func minimisingTheWindowKeepsTheFilter() {
        let run = opened()

        run.filter = Filter("ledg")
        run.minimise()
        _ = run.restore()
        #expect(run.filter == Filter("ledg"))
    }
}
