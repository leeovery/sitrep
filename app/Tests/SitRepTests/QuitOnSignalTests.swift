import Foundation
@testable import SitRep
import SitRepTestSupport
import Testing

/// A signal to stop, as `app/quit` sends, quitting as Quit SitRep does. SIGUSR2 stands in for SIGTERM, which, ignored
/// for the source's sake, would leave the tests' runner deaf to its own. One at a time, as both set the one signal.
@Suite(.serialized)
@MainActor
struct QuitOnSignalTests {
    /// Ignored, 1; at its default, 0, as `SIG_IGN` and `SIG_DFL` are.
    private static func handler(of number: Int32) -> Int {
        var now = sigaction()

        sigaction(number, nil, &now)
        return unsafeBitCast(now.__sigaction_u.__sa_handler, to: Int.self)
    }

    /// Heard, it quits through the seam, so the welcome's close and `watch`'s stop run as for Quit SitRep; the signal's
    /// default is back at once, so a second one ends SitRep, and, its three seconds' grace over, SitRep is ended in any
    /// case, and not before.
    @Test func aSignalToStopQuitsAsQuitDoesAndEndsItAfterItsGrace() async {
        let clock = TestClock(passing: [])
        let quits = Quits()
        let ends = Ends()
        let quitting = QuitOnSignal(SIGUSR2) { quits.count += 1 } end: { ends.add($0) } sleep: {
            try await clock.sleep(for: $0)
        }

        defer { quitting.stop() }
        #expect(Self.handler(of: SIGUSR2) == 1)
        kill(getpid(), SIGUSR2)
        // the grace begins off the main actor once the quit is sent to it: one waited on in time, the other in turns
        await until(within: .seconds(10)) { clock.sleeps == [.seconds(3)] }
        await until(turns: 100) { quits.count == 1 }
        #expect(Self.handler(of: SIGUSR2) == 0)
        #expect(ends.all.isEmpty)
        clock.pass(.seconds(3))
        await until(within: .seconds(10)) { !ends.all.isEmpty }
        #expect(quits.count == 1)
        #expect(ends.all == [SIGUSR2])
    }

    /// Stopped, as a test stops it, it leaves the signal at its default, never ignored.
    @Test func stoppedItLeavesTheSignalAtItsDefault() {
        let quitting = QuitOnSignal(SIGUSR2) {} end: { _ in }

        #expect(Self.handler(of: SIGUSR2) == 1)
        quitting.stop()
        #expect(Self.handler(of: SIGUSR2) == 0)
    }

    @MainActor
    private final class Quits {
        var count = 0
    }

    /// The signals `end` was given, from the queue it runs on.
    private final class Ends: @unchecked Sendable {
        private let lock = NSLock()
        private var ended: [Int32] = []

        var all: [Int32] { lock.withLock { ended } }

        func add(_ number: Int32) {
            lock.withLock { ended.append(number) }
        }
    }
}
