import Foundation
import SitRepLines
@testable import SitRepWindow
import Testing

/// An ask that closes keeps its place on the page only while the pointer is over the page's asks, in the window key,
/// and for a second after it leaves them; then it leaves the asks for Resolved, as a page picked afresh shows it.
/// Lee's answer to k1 went in, and his ignore dropped k3.
struct ClosedAsksTests {
    private static let yes = AskAddress(session: "sr-macapp", ask: "k1")
    private static let left = printedAt.addingTimeInterval(3)

    /// The session's page read again, its board having k1 sent and k3 ignored.
    private static func closing(_ run: WindowRun) {
        answer(run.pick(.session("sr-macapp")), in: run, with: ["sr-macapp": Lines.delivered])
    }

    private static func asks(_ run: WindowRun) -> [String]? {
        run.page(at: printedAt).session?.asks.map(\.id.ask)
    }

    private static func resolved(_ run: WindowRun) -> [String]? {
        run.page(at: printedAt).session?.resolved.map(\.id)
    }

    /// With the pointer over the asks, they keep their places faint as `OpenSessionTests` has them.
    @Test func aSecondAfterThePointerLeavesTheAsksTheClosedOnesLeaveForResolved() {
        let run = opened()
        let unheld = run.nextChange

        overTheAsks(run)
        Self.closing(run)
        run.pointer(overAsks: false, at: Self.left)
        #expect(run.nextChange == Self.left.addingTimeInterval(1))
        run.settle(at: Self.left.addingTimeInterval(0.99))
        #expect(Self.asks(run) == ["k1", "k3", "k2"])
        run.settle(at: Self.left.addingTimeInterval(1))
        #expect(Self.asks(run) == ["k2"])
        #expect(Self.resolved(run) == ["k1", "k5", "k4"])
        #expect(run.nextChange == unheld)
    }

    @Test func thePointerBackOverTheAsksWithinTheSecondKeepsThem() {
        let run = opened()

        overTheAsks(run)
        Self.closing(run)
        run.pointer(overAsks: false, at: Self.left)
        run.pointer(overAsks: true, at: Self.left.addingTimeInterval(0.5))
        run.settle(at: Self.left.addingTimeInterval(2))
        #expect(Self.asks(run) == ["k1", "k3", "k2"])
    }

    @Test func withThePointerNeverOverTheAsksAnAskClosingGoesStraightToResolved() {
        let run = opened()

        Self.closing(run)
        #expect(Self.asks(run) == ["k2"])
        #expect(Self.resolved(run) == ["k1", "k5", "k4"])
    }

    @Test func inAWindowNotKeyThePointerOverTheAsksHoldsNone() {
        let run = opened()

        run.pointer(overAsks: true, at: printedAt)
        Self.closing(run)
        #expect(Self.asks(run) == ["k2"])
    }

    @Test func aSecondAfterTheWindowStopsBeingKeyTheClosedAsksLeave() {
        let run = opened()

        overTheAsks(run)
        Self.closing(run)
        run.window(isKey: false, at: Self.left)
        run.settle(at: Self.left.addingTimeInterval(1))
        #expect(Self.asks(run) == ["k2"])
    }

    @Test func minimisedWithThePointerOverTheAsksTheClosedOnesLeave() {
        let run = opened()

        overTheAsks(run)
        Self.closing(run)
        run.minimise()
        #expect(Self.asks(run) == ["k2"])
    }

    /// Claude closed k1 while Lee's answer to it waited its two seconds: it keeps its place until the answer settles.
    @Test func anAskClosingWhileItsAnswerWaitsStaysUntilTheAnswerSettles() {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        Self.closing(run)
        #expect(Self.asks(run) == ["k1", "k2"])
        _ = run.due(at: printedAt.addingTimeInterval(2))
        _ = run.answered(Self.yes, .refused("k1 is already closed."))
        run.settle(at: printedAt.addingTimeInterval(2))
        #expect(Self.asks(run) == ["k2"])
    }

    /// Lee's answer on its way leaves its ask open until Claude has it.
    @Test func anAskWhoseAnswerIsOnItsWayStays() throws {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        _ = run.due(at: printedAt.addingTimeInterval(2))
        answer(run.answered(Self.yes, .written), in: run, with: ["sr-macapp": Lines.onItsWay])
        run.settle(at: Self.left)

        let card = try #require(run.page(at: printedAt).session?.asks.first)

        #expect(card.id == Self.yes)
        #expect(card.lines == [.onItsWay("→ Approve", .turn)])
    }
}

/// A project's page holds its sessions' closed asks as a session's page does.
struct ProjectClosedAsksTests {
    private static let left = printedAt.addingTimeInterval(3)

    /// The project's page, its session's board read, then read again, on `watch`'s word, having k1 sent and k3
    /// ignored.
    private static func closing(_ run: WindowRun, overTheAsks isOver: Bool) {
        answer(run.pick(.project("sitrep")), in: run, with: ["sr-macapp": Lines.board])
        if isOver {
            overTheAsks(run)
        }
        answer(
            run.show(heard(line(0), line(2)), at: printedAt, reducesMotion: false), in: run,
            with: ["sr-macapp": Lines.delivered]
        )
    }

    private static func asks(_ run: WindowRun) -> [String]? {
        run.page(at: printedAt).project?.asks.map(\.card.id.ask)
    }

    @Test func aSecondAfterThePointerLeavesTheAsksTheClosedOnesLeave() {
        let run = opened()

        Self.closing(run, overTheAsks: true)
        #expect(Self.asks(run) == ["k1", "k3", "k2"])
        run.pointer(overAsks: false, at: Self.left)
        #expect(run.nextChange == Self.left.addingTimeInterval(1))
        run.settle(at: Self.left.addingTimeInterval(1))
        #expect(Self.asks(run) == ["k2"])
    }

    @Test func withThePointerNeverOverTheAsksAnAskClosingLeavesAtOnce() {
        let run = opened()

        Self.closing(run, overTheAsks: false)
        #expect(Self.asks(run) == ["k2"])
    }
}
