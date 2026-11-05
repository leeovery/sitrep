import Foundation
@testable import SitRep
import SitRepLines
import SitRepWindow
import Testing

/// When Lee last looked at each session, saved in the app's defaults by the window's model as a session's page stops
/// showing after he read it: as the window closes, and as the app quits, which tells the window no close.
@MainActor
struct WindowLookedTests {
    /// A wall clock the test moves.
    private final class Clock {
        var now = Date()
    }

    /// The Mac app's page read for a minute, its board carried, then the window closed or the app quitting.
    @Test(arguments: [false, true])
    func itIsSavedAsTheWindowClosesOrTheAppQuits(quits: Bool) throws {
        let defaults = MemoryDefaults()
        let clock = Clock()
        let model = try WindowModel.made(defaults: defaults, wall: { clock.now })

        model.show(HostedSidebar.heard(Lines.watch[0]))
        model.opened(landing: "sr-macapp")
        model.window(isVisible: true)
        model.show(HostedSidebar.heard(Lines.carrying(["sr-macapp": Lines.board], on: Lines.watch[0])))
        clock.now = clock.now.addingTimeInterval(60)
        #expect(LastLooked.read(defaults) == LastLooked())
        if quits {
            model.quitting()
        } else {
            model.closed()
        }
        #expect(LastLooked.read(defaults) == LastLooked(["sr-macapp": clock.now]))
    }
}
