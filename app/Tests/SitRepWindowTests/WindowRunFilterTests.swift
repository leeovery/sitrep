import Foundation
import enum SitRepPanel.FoldPeriod
import struct SitRepPanel.Earlier
@testable import SitRepWindow
import Testing

/// The sidebar's filter as the window runs it: it narrows the list beside the page and the projects, never the
/// places' counts, Return opens the first match, and it never moves where the window is.
struct WindowRunFilterTests {
    @Test func theFilterNarrowsTheListAndTheProjectsAndClearedGivesTheWholeBoardBack() throws {
        let run = opened()

        run.filter = Filter("dash")
        #expect(run.list(at: printedAt)?.picks == [needsYouLines[0], needsYouLines[2]])
        #expect(run.places.projects.isEmpty)
        #expect(run.places.count(of: .needsYou) == 6)
        run.filter = Filter()
        #expect(run.list(at: printedAt)?.picks == needsYouLines)
        #expect(run.places.projects.count == 4)
    }

    @Test func filteringNeverMovesThePickEvenWithThePickedLineFilteredOut() {
        let run = opened()
        let page = run.page(at: printedAt)

        run.filter = Filter("ledg")
        #expect(run.location.picked?.pick == macAppK1)
        #expect(run.list(at: printedAt)?.row(macAppK1) == nil)
        #expect(run.page(at: printedAt) == page)
    }

    /// The list's first match picked, a step replaced; with none in the list, the first project that matches opened.
    @Test func returnOpensTheFirstMatchInTheListElseTheFirstProject() {
        let run = opened()

        run.filter = Filter("goose")
        run.openFirstMatch()
        #expect(run.location.picked?.pick == .line("ask:sr-gs7kq2:k1"))
        #expect(run.following == ["sr-gs7kq2"])
        run.filter = Filter("kit")
        run.openFirstMatch()
        #expect(run.location == .project("kit"))
        #expect(run.following == ["sr-k7t001"])
    }

    @Test(arguments: ["", "zzz"])
    func returnWithNoFilterOrNoMatchOpensNothing(_ typed: String) {
        let run = opened()
        let location = run.location

        run.filter = Filter(typed)
        run.openFirstMatch()
        #expect(run.location == location)
    }

    /// What the filter holds is not kept: reopened, the window lists the whole board.
    @Test func closingTheWindowClearsTheFilter() {
        let run = opened()

        run.filter = Filter("ledg")
        run.close()
        #expect(run.filter.isEmpty)
        run.open()
        #expect(run.list(at: printedAt)?.picks == needsYouLines)
    }

    @Test func minimisingTheWindowKeepsTheFilter() {
        let run = opened()

        run.filter = Filter("ledg")
        run.minimise()
        run.restore()
        #expect(run.filter == Filter("ledg"))
    }
}

/// Your turn's rows fold into "N earlier" as they pass the fold period, by the wall clock, and refold as time passes
/// and as the period changes, nothing polling: the next row to pass it is the window's next change. The fold opens in
/// place, shows open while the filter holds text, and is never kept.
struct WindowRunPeriodTests {
    /// The wall clock, moved on by the test.
    private final class Wall {
        var now = printedAt
    }

    private static func ids(_ run: WindowRun) -> [PlaceList.Item.ID] {
        run.list(at: printedAt)?.items.map(\.id) ?? []
    }

    /// On Your turn: the Mac app's and Dashboard redesign's turns ended 30 and 90 minutes before the board was seeded,
    /// Request ledger's 12: Dashboard redesign's is past the hour.
    private static func run(_ wall: Wall, period: FoldPeriod = .hour) -> WindowRun {
        let run = WindowRun(period: period, wall: { wall.now })

        run.show(heard(turned(["sr-macapp": 30, "sr-dash02": 90])), at: printedAt, reducesMotion: false)
        run.open()
        run.click(.place(.yourTurn))
        return run
    }

    @Test func aRowPastThePeriodFoldsIntoNEarlierTheRestShowing() throws {
        let run = Self.run(Wall())
        let fold = try #require(run.list(at: printedAt)?.fold)

        #expect(Self.ids(run) == [.pick(.session("sr-rq7dgr")), .pick(.session("sr-macapp")), .fold(.earlier)])
        #expect(fold.earlier == Earlier(projects: ["Switchboard"], isOpen: false))
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
        #expect(run.list(at: printedAt)?.fold?.earlier == Earlier(projects: ["SitRep", "Switchboard"], isOpen: false))
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

        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        run.open()
        run.click(.place(.yourTurn))
        wall.now = midnight.addingTimeInterval(24 * 3600 - 1)
        #expect(!Self.ids(run).contains(.fold(.earlier)))
        wall.now = midnight.addingTimeInterval(24 * 3600)
        #expect(Self.ids(run).contains(.fold(.earlier)))
    }

    @Test func nEarlierOpensInPlaceAndFoldsAgainEachTimeTheWindowOpens() {
        let run = Self.run(Wall())

        run.toggleFold(of: .yourTurn)
        #expect(Self.ids(run).suffix(2) == [.fold(.earlier), .pick(.session("sr-dash02"))])
        run.close()
        run.open()
        #expect(!Self.ids(run).contains(.pick(.session("sr-dash02"))))
    }

    /// Its last row starting a turn, the line goes, and closes: a row passing the period later shows it folded.
    @Test func nEarlierFoldsAsItsLineGoes() {
        let wall = Wall()
        let run = Self.run(wall)

        run.toggleFold(of: .yourTurn)
        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(!Self.ids(run).contains(.fold(.earlier)))
        wall.now = printedAt.addingTimeInterval(3600)
        #expect(Self.ids(run) == [.fold(.earlier)])
    }

    /// An hour on, Request ledger's turn has passed the fold period; typing its name shows it under "N earlier", open,
    /// which folds again as the field clears.
    @Test func whileTheFilterHoldsTextNEarliersMatchingRowsShow() {
        let wall = Wall()
        let run = Self.run(wall)

        wall.now = printedAt.addingTimeInterval(3600)
        run.filter = Filter("ledg")
        #expect(Self.ids(run) == [.fold(.earlier), .pick(.session("sr-rq7dgr"))])
        run.filter = Filter()
        #expect(!Self.ids(run).contains(.pick(.session("sr-rq7dgr"))))
    }

    /// A row picked while the filter shows it under "N earlier" shows still as the field clears: the fold opens.
    @Test func aPickUnderNEarlierMadeWhileFilteringShowsAsTheFilterClears() {
        let wall = Wall()
        let run = Self.run(wall)

        run.filter = Filter("dash")
        run.openFirstMatch()
        #expect(run.location.picked?.pick == .session("sr-dash02"))
        run.filter = Filter()
        #expect(Self.ids(run).suffix(2) == [.fold(.earlier), .pick(.session("sr-dash02"))])
    }
}
