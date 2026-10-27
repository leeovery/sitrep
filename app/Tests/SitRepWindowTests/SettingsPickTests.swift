import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepWindow
import Testing

/// Settings as a page of the window, picked at the sidebar's foot or by ⌘,: nothing on the board is picked while it
/// shows, it follows no session, and it stays until Lee picks something on the board.
struct SettingsPickTests {
    @Test func pickingSettingsShowsItAndFollowsNothing() {
        let run = opened()

        run.pick(.settings)
        #expect(run.following.isEmpty)
        #expect(run.pick == .settings)
        #expect(run.page(at: printedAt) == .settings)
    }

    @Test func whileSettingsShowsNothingOnTheBoardIsPicked() {
        let run = opened()

        run.pick(.settings)
        #expect(!run.sidebar(at: printedAt).lines.contains { $0.pick == .settings })
        run.pick(.project("switchboard"))
        #expect(run.sidebar(at: printedAt).lines.contains { $0.pick == .project("switchboard") })
    }

    @Test func aClickOnASessionLeavesSettingsForIt() {
        let run = opened()

        run.pick(.settings)
        run.pickInList(.session("sr-dash02"), at: printedAt)
        #expect(run.following == ["sr-dash02"])
        #expect(run.page(at: printedAt).session?.id == "sr-dash02")
    }

    @Test func aBoardUpdateLeavesSettingsShowingAndFollowingNothing() {
        let run = opened()

        run.pick(.settings)
        run.show(heard(line(0), line(new: ["ask:sr-dash02:k1"])), at: printedAt, reducesMotion: false)
        #expect(run.following.isEmpty)
        #expect(run.pick == .settings)
        #expect(run.page(at: printedAt) == .settings)
    }

    /// ⌘, with the window closed: it opens straight on Settings, following nothing of the session it would open on.
    @Test func theWindowOpensOnSettingsWhenAskedTo() {
        let run = WindowRun()

        run.show(heard(line(0)), at: printedAt, reducesMotion: false)
        run.open(on: .settings)
        #expect(run.following.isEmpty)
        #expect(run.page(at: printedAt) == .settings)
    }

    @Test func settingsShowsBeforeTheFirstBoard() {
        let run = WindowRun()

        run.open(on: .settings)
        #expect(run.page(at: printedAt) == .settings)
    }

    @Test func backFromTheDockItIsStillOnSettings() {
        let run = opened()

        run.pick(.settings)
        run.minimise()
        run.restore()
        #expect(run.following.isEmpty)
        #expect(run.pick == .settings)
    }

    /// The window opens on the session picked last when nothing needs Lee, so Settings never takes its place.
    @Test func settingsIsNeverTheSessionPickedLast() {
        let run = opened()

        run.pick(.session("sr-rq7dgr"))
        run.pick(.settings)
        #expect(run.lastSession == "sr-rq7dgr")
    }

    @Test func closedAndOpenedAgainItOpensOnWhatItOpensOnNotSettings() {
        let run = opened()

        run.pick(.settings)
        run.close()
        run.open()
        #expect(run.pick == .session("sr-macapp"))
    }
}
