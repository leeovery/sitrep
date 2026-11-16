import Dispatch
import os
@testable import SitRepTestSupport
import Testing

/// The bounded waits' time, slept out on the caller's actor in naps that grow: stretched by a busy actor, and a few of
/// its turns a second.
@Suite(.backstop)
struct UntilTests {
    /// Runs each job on a queue of its own the delay given after it comes, and counts them: with a delay, a hot actor,
    /// never blocked, that comes back to a waiter late.
    private final class CountingExecutor: SerialExecutor {
        private let queue = DispatchQueue(label: "until")
        private let delay: Double
        private let count = OSAllocatedUnfairLock(initialState: 0)

        init(delay: Double) {
            self.delay = delay
        }

        var jobs: Int { count.withLock { $0 } }

        func enqueue(_ job: consuming ExecutorJob) {
            let job = UnownedJob(job)

            count.withLock { $0 += 1 }
            queue.asyncAfter(deadline: .now() + delay) {
                job.runSynchronously(on: self.asUnownedSerialExecutor())
            }
        }
    }

    private actor Waiter {
        let executor: CountingExecutor

        init(delay: Double = 0) {
            executor = CountingExecutor(delay: delay)
        }

        nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }
    }

    /// Whether the issue says, as its first words, those given.
    private static func says(_ words: String, _ issue: Issue) -> Bool {
        issue.comments.contains { $0.rawValue.hasPrefix(words) }
    }

    /// A tenth of a second is seven naps, which on an actor that comes back to each a fifth of a second late take over a
    /// second on the clock: the time is the actor's, so the wait still ends slept out.
    @Test func aWaitOnAHotActorIsStretchedByIt() async throws {
        let late = Waiter(delay: 0.2)
        let clock = ContinuousClock()
        let start = clock.now

        try await withKnownIssue {
            try await until(within: .milliseconds(100), "for what never comes", isolation: late) { false }
        } matching: {
            Self.says("The wait for what never comes ran out of time: 0.1 s slept out, ", $0)
        }

        #expect(clock.now - start >= .seconds(1))
    }

    /// A second's wait takes its actor sixteen turns, not two hundred: naps from a millisecond, each twice the last, to
    /// a tenth of a second.
    @Test func aLongWaitTakesItsActorAFewTurnsASecond() async throws {
        let waiter = Waiter()

        try await withKnownIssue {
            try await until(within: .seconds(1), "for what never comes", isolation: waiter) { false }
        } matching: {
            Self.says("The wait for what never comes ran out of time: 1.0 s slept out, ", $0)
        }

        #expect(waiter.executor.jobs <= 20)
        #expect(longestNap == .milliseconds(100))
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

    /// Each end of a wait in words of its own: whether its time was slept out, or its task cancelled.
    @Test func eachEndOfAWaitSaysWhichItWas() {
        let words = [Slept.End.sleptOut, .cancelled].map { end in
            Slept(limit: .milliseconds(100), end: end, took: .milliseconds(1_040)).ranOut("for the line", nil).rawValue
        }

        #expect(words == [
            "The wait for the line ran out of time: 0.1 s slept out, 1.0 s on the clock.",
            "The wait for the line was cancelled: 1.0 s on the clock.",
        ])
    }
}
