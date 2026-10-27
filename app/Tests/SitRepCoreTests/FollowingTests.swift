import Foundation
@testable import SitRepCore
import Testing

/// What the app's one `watch` is told the window follows, run by run.
struct FollowingTests {
    private static func follow(_ sessions: [String]) -> String {
        #"{"follow":[\#(sessions.map { "\"\($0)\"" }.joined(separator: ","))]}"#
    }

    /// Everything the run was told, once it has ended.
    private static func told(_ run: RunInput) async -> [String] {
        await run.lines.reduce(into: []) { $0.append($1) }
    }

    @Test func aRunIsToldTheSetAsItStandsAsItBeginsSortedSoASetIsOneLine() async {
        let following = Following()

        following.follow(["sr-zzzzzz", "sr-k3f9qa"])

        let run = following.begin()

        following.end(run)
        #expect(await Self.told(run) == [Self.follow(["sr-k3f9qa", "sr-zzzzzz"])])
    }

    @Test func theSetChangingIsToldOnceAndALookNowTellsItAgain() async {
        let following = Following()
        let run = following.begin()

        following.follow(["sr-k3f9qa"])
        following.follow(["sr-k3f9qa"])
        following.lookNow()
        following.end(run)
        #expect(await Self.told(run) == [Self.follow([]), Self.follow(["sr-k3f9qa"]), Self.follow(["sr-k3f9qa"])])
    }

    @Test func aRunEndedIsToldNothingMoreAndTheNextIsToldTheSetAsItStands() async {
        let following = Following()
        let ended = following.begin()

        following.end(ended)
        following.follow(["sr-k3f9qa"])
        following.lookNow()

        let next = following.begin()

        following.end(next)
        #expect(await Self.told(ended) == [Self.follow([])])
        #expect(await Self.told(next) == [Self.follow(["sr-k3f9qa"])])
    }

    /// As the watch on one plugin ends after the watch on the next began.
    @Test func aRunEndingAfterTheNextBeganLeavesTheNextOneTold() async {
        let following = Following()
        let first = following.begin()
        let second = following.begin()

        following.end(first)
        following.lookNow()
        following.end(second)
        #expect(await Self.told(first) == [Self.follow([])])
        #expect(await Self.told(second) == [Self.follow([]), Self.follow([])])
    }
}
