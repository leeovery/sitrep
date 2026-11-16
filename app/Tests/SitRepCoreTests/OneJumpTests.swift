import os
@testable import SitRepCore
import SitRepTestSupport
import Testing

/// One jump at a time, the latest click winning: a jump asked for while one runs stops it and runs once it has ended,
/// but a click on the same session before it says it is still jumping joins it; a jump with no answer two seconds on
/// says it is still jumping, on a clock the test moves.
@MainActor
struct OneJumpTests {
    @Test func aJumpTellsHowItEnded() async {
        let (oneJump, _) = Self.made()
        let jumps = Jumps(), heard = Heard()

        oneJump.run(to: "sr-a", jumps.jump(1), told: heard.add)
        await until(turns: 100_000) { jumps.started == [1] }
        jumps.answer(1, .refused("Wingtip is not on screen."))
        await until(turns: 100_000) { !heard.news.isEmpty }

        #expect(heard.news == [.ended(.refused("Wingtip is not on screen."))])
    }

    @Test func aJumpWithNoAnswerTwoSecondsOnSaysItIsStillJumpingThenHowItEnded() async {
        let (oneJump, clock) = Self.made()
        let jumps = Jumps(), heard = Heard()

        oneJump.run(to: "sr-a", jumps.jump(1), told: heard.add)
        await until(turns: 100_000) { jumps.started == [1] && clock.sleeps.count == 1 }
        #expect(clock.sleeps == [.seconds(2)])
        #expect(heard.news.isEmpty)

        clock.pass(OneJump.stillAfter)
        await until(turns: 100_000) { !heard.news.isEmpty }
        #expect(heard.news == [.still])

        jumps.answer(1, .unanswered)
        await until(turns: 100_000) { heard.news.count == 2 }
        #expect(heard.news == [.still, .ended(.unanswered)])
    }

    @Test func aJumpAnsweringWithinTwoSecondsNeverSaysItIsStillJumping() async {
        let (oneJump, clock) = Self.made()
        let jumps = Jumps(), heard = Heard()

        oneJump.run(to: "sr-a", jumps.jump(1), told: heard.add)
        await until(turns: 100_000) { jumps.started == [1] && clock.sleeps.count == 1 }
        jumps.answer(1, .jumped)
        await until(turns: 100_000) { !heard.news.isEmpty }

        clock.pass(OneJump.stillAfter)
        await Self.settle()
        #expect(heard.news == [.ended(.jumped)])
    }

    /// The first is stopped as its task is cancelled, and ends stopped whatever it answers after, with no word of still
    /// jumping; the second, to another session, runs, and alone says it is still jumping.
    @Test func aJumpToAnotherSessionStopsTheFirstAndRunsInItsPlace() async {
        let (oneJump, clock) = Self.made()
        let jumps = Jumps(), first = Heard(), second = Heard()

        oneJump.run(to: "sr-a", jumps.jump(1), told: first.add)
        await until(turns: 100_000) { jumps.started == [1] && clock.sleeps.count == 1 }

        oneJump.run(to: "sr-b", jumps.jump(2), told: second.add)
        await until(turns: 100_000) { jumps.started == [1, 2] && !first.news.isEmpty }
        #expect(jumps.stopped == [1])
        #expect(first.news == [.ended(.stopped)])

        jumps.answer(1, .jumped)
        clock.pass(OneJump.stillAfter)
        await until(turns: 100_000) { !second.news.isEmpty }
        #expect(first.news == [.ended(.stopped)])
        #expect(second.news == [.still])

        jumps.answer(2, .jumped)
        await until(turns: 100_000) { second.news.count == 2 }
        #expect(second.news == [.still, .ended(.jumped)])
        #expect(jumps.stopped == [1])
    }

    /// The jump stopped may take a moment to end: the next jump runs only once it has ended, so the two never run at
    /// once.
    @Test func aJumpRunsOnlyOnceTheOneItStoppedHasEnded() async {
        let (oneJump, _) = Self.made()
        let jumps = Jumps(lingering: [1]), first = Heard(), second = Heard()

        oneJump.run(to: "sr-a", jumps.jump(1), told: first.add)
        await until(turns: 100_000) { jumps.started == [1] }
        oneJump.run(to: "sr-b", jumps.jump(2), told: second.add)
        await until(turns: 100_000) { jumps.stopped == [1] }
        await Self.settle()
        #expect(jumps.started == [1])

        jumps.answer(1, .stopped)
        await until(turns: 100_000) { jumps.started == [1, 2] }
        #expect(first.news == [.ended(.stopped)])
    }

    /// A double-click, or a quick second click on the session, joins the jump under way: no second jump, and both
    /// clicks hear its news, which is told once a jump.
    @Test func aClickOnTheSameSessionBeforeStillJumpingJoinsTheJump() async {
        let (oneJump, clock) = Self.made()
        let jumps = Jumps(), first = Heard(), second = Heard(), once = Heard()

        oneJump.heard = once.add
        oneJump.run(to: "sr-a", jumps.jump(1), told: first.add)
        await until(turns: 100_000) { jumps.started == [1] && clock.sleeps.count == 1 }
        oneJump.run(to: "sr-a", jumps.jump(2), told: second.add)
        #expect(jumps.stopped.isEmpty, "the jump under way runs on")

        clock.pass(OneJump.stillAfter)
        await until(turns: 100_000) { once.news == [.still] }
        jumps.answer(1, .jumped)
        await until(turns: 100_000) { once.news.count == 2 }

        #expect(jumps.started == [1])
        #expect(first.news == [.still, .ended(.jumped)])
        #expect(second.news == [.still, .ended(.jumped)])
        #expect(once.news == [.still, .ended(.jumped)])
        #expect(clock.sleeps == [.seconds(2)])
    }

