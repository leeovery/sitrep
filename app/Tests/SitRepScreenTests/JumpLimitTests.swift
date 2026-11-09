import Foundation
import SitRepCore
@testable import SitRepScreen
import Testing

/// A window of the watch's line: its writer, its session, its place in the jump's order, and the device of its own
/// Ghostty window, where it says one.
struct LineWindow {
    let writer: String
    let session: String
    var order: Int?
    var device: String?
}

/// A line of the watch holding only the windows given, decoded as SitRep decodes one: small, and built in code.
func board(_ windows: [LineWindow]) throws -> Board {
    let windows: [[String: Any]] = windows.map { window in
        [
            "writer": window.writer, "session": window.session, "name": named, "project": "Switchboard",
            "version": NSNull(), "needsReload": false, "state": NSNull(), "attachedAt": 0,
            "where": window.device.map { ["device": $0, "terminal": "ghostty"] } ?? NSNull(),
            "jumpOrder": window.order ?? NSNull(),
        ] as [String: Any]
    }
    let line: [String: Any] = [
        "v": 3, "at": 0, "head": ["needYou": 0, "sessions": 1], "rows": [], "windows": windows, "new": [],
    ]
    let decoder = JSONDecoder()

    decoder.dateDecodingStrategy = .millisecondsSince1970
    return try decoder.decode(Board.self, from: JSONSerialization.data(withJSONObject: line))
}

/// The jump from the watch's line, within its limit, and stopped between its steps, the latest click winning.
struct JumpLimitTests {
    /// A board carried into a closure that gives it to a jump: never changed once decoded.
    private static func giving(_ board: Board) -> @Sendable () async -> JumpBoard.Read {
        { .board(board) }
    }

    @Test func aJumpGoesFromTheWatchsLineTheSessionsWindowsInCoresOrderNeverTheirPlaceInItsWindows() async throws {
        let line = try board([
            LineWindow(writer: "w1", session: "sr-a", order: 1, device: kitTerminal.device),
            LineWindow(writer: "w2", session: "sr-b", order: 0, device: "/dev/ttys090"),
            LineWindow(writer: "w3", session: "sr-a", order: nil, device: nil),
            LineWindow(writer: "w4", session: "sr-a", order: 0, device: "/dev/ttys099"),
        ])
        let jumping = Jumping()

        #expect(await jumping.jump.run(to: "sr-a", on: Self.giving(line)) == .jumped)
        #expect(jumping.ghostty.asked == ["/dev/ttys099", kitTerminal.device])
        #expect(jumping.ghostty.focused == ["KIT-TERMINAL"])
    }

