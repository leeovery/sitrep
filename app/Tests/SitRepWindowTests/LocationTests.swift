import Foundation
import SitRepLines
@testable import SitRepWindow
import Testing

/// Where the window is: a place and its selection, a project's page, or a session's pushed from a root; where it
/// opens, where an open from outside lands, and what it follows.
struct LocationTests {
    /// SitRep's three asks (k2 the oldest), Switchboard's ask and stop, Goosemates' away ask; Request ledger on Lee's
    /// turn; Kit's away session with nothing.
    private static let listed = Listed(heard(line(0)))
    /// As `listed`, Goosemates' session finished, and its project gone with it.
    private static let finished = Listed(heard(line(3)))

    private static let macapp = Selection(pick: .line("ask:sr-macapp:k2"), session: "sr-macapp")
    private static let goose = Selection(pick: .line("ask:sr-gs7kq2:k1"), session: "sr-gs7kq2")

    // MARK: What it is

    /// A session pushed from Switchboard leaves Switchboard picked in the sidebar, and shows no list.
    @Test func aSessionPushedFromAProjectLeavesTheProjectPicked() {
        let pushed = Location.session("sr-dash02", from: .project("switchboard"))

        #expect(pushed.root == .project("switchboard"))
        #expect(pushed.place == nil)
        #expect(pushed.picked == nil)
        #expect(Location.project("kit").root == .project("kit"))
        #expect(Location.place(.parked, scope: .project("kit")).root == .place(.parked))
    }

    @Test func aPlaceHasItsListAndWhatTheListPicked() {
        let place = Location.place(.needsYou, picked: Self.macapp)

        #expect(place.place == .needsYou)
        #expect(place.picked == Self.macapp)
        #expect(place.root == .place(.needsYou))
    }

