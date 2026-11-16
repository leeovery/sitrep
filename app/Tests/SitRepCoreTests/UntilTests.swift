import Dispatch
@testable import SitRepTestSupport
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

    /// Whether the issue says, as its first words, those given.
    private static func says(_ words: String, _ issue: Issue) -> Bool {
        issue.comments.contains { $0.rawValue.hasPrefix(words) }
    }

    /// A tenth of a second, twenty ticks, would take four seconds on an actor that comes back to each a fifth of a
    /// second late; it ends at its ceiling, one second on the clock, and says so.
    @Test func aWaitOnAHotActorEndsAtTenTimesItsLimitOnTheClock() async throws {
        let late = Late()
        let clock = ContinuousClock()
        let start = clock.now

        try await withKnownIssue {
            try await until(within: .milliseconds(100), "for what never comes", isolation: late) { false }
        } matching: {
            Self.says("The wait for what never comes reached its ceiling: ", $0)
        }

        let took = clock.now - start

        #expect(took >= .seconds(1))
        #expect(took < .seconds(3))
    }

    /// Its task cancelled, the wait ends at once, and says so.
    @Test func aWaitWhoseTaskIsCancelledSaysSo() async throws {
        let waiting = Task {
            try await withKnownIssue {
                try await until(within: .seconds(10), "for what never comes") { false }
            } matching: {
                Self.says("The wait for what never comes was cancelled: ", $0)
            }
        }

        waiting.cancel()
        try await result(of: waiting, within: .seconds(10)).get()
    }

    /// Each end of a wait in words of its own: whether its time was slept out, met its ceiling first, or was cancelled.
    @Test func eachEndOfAWaitSaysWhichItWas() {
        let words = [Slept.End.sleptOut, .ceiling, .cancelled].map { end in
            Slept(limit: .milliseconds(100), end: end, took: .milliseconds(1_040)).ranOut("for the line", nil).rawValue
        }

        #expect(words == [
            "The wait for the line ran out of time: 0.1 s slept out, 1.0 s on the clock.",
            "The wait for the line reached its ceiling: 1.0 s on the clock, ten times its 0.1 s, not yet slept out.",
            "The wait for the line was cancelled: 1.0 s on the clock.",
        ])
    }
}
