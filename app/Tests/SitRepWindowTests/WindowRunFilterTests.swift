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

    /// A run of arrow keys down the Needs you view reads only the row it stops on, as down Projects.
    @Test func aRunOfPicksInNeedsYouReadsOnlyTheLast() {
        let run = opened()
        let rows = run.listed(at: printedAt).flat.map { Pick.session($0.id) }

        run.sidebar = .needsYou
        #expect(run.pickInList(rows[1], at: printedAt).map(\.session) == ["sr-dash02"])
        #expect(run.pickInList(rows[2], at: printedAt.addingTimeInterval(0.1)).isEmpty)
        #expect(run.pickInList(rows[3], at: printedAt.addingTimeInterval(0.2)).isEmpty)
        #expect(run.settledReads(at: printedAt.addingTimeInterval(0.35)).map(\.session) == ["sr-rq7dgr"])
    }
}