    /// Picking within the list changes only the selection, Parked's scope kept; a page with no list stays.
    @Test func pickingWithinTheListChangesOnlyTheSelection() {
        let parked = Selection(pick: .parked(session: "sr-macapp", id: "p1"), session: "sr-macapp")

        #expect(Location.place(.needsYou).picking(Self.macapp) == .place(.needsYou, picked: Self.macapp))
        #expect(Location.place(.parked, scope: .project("sitrep")).picking(parked)
            == .place(.parked, picked: parked, scope: .project("sitrep")))
        #expect(Location.project("kit").picking(Self.macapp) == .project("kit"))
    }

    // MARK: What it follows

    @Test func itFollowsThePickedRowsSessionEveryOneOfAProjectOrTheSessionPushed() {
        let row = Selection(pick: .session("sr-rq7dgr"), session: "sr-rq7dgr")
        let parked = Selection(pick: .parked(session: "sr-dash02", id: "p1"), session: "sr-dash02")

        #expect(Location.place(.needsYou, picked: Self.macapp).following(on: Self.listed) == ["sr-macapp"])
        #expect(Location.place(.yourTurn, picked: row).following(on: Self.listed) == ["sr-rq7dgr"])
        #expect(Location.place(.parked, picked: parked).following(on: Self.listed) == ["sr-dash02"])
        #expect(Location.place(.working).following(on: Self.listed).isEmpty)
        #expect(Location.project("switchboard").following(on: Self.listed) == ["sr-dash02", "sr-rq7dgr"])
        #expect(Location.session("sr-k7t001", from: .project("kit")).following(on: Self.listed) == ["sr-k7t001"])
    }

    /// The picked line answered, its session on Lee's turn: the location stays, nothing in the list picked, the page
    /// still on its session, which the window still follows.
    @Test func aPickedLineLeavingNeedsYouKeepsTheLocation() throws {
        let location = Location.place(.needsYou, picked: Self.macapp)
        let answered = Listed(heard(answered("sr-macapp")))

        #expect(PlaceList(.needsYou, in: answered).row(Self.macapp.pick) == nil)
        #expect(location.kept(on: answered) == location)
        #expect(try #require(location.kept(on: answered)).following(on: answered) == ["sr-macapp"])
    }

    // MARK: Where it stays

    /// Goosemates' session finished: the place stays, nothing picked.
    @Test func aSelectionWhoseSessionLeftTheBoardDrops() {
        #expect(Location.place(.needsYou, picked: Self.goose).kept(on: Self.finished) == .place(.needsYou))
    }

    @Test func aProjectsPageStandsWhileItsProjectDoes() {
        #expect(Location.project("goosemates").kept(on: Self.listed) == .project("goosemates"))
        #expect(Location.project("goosemates").kept(on: Self.finished) == nil)
    }

    /// A session's page whose session left gives way to where it was pushed from, as that stands.
    @Test func aPushedSessionThatLeftGivesWayToItsRoot() {
        #expect(Location.session("sr-gs7kq2", from: .project("goosemates")).kept(on: Self.listed)
            == .session("sr-gs7kq2", from: .project("goosemates")))
        #expect(Location.session("sr-gs7kq2", from: .place(.parked)).kept(on: Self.finished) == .place(.parked))
        #expect(Location.session("sr-gs7kq2", from: .project("goosemates")).kept(on: Self.finished) == nil)
    }

    @Test func parkedsScopeFallsBackToAllAsItsProjectOrSessionLeaves() {
        #expect(Location.place(.parked, scope: .project("goosemates")).kept(on: Self.finished) == .place(.parked))
        #expect(Location.place(.parked, scope: .session("sr-gs7kq2")).kept(on: Self.finished) == .place(.parked))
        #expect(Location.place(.parked, scope: .project("kit")).kept(on: Self.finished)
            == .place(.parked, scope: .project("kit")))
    }

    // MARK: Where it opens

    /// Needs you's first line, SitRep's oldest ask, whatever was left before.
    @Test func itOpensOnNeedsYousFirstLine() {
        #expect(Location.opening(on: Self.listed, remembered: .project("kit")) == .place(.needsYou, picked: Self.macapp))
    }

    /// With nothing waiting on Lee, where it was left, as that stands on the board; else Needs you, nothing picked.
    @Test func withNothingWaitingItOpensWhereItWasLeft() {
        let quiet = Built.listed([Built(id: "w1", project: "northwind")])

        #expect(Location.opening(on: quiet, remembered: .project("northwind")) == .project("northwind"))
        #expect(Location.opening(on: quiet, remembered: .project("contoso")) == .place(.needsYou))
        #expect(Location.opening(on: quiet, remembered: nil) == .place(.needsYou))
        #expect(Location.opening(on: quiet, remembered: .place(.working, picked: Self.macapp)) == .place(.working))
    }

    // MARK: An open from outside

    /// SitRep's session needs Lee: Needs you, its oldest line, k2, picked; Switchboard's dashboard its ask, older
    /// than its stop.
    @Test func anOpenOfASessionNeedingLeeLandsOnItsOldestLine() {
        #expect(Location.opening(session: "sr-macapp", on: Self.listed) == .place(.needsYou, picked: Self.macapp))
        #expect(Location.opening(session: "sr-dash02", on: Self.listed)
            == .place(.needsYou, picked: Selection(pick: .line("ask:sr-dash02:k1"), session: "sr-dash02")))
        #expect(Location.opening(session: "sr-gs7kq2", on: Self.listed) == .place(.needsYou, picked: Self.goose))
    }

    @Test func anOpenOfAWorkingOrYourTurnSessionLandsOnItsRow() {
        let bySession = Listed(heard(.line(Lines.bySession[0])))

        #expect(Location.opening(session: "sr-macapp", on: bySession)
            == .place(.working, picked: Selection(pick: .session("sr-macapp"), session: "sr-macapp")))
        #expect(Location.opening(session: "sr-rq7dgr", on: Self.listed)
            == .place(.yourTurn, picked: Selection(pick: .session("sr-rq7dgr"), session: "sr-rq7dgr")))
    }

    /// Kit's away session has no row: its project's page, the session pushed over it. So too a session whose only
    /// row is in Snoozed.
    @Test func anOpenOfASessionWithNoRowPushesItOverItsProject() {
        var asleep = Built(id: "a1", project: "contoso", isAway: true)

        asleep.snoozed = [(age: 10, wakesIn: 60)]

        #expect(Location.opening(session: "sr-k7t001", on: Self.listed) == .session("sr-k7t001", from: .project("kit")))
        #expect(Location.opening(session: "a1", on: Built.listed([asleep])) == .session("a1", from: .project("contoso")))
        #expect(Location.opening(session: "sr-gone", on: Self.listed) == nil)
    }

    // MARK: Lee's board

    /// Every session of Lee's board lands by the rule: the 9 needing Lee in Needs you, the 6 working in Working, the
    /// 6 on Lee's turn in Your turn, the 4 away with nothing pushed over their projects. A project's page follows
    /// each of its sessions.
    @Test func onABoardTheSizeOfLeesEverySessionLandsByTheRule() {
        let listed = Built.listed(Built.leesSize)
        let landings = Built.leesSize.compactMap { Location.opening(session: $0.id, on: listed) }
        let landed: [Int] = [Place.needsYou, .working, .yourTurn].map { place in
            landings.filter { $0.place == place }.count
        }

        #expect(landings.count == 25)
        #expect(landed == [9, 6, 6])
        #expect(landings.filter { $0.place == nil }.map(\.root) == ["p17", "p18", "p19", "p20"].map(Root.project))
        #expect(Location.project("p01").following(on: listed) == ["s01", "s02"])
    }
}
