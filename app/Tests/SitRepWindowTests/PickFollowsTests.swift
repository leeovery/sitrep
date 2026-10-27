import Foundation
@testable import SitRepWindow
import Testing

/// Lee's picks in the list, what they follow settled: an arrow key held down the list follows the first row, the
/// second, and the one it stops on.
struct PickFollowsTests {
    private static func at(_ seconds: TimeInterval) -> Date {
        printedAt.addingTimeInterval(seconds)
    }

    /// A pick a whole `settle` after the last is one on its own.
    @Test func aPickOnItsOwnIsFollowedAtOnce() {
        var settled = PickFollows()

        settled.picked(at: Self.at(0), following: ["a"])
        #expect(settled.standing == nil)
        settled.picked(at: Self.at(0).addingTimeInterval(PickFollows.settle), following: ["b"])
        #expect(settled.standing == nil)
        #expect(settled.dueAt == nil)
    }

    /// Each pick is given what the window followed as it came: the first pick's sessions, `a`, as the run began.
    @Test func picksInARunFollowWhatWasFollowedAsTheRunBeganUntilThePicksStop() {
        var settled = PickFollows()

        settled.picked(at: Self.at(0), following: [])
        settled.picked(at: Self.at(0.1), following: ["a"])
        settled.picked(at: Self.at(0.2), following: ["a"])
        #expect(settled.standing == ["a"])
        #expect(settled.dueAt == Self.at(0.2).addingTimeInterval(PickFollows.settle))
        settled.settle(at: Self.at(0.3))
        #expect(settled.standing == ["a"])
        settled.settle(at: Self.at(0.2).addingTimeInterval(PickFollows.settle))
        #expect(settled.standing == nil)
        #expect(settled.dueAt == nil)
    }

    /// As an arrow key repeating for a second: the run settles from its last pick, however long it ran.
    @Test func aRunLongerThanTheSettleWaitsFromItsLastPick() {
        var settled = PickFollows()
        let picks = stride(from: 0.0, through: 1, by: 0.1).map(Self.at)

        settled.picked(at: picks[0], following: [])
        for pick in picks.dropFirst() {
            settled.picked(at: pick, following: ["a"])
        }
        #expect(settled.dueAt == picks.last?.addingTimeInterval(PickFollows.settle))
        settled.settle(at: Self.at(1.1))
        #expect(settled.standing == ["a"])
    }

    @Test func aPickOnItsOwnAfterARunEndsTheRun() {
        var settled = PickFollows()

        settled.picked(at: Self.at(0), following: [])
        settled.picked(at: Self.at(0.1), following: ["a"])
        settled.picked(at: Self.at(0.5), following: ["a"])
        #expect(settled.standing == nil)
        #expect(settled.dueAt == nil)
    }
}
