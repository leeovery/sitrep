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

    @Test(arguments: [
        (0, .seconds(1), true),
        (0, .seconds(600), true),
        (0, .milliseconds(999), false),
        (1, .seconds(600), false),
        (143, .seconds(5), false),
    ] as [(Int32, Duration, Bool)])
    func onlyARunThatExited0AfterASecondMadeWayForANewVersion(status: Int32, lived: Duration, renews: Bool) {
        #expect(Backoff.renews(status: status, lived: lived) == renews)
    }

    @Test func aRenewalStartsTheCountAgain() {
        var backoff = Backoff()

        for _ in 1...4 { _ = backoff.wait(after: .seconds(5)) }

        backoff.renew()

        #expect(backoff.wait(after: .seconds(5)) == .seconds(1))
    }

    @Test func aRunJustShortOfAMinuteDoesNot() {
        var backoff = Backoff()

        for _ in 1...4 { _ = backoff.wait(after: .seconds(5)) }

        #expect(backoff.wait(after: .seconds(59)) == .seconds(16))
    }
}
