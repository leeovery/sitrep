import os
@testable import SitRepCore
import Testing

/// One jump at a time, the latest click winning: a jump asked for while one runs stops it and runs; a jump with no
/// answer two seconds on says it is still jumping, on a clock the test moves.
@MainActor
struct OneJumpTests {
    @Test func aJumpTellsHowItEnded() async {
        let (oneJump, _) = Self.made()
        let jumps = Jumps(), heard = Heard()

        oneJump.run(jumps.jump(1), told: heard.add)
        await Self.until { jumps.started == [1] }
        jumps.answer(1, .refused("Fumi is not on screen."))
        await Self.until { !heard.news.isEmpty }

        #expect(heard.news == [.ended(.refused("Fumi is not on screen."))])
    }

    @Test func aJumpWithNoAnswerTwoSecondsOnSaysItIsStillJumpingThenHowItEnded() async {
        let (oneJump, clock) = Self.made()
        let jumps = Jumps(), heard = Heard()

        oneJump.run(jumps.jump(1), told: heard.add)
        await Self.until { clock.asked.count == 1 }
        #expect(clock.asked == [.seconds(2)])
        #expect(heard.news.isEmpty)

        clock.pass()
        await Self.until { !heard.news.isEmpty }
        #expect(heard.news == [.still])

        jumps.answer(1, .unanswered)
        await Self.until { heard.news.count == 2 }
        #expect(heard.news == [.still, .ended(.unanswered)])
    }

    @Test func aJumpAnsweringWithinTwoSecondsNeverSaysItIsStillJumping() async {
        let (oneJump, clock) = Self.made()
        let jumps = Jumps(), heard = Heard()

        oneJump.run(jumps.jump(1), told: heard.add)
        await Self.until { jumps.started == [1] && clock.asked.count == 1 }
        jumps.answer(1, .jumped)
        await Self.until { !heard.news.isEmpty }

        clock.pass()
        await Self.settle()
        #expect(heard.news == [.ended(.jumped)])
    }

    /// The first is stopped, its CLI killed as its task is cancelled, and ends stopped whatever its CLI answers after,
    /// with no word of still jumping; the second runs, and alone says it is still jumping.
    @Test func aSecondJumpStopsTheFirstAndRunsInItsPlace() async {
        let (oneJump, clock) = Self.made()
        let jumps = Jumps(), first = Heard(), second = Heard()

        oneJump.run(jumps.jump(1), told: first.add)
        await Self.until { jumps.started == [1] && clock.asked.count == 1 }

        oneJump.run(jumps.jump(2), told: second.add)
        await Self.until { jumps.started == [1, 2] && !first.news.isEmpty }
        #expect(jumps.stopped == [1])
        #expect(first.news == [.ended(.stopped)])

        jumps.answer(1, .jumped)
        clock.pass()
        await Self.until { !second.news.isEmpty }
        #expect(first.news == [.ended(.stopped)])
        #expect(second.news == [.still])

        jumps.answer(2, .jumped)
        await Self.until { second.news.count == 2 }
        #expect(second.news == [.still, .ended(.jumped)])
        #expect(jumps.stopped == [1])
    }

    /// A CLI that answers stopped, its run killed, ends the jump stopped, which no surface tells as a failure.
    @Test func aJumpWhoseCLIIsStoppedEndsStopped() async {
        let (oneJump, _) = Self.made()
        let jumps = Jumps(), heard = Heard()

        oneJump.run(jumps.jump(1), told: heard.add)
        await Self.until { jumps.started == [1] }
        jumps.answer(1, .stopped)
        await Self.until { !heard.news.isEmpty }

        #expect(heard.news == [.ended(.stopped)])
    }

    private static func made() -> (OneJump, TestClock) {
        let clock = TestClock()

        return (OneJump(sleep: { await clock.sleep($0) }), clock)
    }

    /// Lets the jumps' tasks run until the test's condition holds, or long enough that it never will.
    private static func until(_ holds: () -> Bool) async {
        for _ in 0 ..< 100_000 where !holds() {
            await Task.yield()
        }
    }

    /// Lets every task run that would.
    private static func settle() async {
        for _ in 0 ..< 1000 {
            await Task.yield()
        }
    }
}

/// What a jump told, in order.
@MainActor
private final class Heard {
    private(set) var news: [JumpNews] = []

    func add(_ news: JumpNews) {
        self.news.append(news)
    }
}

/// A clock the test moves: each sleep asked of it waits until the test passes the time.
private final class TestClock: Sendable {
    private struct State {
        var asked: [Duration] = []
        var waiting: [CheckedContinuation<Void, Never>] = []
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var asked: [Duration] { state.withLock(\.asked) }

    func sleep(_ duration: Duration) async {
        await withCheckedContinuation { waiting in
            state.withLock { state in
                state.asked.append(duration)
                state.waiting.append(waiting)
            }
        }
    }

    /// Every sleep under way ends.
    func pass() {
        state.withLock { state in
            defer { state.waiting = [] }
            return state.waiting
        }.forEach { $0.resume() }
    }
}

/// Jumps the test answers, each by its number: one waits until answered, or until its task is cancelled, when it
/// answers stopped, as the CLI killed then does.
private final class Jumps: Sendable {
    private struct State {
        var started: [Int] = []
        var stopped: [Int] = []
        var waiting: [Int: CheckedContinuation<JumpAnswer, Never>] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    var started: [Int] { state.withLock(\.started) }
    var stopped: [Int] { state.withLock(\.stopped) }

    func jump(_ number: Int) -> @Sendable () async -> JumpAnswer {
        { [self] in
            await withTaskCancellationHandler {
                await withCheckedContinuation { waiting in
                    let isStopped = state.withLock { state in
                        state.started.append(number)
                        state.waiting[number] = waiting
                        return state.stopped.contains(number)
                    }

                    if isStopped {
                        answer(number, .stopped)
                    }
                }
            } onCancel: {
                state.withLock { $0.stopped.append(number) }
                answer(number, .stopped)
            }
        }
    }

    /// The jump answers, if it still waits.
    func answer(_ number: Int, _ answer: JumpAnswer) {
        state.withLock { $0.waiting.removeValue(forKey: number) }?.resume(returning: answer)
    }
}