    /// Once the jump says it is still jumping, a click on its session is Lee trying again: it starts over.
    @Test func aClickOnTheSameSessionOnceStillJumpingStartsItOver() async {
        let (oneJump, clock) = Self.made()
        let jumps = Jumps(), first = Heard(), second = Heard()

        oneJump.run(to: "sr-a", jumps.jump(1), told: first.add)
        await until(turns: 100_000) { jumps.started == [1] && clock.sleeps.count == 1 }
        clock.pass(OneJump.stillAfter)
        await until(turns: 100_000) { first.news == [.still] }

        oneJump.run(to: "sr-a", jumps.jump(2), told: second.add)
        await until(turns: 100_000) { jumps.started == [1, 2] }
        #expect(jumps.stopped == [1])
        #expect(first.news == [.still, .ended(.stopped)])

        jumps.answer(2, .jumped)
        await until(turns: 100_000) { !second.news.isEmpty }
        #expect(second.news == [.ended(.jumped)])
    }

    /// A click on another session wins at once, before the jump under way says it is still jumping.
    @Test func aClickOnAnotherSessionWinsAtOnce() async {
        let (oneJump, clock) = Self.made()
        let jumps = Jumps(), first = Heard(), second = Heard()

        oneJump.run(to: "sr-a", jumps.jump(1), told: first.add)
        await until(turns: 100_000) { jumps.started == [1] && clock.sleeps.count == 1 }
        oneJump.run(to: "sr-b", jumps.jump(2), told: second.add)
        await until(turns: 100_000) { jumps.started == [1, 2] }

        #expect(jumps.stopped == [1])
        #expect(first.news == [.ended(.stopped)])
        #expect(second.news.isEmpty)
    }

    /// A joined pair, then a click on another session: both clicks of the pair hear the jump stopped.
    @Test func bothClicksOfAJoinedPairHearItStopped() async {
        let (oneJump, clock) = Self.made()
        let jumps = Jumps(), first = Heard(), second = Heard(), other = Heard()

        oneJump.run(to: "sr-a", jumps.jump(1), told: first.add)
        await until(turns: 100_000) { jumps.started == [1] && clock.sleeps.count == 1 }
        oneJump.run(to: "sr-a", jumps.jump(2), told: second.add)
        oneJump.run(to: "sr-b", jumps.jump(3), told: other.add)
        await until(turns: 100_000) { jumps.started == [1, 3] && second.news.count == 1 }

        #expect(first.news == [.ended(.stopped)])
        #expect(second.news == [.ended(.stopped)])
        #expect(other.news.isEmpty)
    }

    /// Stops in a chain, A then B then C: each waits on the one before, B never runs, and C runs once A has ended.
    @Test func aChainOfStopsEachWaitsOnTheOneBefore() async {
        let (oneJump, _) = Self.made()
        let jumps = Jumps(lingering: [1]), a = Heard(), b = Heard(), c = Heard()

        oneJump.run(to: "sr-a", jumps.jump(1), told: a.add)
        await until(turns: 100_000) { jumps.started == [1] }
        oneJump.run(to: "sr-b", jumps.jump(2), told: b.add)
        oneJump.run(to: "sr-c", jumps.jump(3), told: c.add)
        await Self.settle()
        #expect(jumps.started == [1])

        jumps.answer(1, .stopped)
        await until(turns: 100_000) { jumps.started == [1, 3] && b.news.count == 1 }
        #expect(a.news == [.ended(.stopped)])
        #expect(b.news == [.ended(.stopped)])
        #expect(c.news.isEmpty)
    }

    /// A jump that answers stopped ends stopped, which no surface tells as a failure.
    @Test func aJumpThatAnswersStoppedEndsStopped() async {
        let (oneJump, _) = Self.made()
        let jumps = Jumps(), heard = Heard()

        oneJump.run(to: "sr-a", jumps.jump(1), told: heard.add)
        await until(turns: 100_000) { jumps.started == [1] }
        jumps.answer(1, .stopped)
        await until(turns: 100_000) { !heard.news.isEmpty }

        #expect(heard.news == [.ended(.stopped)])
    }

    /// The clock holds a cancelled sleep until it is passed, so a stopped jump's wait on still jumping ends as one not
    /// stopped would, and only OneJump's own check of the cancellation keeps it from saying it is still jumping.
    private static func made() -> (OneJump, TestClock) {
        let clock = TestClock(passing: [], holdsCancelled: true)

        return (OneJump(sleep: { try await clock.sleep(for: $0) }), clock)
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

/// Jumps the test answers, each by its number: one waits until answered, or until its task is cancelled, when it
/// answers stopped, as a jump stopped between its steps does; one lingering waits on, as a jump slow to end does,
/// until the test answers it.
private final class Jumps: Sendable {
    private struct State {
        var started: [Int] = []
        var stopped: [Int] = []
        var waiting: [Int: CheckedContinuation<JumpAnswer, Never>] = [:]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let lingering: Set<Int>

    init(lingering: Set<Int> = []) {
        self.lingering = lingering
    }

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

                    if isStopped, !lingering.contains(number) {
                        answer(number, .stopped)
                    }
                }
            } onCancel: {
                state.withLock { $0.stopped.append(number) }
                if !lingering.contains(number) {
                    answer(number, .stopped)
                }
            }
        }
    }

    /// The jump answers, if it still waits.
    func answer(_ number: Int, _ answer: JumpAnswer) {
        state.withLock { $0.waiting.removeValue(forKey: number) }?.resume(returning: answer)
    }
}
