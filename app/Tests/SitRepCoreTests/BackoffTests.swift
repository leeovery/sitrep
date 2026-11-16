@testable import SitRepCore
import SitRepTestSupport
import Testing

@Suite(.backstop)
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
        (.status(0), .seconds(1), true),
        (.status(0), .seconds(600), true),
        (.status(0), .milliseconds(999), false),
        (.status(1), .seconds(600), false),
        (.signal(15), .seconds(600), false),
    ] as [(Exit, Duration, Bool)])
    func onlyARunThatExited0AfterASecondMadeWayForANewVersion(exit: Exit, lived: Duration, renews: Bool) {
        #expect(Backoff.renews(exit, lived: lived, sinceRenewal: nil) == renews)
    }

    @Test(arguments: [
        (.seconds(59), false),
        (.seconds(60), true),
        (.seconds(3600), true),
    ] as [(Duration, Bool)])
    func aRenewalWithinAMinuteOfTheLastIsNone(sinceRenewal: Duration, renews: Bool) {
        #expect(Backoff.renews(.status(0), lived: .seconds(30), sinceRenewal: sinceRenewal) == renews)
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
