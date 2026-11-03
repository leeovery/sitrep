import Foundation
@testable import SitRep
import Testing

/// A signal to stop, as `app/quit` sends, quitting as Quit SitRep does.
@MainActor
struct QuitOnSignalTests {
    /// Heard, it quits through the seam, so the welcome's close and `watch`'s stop run as for Quit SitRep. SIGUSR2
    /// stands in for SIGTERM, which, ignored for the source's sake, would leave the tests' runner deaf to its own.
    @Test func aSignalToStopQuitsAsQuitDoes() async {
        var quits = 0
        let quitting = QuitOnSignal(SIGUSR2) { quits += 1 }
        var turns = 0

        kill(getpid(), SIGUSR2)
        while quits == 0, turns < 200 {
            try? await Task.sleep(for: .milliseconds(10))
            turns += 1
        }
        #expect(quits == 1)
        quitting.stop()
    }
}
