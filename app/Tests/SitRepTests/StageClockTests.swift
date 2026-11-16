import AppKit
@testable import SitRep
import SitRepTestSupport
import Testing

/// The welcome's stage on the display's clock, as the app runs it: a wake it sets comes on the main run loop, and one
/// called off never does.
@MainActor
struct StageClockTests {
    @Test func aWakeComesOnTheMainRunLoop() async {
        let woken = Woken()
        let wake = DisplayClock().wake(in: 10) { woken.count += 1 }

        defer { wake.invalidate() }
        await until(within: .seconds(20)) { woken.count == 1 }
    }

    @Test func aWakeCalledOffNeverComes() async {
        let woken = Woken(), later = Woken()
        let clock = DisplayClock()

        clock.wake(in: 10) { woken.count += 1 }.invalidate()

        let wake = clock.wake(in: 20) { later.count += 1 }

        defer { wake.invalidate() }
        await until(within: .seconds(20)) { later.count == 1 }
        #expect(woken.count == 0)
    }

    @MainActor
    private final class Woken {
        var count = 0
    }
}
