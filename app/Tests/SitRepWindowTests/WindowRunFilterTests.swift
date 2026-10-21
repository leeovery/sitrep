import Foundation
@testable import SitRepWindow
import Testing

/// The sidebar's filter and folds as the window runs them: the filter narrows the list it shows, Needs you and the
/// projects alike, Return opens the first match, and neither the filter nor a fold ever moves the pick.
struct WindowRunFilterTests {
    @Test func theFilterNarrowsTheListItShowsAndClearedGivesTheWholeBoardBack() {
        let run = opened()

        run.filter = Filter("dash")
        #expect(run.listed(at: printedAt).sessions.map(\.id) == ["sr-dash02"])
        #expect(run.listed(at: printedAt).needsYou.map(\.id) == ["sr-dash02"])
        run.filter = Filter()
        #expect(run.listed(at: printedAt) == Listed(heard(line(0))))
    }

    @Test func filteringNeverMovesThePickEvenWithThePickedSessionFilteredOut() {
        let run = opened()
        let page = run.page(at: printedAt)

        run.filter = Filter("ledg")
        #expect(run.pick == .session("sr-macapp"))
        #expect(run.spot == .needsYou("sr-macapp"))
        #expect(run.page(at: printedAt) == page)
    }

    /// The first row of the list: Goosemates' ask under Needs you comes before Request ledger under Switchboard.
    @Test func returnOpensTheFirstMatchInTheListAndReadsIt() {
        let run = opened()

        run.filter = Filter("le")
        #expect(run.openFirstMatch().map(\.session) == ["sr-gs7kq2"])
        #expect(run.pick == .session("sr-gs7kq2"))
        #expect(run.spot == .needsYou("sr-gs7kq2"))
        run.filter = Filter("ledg")
        #expect(run.openFirstMatch().map(\.session) == ["sr-rq7dgr"])
        #expect(run.spot == .board(.session("sr-rq7dgr")))
    }

    /// Switchboard folded while the field holds "ledg", Request ledger's row, its one match, hidden inside it: Return
    /// opens nothing, and the pick stays.
    @Test func returnOpensOnlyWhatTheListShows() {
        let run = opened()

        run.filter = Filter("ledg")
        run.toggle(.project("switchboard"))
        #expect(run.openFirstMatch().isEmpty)
        #expect(run.pick == .session("sr-macapp"))
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
        run.filter = Filter("ledg")
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

/// The sidebar's folds as the window runs them: a heading folds and unfolds what is under it, the folds Lee leaves kept,
/// and while the filter holds text every project with a match shows open, its fold coming back as the field clears.
struct WindowRunFoldsTests {
    private static func ids(_ run: WindowRun) -> [Sidebar.Line.ID] {
        run.sidebar(at: printedAt).lines.map(\.id)
    }

    @Test func itOpensWithTheFoldsItWasGiven() {
        var folds = Folds()

        folds.toggle(.project("switchboard"))
        #expect(WindowRun(folds: folds).folds == folds)
        #expect(WindowRun().folds == Folds())
    }

    @Test func aHeadingFoldsAndUnfoldsItsRowsAndThePickStays() {
        let run = opened()

        _ = run.pickInList(.board(.session("sr-dash02")), at: printedAt)
        run.toggle(.project("switchboard"))
        #expect(run.folds.contains(.project("switchboard")))
        #expect(!Self.ids(run).contains(.spot(.board(.session("sr-dash02")))))
        #expect(run.pick == .session("sr-dash02"))
        #expect(run.spot == .board(.session("sr-dash02")))
        #expect(run.page(at: printedAt).session?.id == "sr-dash02")
        run.toggle(.project("switchboard"))
        #expect(Self.ids(run).contains(.spot(.board(.session("sr-dash02")))))
    }

    @Test func whileTheFilterHoldsTextAProjectWithAMatchShowsOpenAndItsFoldComesBackAsItClears() {
        let run = opened()

        run.toggle(.project("switchboard"))
        run.filter = Filter("ledg")
        #expect(Self.ids(run).contains(.spot(.board(.session("sr-rq7dgr")))))
        #expect(run.folds.contains(.project("switchboard")))
        run.filter = Filter()
        #expect(!Self.ids(run).contains(.spot(.board(.session("sr-rq7dgr")))))
    }

    /// A heading clicked while the field holds text folds only until the field clears, leaving Lee's folds as they were.
    @Test func aFoldMadeWhileFilteringLastsUntilTheFieldClears() {
        let run = opened()

        run.filter = Filter("ledg")
        run.toggle(.project("switchboard"))
        #expect(!Self.ids(run).contains(.spot(.board(.session("sr-rq7dgr")))))
        run.filter = Filter("ledge")
        #expect(!Self.ids(run).contains(.spot(.board(.session("sr-rq7dgr")))))
        #expect(run.folds == Folds())
        run.filter = Filter()
        run.filter = Filter("ledg")
        #expect(Self.ids(run).contains(.spot(.board(.session("sr-rq7dgr")))))
    }

    @Test func theQuietProjectsStartOpenAndFoldOfTheirOwn() {
        let run = opened()

        #expect(Self.ids(run).suffix(2) == [.quietHeading, .spot(.board(.project("kit")))])
        run.toggle(.quiet)
        #expect(Self.ids(run).last == .quietHeading)
        #expect(run.folds.quiet)
    }
}