    @Test func aRefusalNamesTheSessionByItsNameOnTheBoardOrAsTheSessionWhereItIsNotOnIt() async throws {
        let line = try board([LineWindow(writer: "w1", session: "sr-a")])

        #expect(await Jumping().jump.run(to: "sr-a", on: Self.giving(line)) == offScreen)
        #expect(
            await Jumping().jump.run(to: "sr-z", on: Self.giving(line))
                == .refused("The session is not on screen: no terminal window on this Mac shows it.")
        )
    }

    @Test func withNoBoardHeardTheJumpIsRefusedInTheWordsOfWhyNone() async {
        #expect(await Jumping().jump.run(to: "sr-a", on: { .unread("sitrep watch ended.") }) == .refused("sitrep watch ended."))
    }

    @Test func aJumpWaitsForTheWatchsFirstLineWithinItsLimit() async throws {
        let line = try board([LineWindow(writer: "w1", session: "sr-a", order: 0, device: window)])
        let gate = Gate()
        let jumping = Jumping()
        let jumped = Task {
            await jumping.jump.run(to: "sr-a", on: {
                await gate.pass()
                return .board(line)
            })
        }

        await until { gate.arrived == 1 }
        gate.open()
        #expect(await jumped.value == .jumped)

        let never = Jumping()
        let unanswered = Task {
            await never.jump.run(to: "sr-a", on: {
                await Gate().pass()
                return .unread("")
            })
        }

        await until { never.clock.sleeps.contains(Jump.limit) }
        never.clock.pass(Jump.limit)
        #expect(await unanswered.value == .unanswered)
    }

    @Test func theWholeJumpGivesUpAfterFifteenSecondsUnansweredLettingGoOfAQuestionGhosttyHasNotAnswered() async throws {
        let line = try board([LineWindow(writer: "w1", session: "sr-a", order: 0, device: window)])
        let gate = Gate()
        let jumping = Jumping(ghosttyHeld: gate)
        let jumped = Task { await jumping.jump.run(to: "sr-a", on: Self.giving(line)) }

        await until { gate.arrived == 1 && jumping.clock.sleeps.contains(Jump.limit) }
        jumping.clock.pass(Jump.limit)
        #expect(await jumped.value == .unanswered)
        #expect(Jump.limit == .seconds(15))

        gate.open()
        await settle()
        #expect(jumping.ghostty.told.isEmpty, "a jump given up sends nothing after")
    }

    @Test func aJumpStoppedEndsStoppedAtOnceLettingGoOfItsQuestionInFlightAndSendsNothingAfter() async throws {
        let line = try board([LineWindow(writer: "w1", session: "sr-a", order: 0, device: window)])
        let gate = Gate()
        let jumping = Jumping(ghosttyHeld: gate)
        let jumped = Task { await jumping.jump.run(to: "sr-a", on: Self.giving(line)) }

        await until { gate.arrived == 1 }
        jumped.cancel()
        #expect(await jumped.value == .stopped)

        gate.open()
        await settle()
        #expect(jumping.ghostty.told.isEmpty)
    }

    @Test func aJumpStoppedInItsPauseNeverFocuses() async {
        let (tmux, table) = shown()
        let tabbed = [FakeWindow(id: "TABBED-WINDOW", tabs: [[kitTerminal], [switchboardTerminal]], selected: 0)]
        let jumping = Jumping(tmux, table, terminals: tabbed, clock: TestClock(passing: []))
        let jumped = Task { await jumping.run([inTmux()]) }

        await until { jumping.clock.sleeps.contains(GhosttyDriver.pause) }
        jumped.cancel()

        #expect(await jumped.value == .stopped)
        #expect(jumping.ghostty.told == ["activate window TABBED-WINDOW"])
    }

    @Test func aJumpStoppedWhileTmuxReadsAsksGhosttyNothing() async {
        let (tmux, table) = shown()
        let gate = Gate()
        let jumping = Jumping(tmux, table, tmuxHeld: gate)
        let jumped = Task { await jumping.run([inTmux()]) }

        await until { gate.arrived == 2 }
        jumped.cancel()
        gate.open()

        #expect(await jumped.value == .stopped)
        #expect(jumping.ghostty.asked.isEmpty)
    }

    /// The latest click wins: a click on another session stops the jump under way, whose question to Ghostty is still
    /// in flight, and the new jump runs without waiting on that question; the stopped one, its question answered at
    /// last, sends nothing more.
    @MainActor
    @Test func aLaterClickStopsTheJumpUnderWayBetweenItsStepsAndJumpsWithoutWaitingOnItsQuestionInFlight() async throws {
        let line = try board([
            LineWindow(writer: "w1", session: "sr-a", order: 0, device: kitTerminal.device),
            LineWindow(writer: "w2", session: "sr-b", order: 0, device: window),
        ])
        let gate = Gate()
        let jumping = Jumping(ghosttyHeld: gate)
        let oneJump = OneJump { _ in try await Task.sleep(for: .seconds(3600)) }
        let first = Told(), second = Told()

        oneJump.run(to: "sr-a", { await jumping.jump.run(to: "sr-a", on: Self.giving(line)) }, told: first.add)
        await until { gate.arrived == 1 }
        oneJump.run(to: "sr-b", { await jumping.jump.run(to: "sr-b", on: Self.giving(line)) }, told: second.add)
        await until { !second.news.isEmpty }

        #expect(first.news == [.ended(.stopped)])
        #expect(second.news == [.ended(.jumped)])
        #expect(jumping.ghostty.focused == ["SWITCHBOARD-TERMINAL"])

        gate.open()
        await settle()
        #expect(jumping.ghostty.asked == [kitTerminal.device, window])
        #expect(jumping.ghostty.told == ["focus SWITCHBOARD-TERMINAL"], "the stopped jump sends nothing once its question is answered")
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
