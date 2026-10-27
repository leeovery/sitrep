import Foundation
import SitRepLines
@testable import SitRepWindow
import Testing

/// An ask that closes keeps its place on the page only while the pointer is over the page, in the window key, and for
/// a second after it leaves; then it leaves the asks for Resolved, as a page picked afresh shows it. Lee's answer to k1
/// went in, and his ignore dropped k3.
struct ClosedAsksTests {
    private static let yes = AskAddress(session: "sr-macapp", ask: "k1")
    private static let left = printedAt.addingTimeInterval(3)

    /// The session's next board, which has k1 sent and k3 ignored.
    private static func closing(_ run: WindowRun, to board: String = Lines.delivered) {
        take(["sr-macapp": board], in: run)
    }

    private static func asks(_ run: WindowRun) -> [String]? {
        run.page(at: printedAt).session?.asks.map(\.id.ask)
    }

    private static func resolved(_ run: WindowRun) -> [String]? {
        run.page(at: printedAt).session?.resolved.map(\.id)
    }

    /// With the pointer over the page, they keep their places faint as `OpenSessionTests` has them.
    @Test func aSecondAfterThePointerLeavesThePageTheClosedAsksLeaveForResolved() {
        let run = opened()
        let unheld = run.nextChange

        overThePage(run)
        Self.closing(run)
        run.pointer(overPage: false, from: pageRegion, at: Self.left)
        #expect(run.nextChange == Self.left.addingTimeInterval(1))
        run.settle(at: Self.left.addingTimeInterval(0.99))
        #expect(Self.asks(run) == ["k1", "k3", "k2"])
        run.settle(at: Self.left.addingTimeInterval(1))
        #expect(Self.asks(run) == ["k2"])
        #expect(Self.resolved(run) == ["k1", "k5", "k4"])
        #expect(run.nextChange == unheld)
    }

    @Test func thePointerBackOverThePageWithinTheSecondKeepsThem() {
        let run = opened()

        overThePage(run)
        Self.closing(run)
        run.pointer(overPage: false, from: pageRegion, at: Self.left)
        run.pointer(overPage: true, from: pageRegion, at: Self.left.addingTimeInterval(0.5))
        run.settle(at: Self.left.addingTimeInterval(2))
        #expect(Self.asks(run) == ["k1", "k3", "k2"])
    }

    /// A page coming as another goes: whichever says so first, the pointer over the one coming holds the page.
    @Test(arguments: [true, false])
    func aRegionGoingAsAnotherComesLeavesThePageHeld(comingFirst: Bool) {
        let run = opened()

        overThePage(run)
        Self.closing(run)
        if comingFirst {
            run.pointer(overPage: true, from: otherRegion, at: Self.left)
            run.pointer(overPage: false, from: pageRegion, at: Self.left)
        } else {
            run.pointer(overPage: false, from: pageRegion, at: Self.left)
            run.pointer(overPage: true, from: otherRegion, at: Self.left)
        }
        run.settle(at: Self.left.addingTimeInterval(2))
        #expect(Self.asks(run) == ["k1", "k3", "k2"])
        run.pointer(overPage: false, from: otherRegion, at: Self.left.addingTimeInterval(2))
        run.settle(at: Self.left.addingTimeInterval(3))
        #expect(Self.asks(run) == ["k2"])
    }

    @Test func withThePointerNeverOverThePageAnAskClosingGoesStraightToResolved() {
        let run = opened()

        Self.closing(run)
        #expect(Self.asks(run) == ["k2"])
        #expect(Self.resolved(run) == ["k1", "k5", "k4"])
    }

    /// The board that lets a closed ask go lands a new one at the top, washed, all the same.
    @Test func withNothingHeldANewAskLandsAtTheTopWashedAsTheClosedOnesLeave() {
        let run = opened()

        Self.closing(run, to: deliveredAndNew)

        let asks = run.page(at: printedAt).session?.asks

        #expect(asks?.map(\.id.ask) == ["k4", "k2"])
        #expect(asks?.map(\.washed) == [printedAt, nil])
    }

    @Test func inAWindowNotKeyThePointerOverThePageHoldsNothing() {
        let run = opened()

        run.pointer(overPage: true, from: pageRegion, at: printedAt)
        Self.closing(run)
        #expect(Self.asks(run) == ["k2"])
    }

    @Test func aSecondAfterTheWindowStopsBeingKeyTheClosedAsksLeave() {
        let run = opened()

        overThePage(run)
        Self.closing(run)
        run.window(isKey: false, at: Self.left)
        run.settle(at: Self.left.addingTimeInterval(0.99))
        #expect(Self.asks(run) == ["k1", "k3", "k2"])
        run.settle(at: Self.left.addingTimeInterval(1))
        #expect(Self.asks(run) == ["k2"])
    }

    @Test func theWindowKeyAgainWithinTheSecondKeepsThem() {
        let run = opened()

        overThePage(run)
        Self.closing(run)
        run.window(isKey: false, at: Self.left)
        run.window(isKey: true, at: Self.left.addingTimeInterval(0.5))
        run.settle(at: Self.left.addingTimeInterval(2))
        #expect(Self.asks(run) == ["k1", "k3", "k2"])
    }

