import Foundation
import enum SitRepPanel.FoldPeriod
import struct SitRepPanel.Earlier
@testable import SitRepWindow
import Testing

/// The sidebar's filter and folds as the window runs them: the filter narrows the list it shows, every section alike,
/// Return opens the first match, and neither the filter nor a fold ever moves the pick.
struct WindowRunFilterTests {
    @Test func theFilterNarrowsTheListItShowsAndClearedGivesTheWholeBoardBack() {
        let run = opened()

        run.filter = Filter("dash")
        #expect(run.listed(at: printedAt).rows.map(\.id) == ["sr-dash02"])
        #expect(run.listed(at: printedAt).projects.isEmpty)
        run.filter = Filter()
        #expect(run.listed(at: printedAt) == Listed(heard(line(0))))
    }

    @Test func filteringNeverMovesThePickEvenWithThePickedSessionFilteredOut() {
        let run = opened()
        let page = run.page(at: printedAt)

        run.filter = Filter("ledg")
        #expect(run.pick == .session("sr-macapp"))
        #expect(run.page(at: printedAt) == page)
    }

    /// The first row of the list: Goosemates' ask under Needs you comes before Request ledger under Your turn.
    @Test func returnOpensTheFirstMatchInTheListAndReadsIt() {
        let run = opened()

        run.filter = Filter("le")
        #expect(run.openFirstMatch().map(\.session) == ["sr-gs7kq2"])
        #expect(run.pick == .session("sr-gs7kq2"))
        run.filter = Filter("ledg")
        #expect(run.openFirstMatch().map(\.session) == ["sr-rq7dgr"])
    }

    /// Your turn folded while the field holds "ledg", Request ledger's row, its one match, hidden inside it: Return
    /// opens nothing. Then with "switch", Needs you folded too: Return opens the first row that shows, Switchboard's
    /// under Projects.
    @Test func returnOpensOnlyWhatTheListShows() {
        let run = opened()

        run.filter = Filter("ledg")
        run.toggle(.section(.yourTurn))
        #expect(run.openFirstMatch().isEmpty)
        #expect(run.pick == .session("sr-macapp"))
        run.filter = Filter("switch")
        run.toggle(.section(.needsYou))
        #expect(run.openFirstMatch().map(\.session) == ["sr-dash02", "sr-rq7dgr"])
        #expect(run.pick == .project("switchboard"))
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
        #expect(run.listed(at: printedAt).rows.map(\.id).contains("sr-macapp"))
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

/// The sidebar's folds as the window runs them: a heading folds and unfolds what is under it, the folds Lee leaves
/// kept, and while the filter holds text every section with a match shows open, "N earlier" too, its fold coming back
/// as the field clears.
struct WindowRunFoldsTests {
    private static func ids(_ run: WindowRun) -> [Sidebar.Line.ID] {
        run.sidebar(at: printedAt).lines.map(\.id)
    }

    @Test func itOpensWithTheFoldsItWasGiven() {
        let folds = Folds(sections: [.yourTurn], projects: false)

        #expect(WindowRun(folds: folds).folds == folds)
        #expect(WindowRun().folds == Folds())
    }

    @Test func aHeadingFoldsAndUnfoldsItsRowsAndThePickStays() {
        let run = opened()

        _ = run.pickInList(.session("sr-dash02"), at: printedAt)
        run.toggle(.section(.needsYou))
        #expect(run.folds.contains(.section(.needsYou)))
        #expect(!Self.ids(run).contains(.pick(.session("sr-dash02"))))
        #expect(run.pick == .session("sr-dash02"))
        #expect(run.page(at: printedAt).session?.id == "sr-dash02")
        run.toggle(.section(.needsYou))
        #expect(Self.ids(run).contains(.pick(.session("sr-dash02"))))
    }

    /// Projects folded as it is at first, Your turn folded by Lee: typing "switch" opens both, Lee's folds as he left
    /// them; cleared, they fold again.
    @Test func whileTheFilterHoldsTextEverySectionWithAMatchShowsOpenAndItsFoldComesBackAsItClears() {
        let run = opened()

        run.toggle(.section(.yourTurn))
        run.filter = Filter("switch")
        #expect(Self.ids(run) == [
            .fold(.section(.needsYou)), .pick(.session("sr-dash02")), .fold(.section(.yourTurn)),
            .pick(.session("sr-rq7dgr")), .fold(.projects), .pick(.project("switchboard")),
        ])
        #expect(run.folds == Folds(sections: [.yourTurn]))
        run.filter = Filter()
        #expect(!Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
        #expect(!Self.ids(run).contains(.pick(.project("switchboard"))))
    }

    /// An hour on, Request ledger's turn has passed the fold period; typing its name shows it under "N earlier".
    @Test func whileTheFilterHoldsTextNEarliersMatchingRowsShow() {
        let run = opened(wall: { printedAt.addingTimeInterval(3600) })

        run.filter = Filter("ledg")
        #expect(Self.ids(run) == [.fold(.section(.yourTurn)), .fold(.earlier), .pick(.session("sr-rq7dgr"))])
        run.filter = Filter()
        #expect(Self.ids(run).contains(.fold(.earlier)))
        #expect(!Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
    }

