import Foundation
@testable import SitRepWindow
import Testing

/// Lee's picks' reads, settled: an arrow key held down the list reads the first row and the one it stops on.
struct PickReadsTests {
    private static func reads(_ session: String) -> [Read] {
        [Read(session: session, ticket: 1)]
    }

    private static func at(_ seconds: TimeInterval) -> Date {
        printedAt.addingTimeInterval(seconds)
    }

    @Test func aPickOnItsOwnReadsAtOnce() {
        var settled = PickReads()

        #expect(settled.picked(Self.reads("a"), at: Self.at(0)) == Self.reads("a"))
        #expect(settled.picked(Self.reads("b"), at: Self.at(1)) == Self.reads("b"))
        #expect(settled.dueAt == nil)
    }

    @Test func picksInARunReadOnlyTheLastOnceThePicksStop() {
        var settled = PickReads()

        #expect(settled.picked(Self.reads("a"), at: Self.at(0)) == Self.reads("a"))
        #expect(settled.picked(Self.reads("b"), at: Self.at(0.1)).isEmpty)
        #expect(settled.picked(Self.reads("c"), at: Self.at(0.2)).isEmpty)
        #expect(settled.dueAt == Self.at(0.2).addingTimeInterval(PickReads.settle))
        #expect(settled.due(at: Self.at(0.3)).isEmpty)
        #expect(settled.due(at: Self.at(0.2).addingTimeInterval(PickReads.settle)) == Self.reads("c"))
        #expect(settled.due(at: Self.at(1)).isEmpty)
        #expect(settled.dueAt == nil)
    }

    @Test func aPickOnItsOwnAfterARunDropsTheRunsReadsForItsOwn() {
        var settled = PickReads()

        _ = settled.picked(Self.reads("a"), at: Self.at(0))
        _ = settled.picked(Self.reads("b"), at: Self.at(0.1))
        #expect(settled.picked(Self.reads("c"), at: Self.at(0.5)) == Self.reads("c"))
        #expect(settled.due(at: Self.at(1)).isEmpty)
    }
}
