import Foundation
import SitRepCore
@testable import SitRepScreen
import SitRepTestSupport
import Testing

extension WatchLine.Window {
    /// A window of the jump's world, on Woodgrove's session: its writer, its session, its place in the jump's order,
    /// and the device of its own Ghostty window, where it says one; or the zmx session it runs in, on zmx's own pty;
    /// and its Claude's folder, where it says one.
    static func jumping(
        _ writer: String, session: String, order: Int? = nil, device: String? = nil, zmx: String? = nil,
        directory: String? = nil
    ) -> Self {
        let place = zmx.map { WatchLine.Where(device: "/dev/ttys087", zmx: .init(session: $0)) }
            ?? device.map { WatchLine.Where(device: $0) }

        return Self(
            writer: writer, session: session, name: JumpWorld.named, project: "Woodgrove", version: nil,
            where: place, directory: directory, attachedAt: 0, jumpOrder: order
        )
    }
}

/// A line of the watch holding only the windows given, and Woodgrove listing the sessions given, decoded as SitRep
/// decodes one.
func board(_ windows: [WatchLine.Window], sessions: [WatchLine.Session] = []) throws -> Board {
    let line = WatchLine(
        at: 0, version: nil, head: .init(needYou: 0, sessions: 1),
        projects: [.init(name: "Woodgrove", sessions: sessions)], windows: windows
    )
    let decoder = JSONDecoder()

    decoder.dateDecodingStrategy = .millisecondsSince1970
    return try decoder.decode(Board.self, from: Data(line.text.utf8))
}

/// The jump from the watch's line, within its limit, and stopped between its steps, the latest click winning.
struct JumpLimitTests {
    @Test func aJumpGoesFromTheWatchsLineTheSessionsWindowsInCoresOrderNeverTheirPlaceInItsWindows() async throws {
        let line = try board([
            WatchLine.Window.jumping("w1", session: "sr-a", order: 1, device: JumpWorld.litwareTerminal.device),
            WatchLine.Window.jumping("w2", session: "sr-b", order: 0, device: "/dev/ttys090"),
            WatchLine.Window.jumping("w3", session: "sr-a", order: nil, device: nil),
            WatchLine.Window.jumping("w4", session: "sr-a", order: 0, device: "/dev/ttys099"),
        ])
        let jumping = Jumping()

        #expect(await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) == .jumped)
        #expect(jumping.ghostty.asked == ["/dev/ttys099", JumpWorld.litwareTerminal.device])
        #expect(jumping.ghostty.focused == ["LITWARE-TERMINAL"])
    }

