import Foundation
import SitRepLines
@testable import SitRepWindow
import Testing

/// The sidebar under the Filter field: the four places with their counts, then every project, marked and counted.
struct PlacesTests {
    /// SitRep's three asks, Switchboard's ask and stop, Goosemates' away ask; Switchboard's Request ledger on Lee's
    /// turn; Kit's away session with nothing; SitRep's one item parked.
    private static let listed = Listed(heard(line(0)))
    /// Harness's three asks, Switchboard's ask and prompt and Goosemates' away ask; SitRep working, Kit on its own
    /// work; Fumi's turn.
    private static let bySession = Listed(heard(.line(Lines.bySession[0])))

    private static func counts(_ places: Places) -> [Int] {
        Place.allCases.map(places.count(of:))
    }

    @Test func thePlacesAreNeedsYouWorkingYourTurnAndParked() {
        #expect(Place.allCases.map(\.title) == ["Needs you", "Working", "Your turn", "Parked"])
    }

    /// Needs you counts each line waiting, not each session: SitRep's three, Switchboard's two, Goosemates' one.
    @Test func needsYouCountsLinesWorkingAndYourTurnCountRowsParkedCountsItems() {
        #expect(Self.counts(Places(Self.listed)) == [6, 0, 1, 1])
        #expect(Self.counts(Places(Self.bySession)) == [6, 2, 1, 0])
    }

    /// A row past the fold period, under "N earlier", still counts in Your turn.
    @Test func yourTurnCountsItsRowsUnderNEarlierToo() {
        var earlier = Self.listed

        earlier.changeRows { $0.isEarlier = $0.section == .yourTurn }

        #expect(Places(earlier).count(of: .yourTurn) == 1)
    }

    /// Goosemates' only waiting line is of a session no window holds: the away ring. Kit's away session waits on
    /// nothing, opens nothing and parked nothing: quiet, its count hidden.
    @Test func aProjectIsMarkedByWhatWaitsOnLeeInItAndCountsItsCurrentSessions() {
        let projects = Places(Self.listed).projects

        #expect(projects.map(\.id) == ["sitrep", "switchboard", "goosemates", "kit"])
        #expect(projects.map(\.mark) == [.needs, .needs, .awayAsk, .nothingWaiting])
        #expect(projects.map(\.isQuiet) == [false, false, false, true])
        #expect(projects.map(\.count) == [1, 2, 1, nil])
    }

    /// SitRep's, Kit's and Fumi's sessions are open with nothing waiting: the quiet grey dot, but not quiet, their
    /// names bright and their counts shown.
    @Test func aProjectOpenWithNothingWaitingTakesTheGreyDotButIsNotQuiet() {
        let projects = Places(Self.bySession).projects.filter { ["sitrep", "kit", "fumi"].contains($0.id) }

        #expect(projects.map(\.mark) == [.nothingWaiting, .nothingWaiting, .nothingWaiting])
        #expect(projects.map(\.isQuiet) == [false, false, false])
        #expect(projects.map(\.count) == [1, 1, 1])
    }

    /// One line of a session a window holds is enough for the dot, beside any of an away one.
    @Test func aLiveLineOutweighsAwayOnesInAProjectsMark() throws {
        let live = Built(id: "s1", project: "northwind", waiting: [10])
        let away = Built(id: "a1", project: "northwind", isAway: true, waiting: [50])
        let places = Places(Built.listed([away, live]))

        #expect(try #require(places.projects.first).mark == .needs)
    }

    /// Something parked keeps a project from being quiet, with nothing open or waiting.
    @Test func somethingParkedKeepsAProjectFromBeingQuiet() throws {
        let parked = Built(id: "a1", project: "contoso", isAway: true, parked: 2)
        let places = Places(Built.listed([parked]))
        let project = try #require(places.projects.first)

        #expect(project.mark == .nothingWaiting)
        #expect(!project.isQuiet)
        #expect(project.count == 1)
        #expect(places.count(of: .parked) == 2)
    }

    /// An away session whose only asks are asleep keeps its project current, as core does: not quiet, its count
    /// shown, but the grey dot, as nothing waits on Lee now.
    @Test func aProjectWhoseOnlyAsksAreAsleepIsNotQuiet() throws {
        var asleep = Built(id: "a1", project: "contoso", isAway: true)

        asleep.snoozed = [(age: 10, wakesIn: 60)]

        let project = try #require(Places(Built.listed([asleep])).projects.first)

        #expect(project.mark == .nothingWaiting)
        #expect(!project.isQuiet)
        #expect(project.count == 1)
    }

    /// Harness's k3 waits; k1 and k2 asleep count in no place.
    @Test func needsYouCountsNoAsleepLine() {
        #expect(Self.counts(Places(Listed(heard(.line(Lines.snoozed[0]))))) == [1, 0, 0, 0])
    }

    /// The filter narrows the projects to those whose names hold every word, and leaves the counts the board's.
    @Test func theFilterNarrowsTheProjectsButNotTheCounts() {
        let places = Places(Self.listed, filter: Filter("SWITCH"))

        #expect(places.projects.map(\.id) == ["switchboard"])
        #expect(Self.counts(places) == [6, 0, 1, 1])
    }

    @Test func beforeTheFirstLineEveryCountIsNoneAndNoProjectIsListed() {
        let places = Places(Listed())

        #expect(Self.counts(places) == [0, 0, 0, 0])
        #expect(places.projects.isEmpty)
    }

    /// Lee's board: 13 lines of 7 live sessions and 2 away asks, 6 working, 6 on Lee's turn, 100 parked; 20
    /// projects, the 7 with a live line marked, the 2 with only an away ask ringed, and the 3 with nothing open,
    /// waiting or parked quiet.
    @Test func aBoardTheSizeOfLeesCountsAndMarksEveryProject() {
        let places = Places(Built.listed(Built.leesSize))
        let marked = { (mark: ProjectMark) in places.projects.filter { $0.mark == mark }.map(\.id) }

        #expect(Self.counts(places) == [15, 6, 6, 100])
        #expect(places.projects.count == 20)
        #expect(marked(.needs) == ["p01", "p02", "p04", "p05", "p08", "p11", "p14"])
        #expect(marked(.awayAsk) == ["p15", "p16"])
        #expect(places.projects.filter(\.isQuiet).map(\.id) == ["p18", "p19", "p20"])
        #expect(places.projects.prefix(5).map(\.count) == [2, 2, 2, 2, 2])
    }
}
