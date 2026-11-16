import Dispatch
import SitRepTestSupport
import Testing

/// The bounded waits' time, slept out on the caller's actor: stretched by a busy actor, and ended all the same on the
/// clock at ten times the limit.
@Suite(.backstop)
struct UntilTests {
    /// Runs each job a fifth of a second after it comes, as a hot actor, never blocked, comes back to a waiter late.
    private final class LateExecutor: SerialExecutor {
        private let queue = DispatchQueue(label: "late")

        func enqueue(_ job: consuming ExecutorJob) {
            let job = UnownedJob(job)

            queue.asyncAfter(deadline: .now() + 0.2) {
                job.runSynchronously(on: self.asUnownedSerialExecutor())
            }
        }
    }

    private actor Late {
        private let executor = LateExecutor()

        nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }
    }

    /// A tenth of a second, twenty ticks, would take four seconds on an actor that comes back to each a fifth of a
    /// second late; it ends at its ceiling, one second on the clock, and says both times.
    @Test func aWaitOnAHotActorEndsAtTenTimesItsLimitOnTheClock() async throws {
        let late = Late()
        let clock = ContinuousClock()
        let start = clock.now

        try await withKnownIssue {
            try await until(within: .milliseconds(100), "for what never comes", isolation: late) { false }
        } matching: { issue in
            issue.comments.contains { $0.rawValue.hasPrefix("The wait for what never comes ran out of time: 0.1 s slept out, ") }
        }

        let took = clock.now - start

        #expect(took >= .seconds(1))
        #expect(took < .seconds(3))
    }
}
