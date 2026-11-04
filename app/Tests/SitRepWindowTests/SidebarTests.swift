import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// The sidebar as the window runs it, over the first line the real `watch` printed: the four places with the board's
/// counts, whatever the filter holds, then every project, marked and counted; and where the window was left, kept
/// across launches.
struct SidebarTests {
    @Test func thePlacesCountTheWholeBoardWhateverTheFilterHolds() {
        let run = opened()

        run.filter = Filter("ledg")
        #expect(Place.allCases.map(run.places.count(of:)) == [6, 1, 0, 1])
        #expect(run.places.projects.isEmpty)
    }

    /// Every project, quiet ones too, in `watch`'s order: SitRep's and Switchboard's lines waiting the dot, Goosemates'
    /// away ask the ring, Kit's away session alone the grey dot, quiet, its count hidden.
    @Test func everyProjectIsListedMarkedAndCounted() {
        let projects = opened().places.projects

        #expect(projects.map(\.id) == ["sitrep", "switchboard", "goosemates", "kit"])
        #expect(projects.map(\.mark) == [.needs, .needs, .awayAsk, .nothingWaiting])
        #expect(projects.map(\.count) == [1, 2, 1, nil])
    }

    /// Before the window opens, and while it is closed, the sidebar shows where it was left.
    @Test func closedItsRootIsWhereItWasLeft() {
        #expect(WindowRun(remembered: .session("sr-rq7dgr", from: .project("switchboard"))).location.root
            == .project("switchboard"))
        #expect(WindowRun().location.root == .place(.needsYou))
    }
}

/// Where the window was left, kept under "windowLocation" across launches; the session picked last, kept under
/// "windowLastSession" until the window's places, read once as its page.
struct WhereLeftTests {
    @Test func whereItWasLeftIsReadBackItsPickWithoutWhereItStood() throws {
        let defaults = MemoryDefaults()
        let listed = Listed(heard(line(0)))
        let selection = try #require(PlaceList(.needsYou, in: listed).selection(of: macAppK1))

        WhereLeft.save(.place(.needsYou, picked: selection), in: defaults)
        #expect(WhereLeft.read(defaults) == .place(.needsYou, picked: selection))
    }

    @Test func nothingSavedIsNowhere() {
        #expect(WhereLeft.read(MemoryDefaults()) == nil)
    }

    @Test func whatItCannotReadIsNowhere() {
        let defaults = MemoryDefaults()

        defaults.set(Data("{\"location\":{\"elsewhere\":{}}}".utf8), forKey: WhereLeft.key)
        #expect(WhereLeft.read(defaults) == nil)
    }

    /// The old key read once: as the session's page, saved under the new key, and gone.
    @Test func theSessionPickedLastIsReadOnceAsItsPage() {
        let defaults = MemoryDefaults()

        defaults.set("sr-rq7dgr", forKey: "windowLastSession")
        #expect(WhereLeft.read(defaults) == .session("sr-rq7dgr", from: .place(.needsYou)))
        #expect(defaults.object(forKey: "windowLastSession") == nil)
        #expect(WhereLeft.read(defaults) == .session("sr-rq7dgr", from: .place(.needsYou)))
    }

    /// A value under the new key wins, the old one left unread.
    @Test func aValueSavedWinsOverTheOldKey() {
        let defaults = MemoryDefaults()

        WhereLeft.save(.project("kit"), in: defaults)
        defaults.set("sr-rq7dgr", forKey: "windowLastSession")
        #expect(WhereLeft.read(defaults) == .project("kit"))
    }
}
