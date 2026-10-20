import Foundation
@testable import SitRepWindow
import Testing

/// Lee's picks in the list, their reads settled: an arrow key held down the list reads the first row, the second, and
/// the one it stops on.
struct PickReadsTests {
    private static func at(_ seconds: TimeInterval) -> Date {
        printedAt.addingTimeInterval(seconds)
    }

    /// A pick a whole `settle` after the last is one on its own.
    @Test func aPickOnItsOwnReadsAtOnce() {
        var settled = PickReads()

        #expect(settled.picked(["a"], at: Self.at(0)) == ["a"])
        #expect(settled.picked(["b"], at: Self.at(0).addingTimeInterval(PickReads.settle)) == ["b"])
        #expect(settled.dueAt == nil)
    }

    @Test func picksInARunReadOnlyTheLastOnceThePicksStop() {
        var settled = PickReads()

        #expect(settled.picked(["a"], at: Self.at(0)) == ["a"])
        #expect(settled.picked(["b"], at: Self.at(0.1)).isEmpty)
        #expect(settled.picked(["c"], at: Self.at(0.2)).isEmpty)
        #expect(settled.dueAt == Self.at(0.2).addingTimeInterval(PickReads.settle))
        #expect(settled.due(at: Self.at(0.3)).isEmpty)
        #expect(settled.due(at: Self.at(0.2).addingTimeInterval(PickReads.settle)) == ["c"])
        #expect(settled.due(at: Self.at(1)).isEmpty)
        #expect(settled.dueAt == nil)
    }

    /// As an arrow key repeating for a second: the run's reads wait from its last pick, however long it ran.
    @Test func aRunLongerThanTheSettleWaitsFromItsLastPick() {
        var settled = PickReads()
        let picks = stride(from: 0.0, through: 1, by: 0.1).map(Self.at)

        #expect(settled.picked(["a"], at: picks[0]) == ["a"])
        for pick in picks.dropFirst() {
            #expect(settled.picked(["b"], at: pick).isEmpty)
        }
        #expect(settled.dueAt == picks.last?.addingTimeInterval(PickReads.settle))
        #expect(settled.due(at: Self.at(1.1)).isEmpty)
    }

    @Test func aPickOnItsOwnAfterARunDropsTheRunsReadsForItsOwn() {
        var settled = PickReads()

        _ = settled.picked(["a"], at: Self.at(0))
        _ = settled.picked(["b"], at: Self.at(0.1))
        #expect(settled.picked(["c"], at: Self.at(0.5)) == ["c"])
        #expect(settled.due(at: Self.at(1)).isEmpty)
    }

    /// As a quiet project picked among sessions: it shows no session, so there is nothing to read.
    @Test func aPickWithNothingToReadInARunLetsTheRunsReadsGo() {
        var settled = PickReads()

        _ = settled.picked(["a"], at: Self.at(0))
        _ = settled.picked(["b"], at: Self.at(0.1))
        #expect(settled.picked([], at: Self.at(0.2)).isEmpty)
        #expect(settled.dueAt == nil)
        #expect(settled.due(at: Self.at(1)).isEmpty)
    }
}
