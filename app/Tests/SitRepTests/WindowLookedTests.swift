import Foundation
@testable import SitRep
import SitRepLines
import SitRepWindow
import Testing

/// When Lee last looked at each session, saved in the app's defaults by the window's model as a session's page stops
/// showing: as the window closes, and as the app quits, which tells the window no close.
@MainActor
struct WindowLookedTests {
    @Test(arguments: [false, true])
    func itIsSavedAsTheWindowClosesOrTheAppQuits(quits: Bool) throws {
        let defaults = MemoryDefaults()
        let model = try WindowModel.made(defaults: defaults)

        model.show(HostedSidebar.heard(Lines.watch[0]))
        model.opened(landing: "sr-macapp")
        model.window(isVisible: true)
        #expect(LastLooked.read(defaults) == LastLooked())
        if quits {
            model.quitting()
        } else {
            model.closed()
        }
        #expect(LastLooked.read(defaults).sessions.keys.sorted() == ["sr-macapp"])
    }
}
