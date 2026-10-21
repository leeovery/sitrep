import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// Settings as a page of the window, picked at the sidebar's foot or by ⌘,: nothing on the board is picked while it
/// shows, it reads no session, and it stays until Lee picks something on the board.
struct SettingsPickTests {
    @Test func pickingSettingsShowsItAndReadsNothing() {
        let run = opened()

        #expect(run.pick(.settings).isEmpty)
        #expect(run.pick == .settings)
        #expect(run.page(at: printedAt) == .settings)
    }

    @Test func whileSettingsShowsNothingOnTheBoardIsPicked() {
        let run = opened()

        _ = run.pick(.settings)
        #expect(run.spot == nil)
        _ = run.pick(.project("switchboard"))
        #expect(run.spot == .board(.project("switchboard")))
    }

    @Test func aClickOnASessionLeavesSettingsForIt() {
        let run = opened()

        _ = run.pick(.settings)
        #expect(run.pickInList(.board(.session("sr-dash02")), at: printedAt).map(\.session) == ["sr-dash02"])
        #expect(run.page(at: printedAt).session?.id == "sr-dash02")
    }

    @Test func aBoardUpdateLeavesSettingsShowingAndReadsNothing() {
        let run = opened()

        _ = run.pick(.settings)
        #expect(run.show(heard(line(0), line(new: ["ask:sr-dash02:k1"], changed: ["sr-macapp"])), at: printedAt, reducesMotion: false).isEmpty)
        #expect(run.pick == .settings)
        #expect(run.page(at: printedAt) == .settings)
    }

    /// ⌘, with the window closed: it opens straight on Settings, reading nothing of the session it would open on.
    @Test func theWindowOpensOnSettingsWhenAskedTo() {
        let run = WindowRun()

        _ = run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        #expect(run.open(on: .settings).isEmpty)
        #expect(run.page(at: printedAt) == .settings)
    }

    @Test func settingsShowsBeforeTheFirstBoard() {
        let run = WindowRun()

        _ = run.open(on: .settings)
        #expect(run.page(at: printedAt) == .settings)
    }

    @Test func backFromTheDockItIsStillOnSettings() {
        let run = opened()

        _ = run.pick(.settings)
        run.minimise()
        #expect(run.restore().isEmpty)
        #expect(run.pick == .settings)
    }

    /// The window opens on the session picked last when nothing needs Lee, so Settings never takes its place.
    @Test func settingsIsNeverTheSessionPickedLast() {
        let run = opened()

        _ = run.pick(.session("sr-rq7dgr"))
        _ = run.pick(.settings)
        #expect(run.lastSession == "sr-rq7dgr")
    }

    @Test func closedAndOpenedAgainItOpensOnWhatItOpensOnNotSettings() {
        let run = opened()

        _ = run.pick(.settings)
        run.close()
        _ = run.open()
        #expect(run.pick == .session("sr-macapp"))
    }
}
