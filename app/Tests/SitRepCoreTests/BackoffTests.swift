@testable import SitRepCore
import Testing

struct BackoffTests {
    @Test func theWaitStartsAtASecondAndDoublesAtEachEndToHalfAMinute() {
        var backoff = Backoff()
        let waits = (1...8).map { _ in backoff.wait(after: .zero) }

        #expect(waits == [1, 2, 4, 8, 16, 30, 30, 30].map { .seconds($0) })
    }

    @Test func aRunThatLivedAMinuteStartsTheCountAgain() {
        var backoff = Backoff()

        for _ in 1...4 { _ = backoff.wait(after: .seconds(5)) }

        #expect(backoff.wait(after: .seconds(60)) == .seconds(1))
        #expect(backoff.wait(after: .zero) == .seconds(2))
    }

    @Test func aRunJustShortOfAMinuteDoesNot() {
        var backoff = Backoff()

        for _ in 1...4 { _ = backoff.wait(after: .seconds(5)) }

        #expect(backoff.wait(after: .seconds(59)) == .seconds(16))
    }
}