    /// A session on the board is named as the board names it, one with no row and no window by its project, as the
    /// CLI named it by its status; one not on the board is no such session, in the CLI's words but for its id.
    @Test func aRefusalNamesTheSessionAsTheBoardDoesOneNotOnItIsNoSuchSessionNamingNoId() async throws {
        let line = try board([WatchLine.Window.jumping("w1", session: "sr-a")], sessions: [.init(id: "sr-q", name: "Quiet one")])
        let unknown = await Jumping().jump.answer(to: "sr-z", on: GivenBoard(line))

        #expect(await Jumping().jump.answer(to: "sr-a", on: GivenBoard(line)) == JumpWorld.justStopped)
        #expect(
            await Jumping().jump.answer(to: "sr-q", on: GivenBoard(line))
                == .refused("Quiet one is not on screen: no terminal window on this Mac shows it.")
        )
        #expect(unknown == .refused("There is no such session on the board, in any project."))
        #expect(unknown.banner?.body.contains("sr-z") == false)
    }

    @Test func aWatchGivenUpIsRefusedAtOnceInItsWords() async {
        let jumping = Jumping()

        #expect(
            await jumping.jump.answer(to: "sr-a", on: GivenBoard { .unread("SitRep has no plugin to run.") })
                == .refused("SitRep has no plugin to run.")
        )
        #expect(jumping.ghostty.asked.isEmpty)
    }

    /// Waiting for a board is no busy Mac: a jump whose time runs out waiting for one says the board is not there.
    @Test func aJumpWaitsForTheBoardWithinItsLimitAndOneThatNeverComesIsRefusedAsNotThereNeverTooBusy() async throws {
        let line = try board([WatchLine.Window.jumping("w1", session: "sr-a", order: 0, device: JumpWorld.window)])
        let gate = Gate()
        let jumping = Jumping()
        let jumped = Task {
            await jumping.jump.answer(to: "sr-a", on: GivenBoard {
                await gate.pass()
                return .board(line)
            })
        }

        await until(within: .seconds(10)) { gate.arrived == 1 }
        gate.open()
        #expect(await jumped.value == .jumped)

        let never = Jumping()
        let refused = Task {
            await never.jump.answer(to: "sr-a", on: GivenBoard {
                await Gate().pass()
                return .unread("")
            })
        }

        await until(within: .seconds(10)) { never.clock.sleeps.contains(Jump.limit) }
        never.clock.pass(Jump.limit)
        #expect(await refused.value == .refused(GivenBoard.missing))
    }

    /// The jump is made once the board is in hand, Lee's PATH asked for as it is, so that wait is within the limit,
    /// and a later click ends it.
    @Test func makingTheJumpIsWithinItsLimitAndStoppedWithIt() async throws {
        let line = try board([WatchLine.Window.jumping("w1", session: "sr-a", order: 0, device: JumpWorld.window)])
        let jumping = Jumping()
        let jump = jumping.jump
        let atLimit = Gate(), atStop = Gate()
        let unanswered = Task {
            await Jump.run(to: "sr-a", on: GivenBoard(line), clock: jumping.clock) {
                await atLimit.pass()
                return jump
            }
        }

        await until(within: .seconds(10)) { atLimit.arrived == 1 && jumping.clock.sleeps.contains(Jump.limit) }
        jumping.clock.pass(Jump.limit)
        #expect(await unanswered.value.answer == .unanswered)

        let stopped = Task {
            await Jump.run(to: "sr-a", on: GivenBoard(line), clock: TestClock(passing: .jumpsPauses)) {
                await atStop.pass()
                return jump
            }
        }

        await until(within: .seconds(10)) { atStop.arrived == 1 }
        stopped.cancel()
        #expect(await stopped.value.answer == .stopped)
        #expect(jumping.ghostty.asked.isEmpty)

        atLimit.open()
        atStop.open()
    }

    @Test func theWholeJumpGivesUpAfterFifteenSecondsUnansweredNotWaitingOnAQuestionGhosttyHasNotAnswered() async throws {
        let line = try board([WatchLine.Window.jumping("w1", session: "sr-a", order: 0, device: JumpWorld.window)])
        let gate = Gate()
        let jumping = Jumping(ghosttyHeld: gate)
        let jumped = Task { await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) }

        await until(within: .seconds(10)) { gate.arrived == 1 && jumping.clock.sleeps.contains(Jump.limit) }
        jumping.clock.pass(Jump.limit)
        #expect(await jumped.value == .unanswered)
        #expect(Jump.limit == .seconds(15))

        gate.open()
    }

    @Test func aJumpStoppedEndsStoppedAtOnceNotWaitingOnItsQuestionInFlight() async throws {
        let line = try board([WatchLine.Window.jumping("w1", session: "sr-a", order: 0, device: JumpWorld.window)])
        let gate = Gate()
        let jumping = Jumping(ghosttyHeld: gate)
        let jumped = Task { await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) }

        await until(within: .seconds(10)) { gate.arrived == 1 }
        jumped.cancel()
        #expect(await jumped.value == .stopped)

        gate.open()
    }

    /// What a jump let go of, at its limit or stopped, is cancelled, and runs on to its end without being waited on.
    @Test(arguments: [false, true])
    func atItsLimitOrStoppedAJumpCancelsWhatItLetsGoOf(isStopped: Bool) async {
        let clock = TestClock(passing: .jumpsPauses)
        let gate = Gate()
        let (ended, end) = AsyncStream.makeStream(of: Bool.self)
        let answering = Task {
            await answer(within: Jump.limit, on: clock) { () async -> Int in
                await gate.pass()
                end.yield(Task.isCancelled)
                return 1
            }
        }

        await until(within: .seconds(10)) { gate.arrived == 1 && clock.sleeps.contains(Jump.limit) }
        if isStopped {
            answering.cancel()
        } else {
            clock.pass(Jump.limit)
        }
        #expect(await answering.value == nil, "answered while what it let go of still runs")

        gate.open()
        #expect(await ended.first { _ in true } == true, "what it let go of, cancelled, ran on to its end")
    }

    /// The step after a question Ghostty has not answered is never taken once the jump is cancelled: the jump, run to
    /// its end, sends nothing more.
    @Test func aJumpCancelledWhileGhosttyHoldsItsQuestionSendsNothingOnceItIsAnswered() async {
        let gate = Gate()
        let jumping = Jumping(ghosttyHeld: gate)
        let jumped = Task { try await jumping.jump.jump(to: [inGhosttyWindow]) }

        await until(within: .seconds(10)) { gate.arrived == 1 }
        jumped.cancel()
        gate.open()

        await #expect(throws: CancellationError.self) { try await jumped.value }
        #expect(jumping.ghostty.asked == [JumpWorld.litwareTerminal.device])
        #expect(jumping.ghostty.told.isEmpty)
    }

    @Test func aJumpStoppedInItsPauseNeverFocuses() async {
        let (tmux, table) = shown()
        let tabbed = [FakeWindow(id: "TABBED-WINDOW", tabs: [[JumpWorld.litwareTerminal], [JumpWorld.woodgroveTerminal]], selected: 0)]
        let jumping = Jumping(tmux, table, terminals: tabbed, clock: TestClock(passing: []))
        let jumped = Task { await jumping.run([inTmux()]) }

        await until(within: .seconds(10)) { jumping.clock.sleeps.contains(GhosttyDriver.pause) }
        jumped.cancel()

        #expect(await jumped.value == .stopped)
        #expect(jumping.ghostty.told == ["activate window TABBED-WINDOW"])
    }

    @Test func aJumpStoppedWhileTmuxReadsAsksGhosttyNothing() async {
        let (tmux, table) = shown()
        let gate = Gate()
        let jumping = Jumping(tmux, table, tmuxHeld: gate)
        let jumped = Task { await jumping.run([inTmux()]) }

        await until(within: .seconds(10)) { gate.arrived == 2 }
        jumped.cancel()
        gate.open()

        #expect(await jumped.value == .stopped)
        #expect(jumping.ghostty.asked.isEmpty)
    }

    /// The latest click wins: a click on another session stops the jump under way, whose question to Ghostty is still
    /// in flight, and the new jump runs without waiting on that question.
    @MainActor
    @Test func aLaterClickStopsTheJumpUnderWayBetweenItsStepsAndJumpsWithoutWaitingOnItsQuestionInFlight() async throws {
        let line = try board([
            WatchLine.Window.jumping("w1", session: "sr-a", order: 0, device: JumpWorld.litwareTerminal.device),
            WatchLine.Window.jumping("w2", session: "sr-b", order: 0, device: JumpWorld.window),
        ])
        let gate = Gate()
        let jumping = Jumping(ghosttyHeld: gate)
        let oneJump = OneJump { _ in try await Task.sleep(for: .seconds(3600)) }
        let first = Told(), second = Told()

        oneJump.run(to: "sr-a", { await jumping.jump.answer(to: "sr-a", on: GivenBoard(line)) }, told: first.add)
        await until(within: .seconds(10)) { gate.arrived == 1 }
        oneJump.run(to: "sr-b", { await jumping.jump.answer(to: "sr-b", on: GivenBoard(line)) }, told: second.add)
        await until(within: .seconds(10)) { !second.news.isEmpty }

        #expect(first.news == [.ended(.stopped)])
        #expect(second.news == [.ended(.jumped)])
        #expect(jumping.ghostty.asked == [JumpWorld.litwareTerminal.device, JumpWorld.window])
        #expect(jumping.ghostty.told == ["focus WOODGROVE-TERMINAL"])

        gate.open()
    }
}

/// What a click on a jump heard, in order.
@MainActor
private final class Told {
    private(set) var news: [JumpNews] = []

    func add(_ news: JumpNews) {
        self.news.append(news)
    }
}
