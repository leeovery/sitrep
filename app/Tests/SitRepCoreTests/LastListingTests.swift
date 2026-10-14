@testable import SitRepCore
import Testing

struct LastListingTests {
    private static let fumi = ListAnswer.works([OnScreen(id: "sr-047c7y", project: "Fumi", name: "Management window discussion")])
    private static let both = ListAnswer.works([
        OnScreen(id: "sr-047c7y", project: "Fumi", name: "Management window discussion"),
        OnScreen(id: "sr-y4d0qj", project: "Switchboard", name: "Milestone 7 stages 4 to 14"),
    ])

    @Test func nothingIsKeptUntilAListingAnswersSoTheMenuSaysItIsLooking() {
        var last = LastListing()

        _ = last.ask()

        #expect(last.answer == nil)
    }

    @Test func theFirstAnswerIsKept() {
        var last = LastListing()
        let listing = last.ask()

        let isTaken = last.take(Self.fumi, for: listing)

        #expect(isTaken)
        #expect(last.answer == Self.fumi)
    }

    @Test func anOpeningKeepsShowingTheLastAnswerWhileItsListingRuns() {
        var last = LastListing()

        _ = last.take(Self.fumi, for: last.ask())
        _ = last.ask()

        #expect(last.answer == Self.fumi)
    }

    @Test func anUnchangedAnswerDoesNotRedraw() {
        var last = LastListing()

        _ = last.take(Self.fumi, for: last.ask())

        let isTaken = last.take(Self.fumi, for: last.ask())

        #expect(!isTaken)
        #expect(last.answer == Self.fumi)
    }

    @Test(arguments: [both, .works([]), .failed("sitrep list did not answer within 10 seconds.")])
    func aChangedAnswerReplacesTheLast(changed: ListAnswer) {
        var last = LastListing()

        _ = last.take(Self.fumi, for: last.ask())

        let isTaken = last.take(changed, for: last.ask())

        #expect(isTaken)
        #expect(last.answer == changed)
    }

    @Test func aLateAnswerNeverReplacesANewerOne() {
        var last = LastListing()
        let earlier = last.ask()
        let later = last.ask()

        let isLaterTaken = last.take(Self.both, for: later)
        let isEarlierTaken = last.take(Self.fumi, for: earlier)

        #expect(isLaterTaken)
        #expect(!isEarlierTaken)
        #expect(last.answer == Self.both)
    }

    @Test func anAnswerOvertakenByANewerListingWaitsForThatOne() {
        var last = LastListing()
        let earlier = last.ask()

        _ = last.ask()
        let isTaken = last.take(Self.fumi, for: earlier)

        #expect(!isTaken)
        #expect(last.answer == nil)
    }
}