    /// A first click: the pointer comes over the page of a window not key, which the click then makes key.
    @Test func thePointerOverThePageBeforeTheWindowIsKeyHoldsItOnceItIs() {
        let run = opened()

        run.pointer(overPage: true, from: pageRegion, at: printedAt)
        run.window(isKey: true, at: printedAt)
        Self.closing(run)
        #expect(Self.asks(run) == ["k1", "k3", "k2"])
    }

    /// Let go, k1 and k3 are as new to the page should the board have them open again.
    @Test func anAskLetGoAndOpenAgainComesBackNewAtTheTopWashed() {
        let run = opened()
        let later = printedAt.addingTimeInterval(5)

        Self.closing(run)
        take(["sr-macapp": Lines.board], in: run, at: later)

        let asks = run.page(at: later).session?.asks

        #expect(asks?.map(\.id.ask) == ["k1", "k3", "k2"])
        #expect(asks?.map(\.washed) == [later, later, nil])
    }

    @Test func minimisedWithThePointerOverThePageTheClosedAsksLeave() {
        let run = opened()

        overThePage(run)
        Self.closing(run)
        run.minimise()
        #expect(Self.asks(run) == ["k2"])
    }

    @Test func closedWithThePointerOverThePageTheClosedAsksLeave() {
        let run = opened()

        overThePage(run)
        Self.closing(run)
        run.close()
        #expect(Self.asks(run) == ["k2"])
    }

    /// The pointer stays over the page through a pick: the last page's closed asks are gone with it, and the new
    /// page's are held.
    @Test func aPickWhileThePageIsHeldHoldsTheNewPage() {
        let run = opened()

        overThePage(run)
        Self.closing(run)
        run.pick(.project("sitrep"))
        take(["sr-macapp": Lines.board], in: run)
        #expect(run.page(at: printedAt).project?.asks.map(\.card.isClosed) == [false, false, false])
        take(["sr-macapp": Lines.delivered], in: run, on: line(2))
        #expect(run.page(at: printedAt).project?.asks.map(\.card.isClosed) == [true, true, false])
    }

    /// A pick in the list holds the list's order for a second, not the page.
    @Test func aPickInTheListLeavesThePageUnheld() {
        let run = opened()

        run.pickInList(.session("sr-macapp"), at: printedAt)
        take(["sr-macapp": Lines.delivered], in: run)
        #expect(Self.asks(run) == ["k2"])
    }

    /// Claude closed k1 while Lee's answer to it waited its two seconds: it keeps its place, and stays out of Resolved,
    /// until the answer settles, as k3 beside it leaves.
    @Test func anAskClosingWhileItsAnswerWaitsStaysUntilTheAnswerSettles() {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        Self.closing(run)
        #expect(Self.asks(run) == ["k1", "k2"])
        #expect(Self.resolved(run) == ["k5", "k4"])
        _ = run.due(at: printedAt.addingTimeInterval(2))
        _ = run.answered(Self.yes, .refused("k1 is already closed."))
        run.settle(at: printedAt.addingTimeInterval(2))
        #expect(Self.asks(run) == ["k2"])
        #expect(Self.resolved(run) == ["k1", "k5", "k4"])
    }

    /// Escape takes back the press that kept k1: nothing keeps it now.
    @Test func anAskClosedUnderAWaitingPressLeavesOnceThePressIsTakenBack() {
        let run = opened()

        _ = run.press(.yes("Approve"), on: Self.yes, at: printedAt)
        Self.closing(run)
        #expect(Self.asks(run) == ["k1", "k2"])
        #expect(run.undo())
        run.settle(at: printedAt.addingTimeInterval(1))
        #expect(Self.asks(run) == ["k2"])
    }
}

/// A project's page holds its sessions' closed asks as a session's page does.
struct ProjectClosedAsksTests {
    private static let left = printedAt.addingTimeInterval(3)

    /// The project's page, its session's board come, then its next, having k1 sent and k3 ignored.
    private static func closing(_ run: WindowRun, overThePage isOver: Bool) {
        run.pick(.project("sitrep"))
        take(["sr-macapp": Lines.board], in: run)
        if isOver {
            overThePage(run)
        }
        take(["sr-macapp": Lines.delivered], in: run, on: line(2))
    }

    private static func asks(_ run: WindowRun) -> [String]? {
        run.page(at: printedAt).project?.asks.map(\.card.id.ask)
    }

    @Test func aSecondAfterThePointerLeavesThePageTheClosedAsksLeave() {
        let run = opened()

        Self.closing(run, overThePage: true)
        #expect(Self.asks(run) == ["k1", "k3", "k2"])
        run.pointer(overPage: false, from: pageRegion, at: Self.left)
        #expect(run.nextChange == Self.left.addingTimeInterval(1))
        run.settle(at: Self.left.addingTimeInterval(1))
        #expect(Self.asks(run) == ["k2"])
    }

    @Test func withThePointerNeverOverThePageAnAskClosingLeavesAtOnce() {
        let run = opened()

        Self.closing(run, overThePage: false)
        #expect(Self.asks(run) == ["k2"])
    }
}
