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
        let graces = Graces()
        let quits = Quits()
        let ends = Ends()
        let quitting = QuitOnSignal(SIGUSR2) { quits.count += 1 } end: { ends.add($0) } after: { graces.add($0, $1) }

        defer { quitting.stop() }
        #expect(Self.handler(of: SIGUSR2) == 1)
        kill(getpid(), SIGUSR2)
        // The signal is heard on another thread, which sends the quit to the main actor and then sets the grace. So
        // wait for the grace by the clock, then give the main actor turns to run the quit.
        await until(within: .seconds(10)) { graces.waits == [.seconds(3)] }
        await until(turns: 100) { quits.count == 1 }
        #expect(Self.handler(of: SIGUSR2) == 0)
        #expect(ends.all.isEmpty)
        graces.pass()
        #expect(quits.count == 1)
        #expect(ends.all == [SIGUSR2])
    }

    /// Its grace runs off the main thread, so it ends a SitRep whose main thread never answers: here the main thread is
    /// held from the signal until SitRep is ended, so the quit sent to it never runs.
    @Test func theGraceEndsItWhileTheMainThreadIsStuck() {
        let ended = DispatchSemaphore(value: 0)
        let quits = Quits()
        let quitting = QuitOnSignal(SIGUSR2, grace: .milliseconds(20)) { quits.count += 1 } end: { _ in ended.signal() }

        defer { quitting.stop() }
        kill(getpid(), SIGUSR2)
        #expect(ended.wait(timeout: .now() + 10) == .success)
        #expect(quits.count == 0)
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

    /// The graces set, each ended only as the test passes them.
    private final class Graces: @unchecked Sendable {
        private let lock = NSLock()
        private var set: [(wait: Duration, then: @Sendable () -> Void)] = []

        var waits: [Duration] { lock.withLock { set.map(\.wait) } }

        func add(_ wait: Duration, _ then: @escaping @Sendable () -> Void) {
            lock.withLock { set.append((wait, then)) }
        }

        /// Every grace set passes, and what it waited to do is done.
        func pass() {
            let passing = lock.withLock {
                defer { set = [] }
                return set
            }

            passing.forEach { $0.then() }
        }
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
