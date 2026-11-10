import Foundation
import os
@testable import SitRep
import SitRepCore
import Testing

/// A click from any surface (`Clicks`): the jump, then, where it found a window could be opened, the opening, apart from
/// it, both under the latest-click rule; a quick second click joining either, so one window opens; a failure's banner,
/// once; and the front handed back where nothing of SitRep's comes forward (stage 7, C).
@MainActor
struct ClicksTests {
    @Test func aJumpThatJumpedIsToldSoAndHandsNothingBack() async {
        let world = World { _ in .answered(.jumped) }

        world.click("sr-a")
        await world.until { world.answers["sr-a"] == [.jumped] }

        #expect(world.handBacks == 0)
        #expect(world.banners.isEmpty)
        #expect(world.heard == [.ended(.jumped)])
    }

    /// Nothing of SitRep's comes forward for a refusal, so a notification's click never leaves the front with the
    /// windowless helper.
    @Test func aRefusalPostsItsBannerAndHandsTheFrontBack() async {
        let world = World { _ in .answered(.refused("Not on screen.")) }

        world.click("sr-a")
        await world.until { world.handBacks == 1 }

        #expect(world.answers["sr-a"] == [.refused("Not on screen.")])
        #expect(world.banners == [.unjumped("Not on screen.")])
    }

    /// The jump answers openable, which ends nothing; the opening follows, and its answer is the click's.
    @Test func aWindowTheJumpFoundCanBeOpenedIsOpenedApartFromIt() async {
        let world = World { _ in .openable(.opened) }

        world.click("sr-a")
        await world.until { world.answers["sr-a"] == [.opened] }

        #expect(world.jumps == ["sr-a"])
        #expect(world.opened == ["sr-a"])
        #expect(world.heard == [.ended(.openable), .ended(.opened)])
        #expect(world.handBacks == 0)
        #expect(world.banners.isEmpty)
    }

    @Test func aWindowNotOpenedPostsItsBannerAndHandsTheFrontBack() async {
        let world = World { _ in .openable(.unopened("Set an open command.")) }

        world.click("sr-a")
        await world.until { world.handBacks == 1 }

        #expect(world.answers["sr-a"] == [.unopened("Set an open command.")])
        #expect(world.banners == [.unopened("Set an open command.")])
    }

    /// A window opened for the session a moment ago comes forward of itself, if at all: the front is handed back, and
    /// no banner posted.
    @Test func aWindowAlreadyOpeningHandsTheFrontBackWithNoBanner() async {
        let world = World { _ in .answered(.opening) }

        world.click("sr-a")
        await world.until { world.handBacks == 1 }

        #expect(world.answers["sr-a"] == [.opening])
        #expect(world.banners.isEmpty)
    }

    /// A double-click: the second, before the jump answers, joins it, and the two open one window.
    @Test func aSecondClickJoiningTheJumpOpensTheSameWindow() async {
        let jumped = Latch()
        let world = World { _ in
            await jumped.wait()
            return .openable(.opened)
        }

        world.click("sr-a")
        world.click("sr-a")
        jumped.open()
        await world.until { world.answers["sr-a"] == [.opened, .opened] }

        #expect(world.jumps == ["sr-a"])
        #expect(world.opened == ["sr-a"])
    }

    /// A second click while the window opens joins the opening, and opens no second.
    @Test func aSecondClickJoiningTheOpeningOpensNoSecondWindow() async {
        let opening = Latch()
        let world = World(opening: opening) { _ in .openable(.opened) }

        world.click("sr-a")
        await world.until { world.opened == ["sr-a"] }
        world.click("sr-a")
        opening.open()
        await world.until { world.answers["sr-a"] == [.opened, .opened] }

        #expect(world.jumps == ["sr-a"])
        #expect(world.opened == ["sr-a"])
    }

    /// The latest click wins: a click on another session stops the opening, which ends stopped whatever it came to, and
    /// its own runs once the opening's event in flight lets go.
    @Test func aClickOnAnotherSessionStopsTheOpening() async {
        let opening = Latch()
        let world = World(opening: opening) { session in session == "sr-a" ? .openable(.opened) : .answered(.jumped) }

        world.click("sr-a")
        await world.until { world.opened == ["sr-a"] }
        world.click("sr-b")
        opening.open()
        await world.until { world.answers["sr-b"] == [.jumped] }

        #expect(world.answers["sr-a"] == [.stopped])
        #expect(world.wasStopped)
        #expect(world.banners.isEmpty)
    }
}

/// Clicks over a jump that answers as `reached` says for a session, any window it finds openable opened at once, or once
/// `opening` opens; every answer, hand-back, banner and news kept.
@MainActor
private final class World {
    private struct Done: Sendable {
        var jumps: [String] = []
        var opened: [String] = []
        var stopped = false
    }

    enum Reach: Sendable {
        case answered(JumpAnswer)
        case openable(JumpAnswer)
    }

    var answers: [String: [JumpAnswer]] = [:]
    var handBacks = 0
    var banners: [Banner] = []
    var heard: [JumpNews] = []
    private let done = OSAllocatedUnfairLock(initialState: Done())
    private var clicks: Clicks?

    init(opening: Latch? = nil, _ reached: @escaping @Sendable (String) async -> Reach) {
        let done = done
        let clicks = Clicks(OneJump { _ in try await Task.sleep(for: .seconds(3600)) }, jump: { session in
            {
                done.withLock { $0.jumps.append(session) }
                switch await reached(session) {
                case let .answered(answer):
                    return .answered(answer)
                case let .openable(answer):
                    return .openable {
                        done.withLock { $0.opened.append(session) }
                        await opening?.wait()
                        done.withLock { $0.stopped = $0.stopped || Task.isCancelled }
                        return answer
                    }
                }
            }
        }, post: { [weak self] in self?.banners.append($0) })

        clicks.heard = { [weak self] in self?.heard.append($0) }
        self.clicks = clicks
    }

    var jumps: [String] { done.withLock(\.jumps) }
    var opened: [String] { done.withLock(\.opened) }
    /// Whether an opening ran on after a later click stopped it.
    var wasStopped: Bool { done.withLock(\.stopped) }

    func click(_ session: String) {
        clicks?.click(session, answered: { [weak self] in self?.answers[session, default: []].append($0) }) { [weak self] in
            self?.handBacks += 1
        }
    }

    /// Lets the tasks run until the condition holds, or, failing, a hundred thousand turns have passed: counted in
    /// turns, not time, as the main actor is shared with every other test of the suite.
    func until(sourceLocation: SourceLocation = #_sourceLocation, _ holds: () -> Bool) async {
        for _ in 0 ..< 100_000 where !holds() {
            await Task.yield()
        }
        #expect(holds(), "The condition waited for never held.", sourceLocation: sourceLocation)
    }
}

/// A latch the test opens, which a double waits at until then, heeding no cancellation, as an event in flight.
private final class Latch: Sendable {
    private let state = OSAllocatedUnfairLock(initialState: (isOpen: false, waiting: [CheckedContinuation<Void, Never>]()))

    func wait() async {
        await withCheckedContinuation { continuation in
            let isOpen = state.withLock { state in
                if !state.isOpen {
                    state.waiting.append(continuation)
                }
                return state.isOpen
            }

            if isOpen {
                continuation.resume()
            }
        }
    }

    func open() {
        state.withLock { state in
            defer { state.waiting = [] }
            state.isOpen = true
            return state.waiting
        }.forEach { $0.resume() }
    }
}