    /// A heading clicked while the field holds text folds only until the field clears, leaving Lee's folds as they were.
    @Test func aFoldMadeWhileFilteringLastsUntilTheFieldClears() {
        let run = opened()

        run.filter = Filter("ledg")
        run.toggle(.section(.yourTurn))
        #expect(!Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
        run.filter = Filter("ledge")
        #expect(!Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
        #expect(run.folds == Folds())
        run.filter = Filter()
        run.filter = Filter("ledg")
        #expect(Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
    }

    @Test func projectsStartsFoldedAndOpensToEveryProject() {
        let run = opened()

        #expect(Self.ids(run).last == .fold(.projects))
        run.toggle(.projects)
        #expect(!run.folds.projects)
        #expect(Self.ids(run).suffix(4) == [
            .pick(.project("sitrep")), .pick(.project("switchboard")), .pick(.project("goosemates")),
            .pick(.project("kit")),
        ])
    }
}

/// Your turn's rows fold into "N earlier" as they pass the fold period, by the wall clock, and refold as time passes
/// and as the period changes, nothing polling: the next row to pass it is the window's next change.
struct WindowRunPeriodTests {
    /// The wall clock, moved on by the test.
    private final class Wall {
        var now = printedAt
    }

    private static func ids(_ run: WindowRun) -> [Sidebar.Line.ID] {
        run.sidebar(at: printedAt).lines.map(\.id)
    }

    /// The Mac app's and Dashboard redesign's turns ended 30 and 90 minutes before the board was seeded, Request
    /// ledger's 12: Dashboard redesign's is past the hour.
    private static func run(_ wall: Wall, period: FoldPeriod = .hour) -> WindowRun {
        let run = WindowRun(period: period, wall: { wall.now })

        _ = run.show(heard(turned(["sr-macapp": 30, "sr-dash02": 90])), at: printedAt, reducesMotion: false)
        _ = run.open()
        return run
    }

    @Test func aRowPastThePeriodFoldsIntoNEarlierTheRestShowing() throws {
        let run = Self.run(Wall())
        let sidebar = run.sidebar(at: printedAt)

        #expect(Array(sidebar.lines.map(\.id).drop { $0 != .fold(.section(.yourTurn)) }.prefix(4)) == [
            .fold(.section(.yourTurn)), .pick(.session("sr-rq7dgr")), .pick(.session("sr-macapp")), .fold(.earlier),
        ])
        #expect(sidebar.lines.contains(.earlier(Earlier(projects: ["Switchboard"], isOpen: false))))
    }

    /// The Mac app's turn passes the hour 30 minutes on, at which the window is drawn again, folding it in.
    @Test func asTimePassesARowFoldsInAtTheMomentItPassesThePeriod() {
        let wall = Wall()
        let run = Self.run(wall)
        let passes = minutes(before: 30).addingTimeInterval(3600)

        #expect(run.nextChange == passes)
        wall.now = passes.addingTimeInterval(-0.001)
        #expect(Self.ids(run).contains(.pick(.session("sr-macapp"))))
        wall.now = passes
        #expect(!Self.ids(run).contains(.pick(.session("sr-macapp"))))
        #expect(run.sidebar(at: printedAt).lines.contains(.earlier(Earlier(projects: ["SitRep", "Switchboard"], isOpen: false))))
    }

    @Test func thePeriodChangingRefoldsAtOnce() {
        let run = Self.run(Wall())

        run.period = .never
        #expect(!Self.ids(run).contains(.fold(.earlier)))
        #expect(run.nextChange == nil)
        run.period = .fourHours
        #expect(!Self.ids(run).contains(.fold(.earlier)))
        run.period = .hour
        #expect(Self.ids(run).contains(.fold(.earlier)))
    }

    /// "Today" folds what ended before local midnight: Request ledger's turn ended at 9:41 in London.
    @Test func todayFoldsWhatEndedBeforeMidnight() throws {
        let wall = Wall()
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))

        let midnight = calendar.startOfDay(for: printedAt)
        let run = WindowRun(period: .today, wall: { wall.now }, calendar: calendar)

        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        wall.now = midnight.addingTimeInterval(24 * 3600 - 1)
        #expect(!Self.ids(run).contains(.fold(.earlier)))
        wall.now = midnight.addingTimeInterval(24 * 3600)
        #expect(Self.ids(run).contains(.fold(.earlier)))
    }

    @Test func nEarlierOpensInPlaceAndFoldsAgainEachTimeTheWindowOpens() {
        let run = Self.run(Wall())

        run.toggle(.earlier)
        #expect(Self.ids(run).suffix(3) == [.fold(.earlier), .pick(.session("sr-dash02")), .fold(.projects)])
        run.close()
        _ = run.open()
        #expect(!Self.ids(run).contains(.pick(.session("sr-dash02"))))
    }

    /// Its last row starting a turn, the line goes, and closes: a row passing the period later shows it folded.
    @Test func nEarlierFoldsAsItsLineGoes() {
        let run = Self.run(Wall())

        run.toggle(.earlier)
        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(!Self.ids(run).contains(.fold(.earlier)))
        #expect(!run.folds.isEarlierOpen)
    }
}
