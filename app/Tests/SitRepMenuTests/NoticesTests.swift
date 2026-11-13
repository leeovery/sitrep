@testable import SitRepCore
import SitRepMenu
import Testing

struct NoticesTests {
    private static let newAsk = Watched.line(new: ["ask:sr-ledger:k1"])
    /// A board after the run's first, with the ask new on it.
    private static let asked = heard([.line(Watched.line(rows: [])), .line(newAsk)])

    @Test func aNewAskSendsItsTitleItsProjectAndSessionSilentlyJumpingToIt() {
        #expect(Notices.due(Self.asked, .notifyingAsks) == [
            Banner(title: "Choose how long the ledger keeps requests", subtitle: "Switchboard · Usage", body: "", work: "sr-ledger"),
        ])
    }

    @Test func withTheSwitchOffNothingIsSent() {
        #expect(Notices.due(Self.asked, AppSettings()).isEmpty)
    }

    @Test func aWindowsNewStopSendsNothing() {
        let stopped = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["stop:sr-dash:w1:1792445500000"]))])

        #expect(Notices.due(stopped, .notifyingAsks).isEmpty)
    }

    /// Each its own, the oldest first, so Notification Center stacks the newest on top: Terrace's ask, older, though
    /// core lists it after Switchboard's.
    @Test func eachNewAskSendsItsOwnTheOldestFirst() {
        let both = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["ask:sr-ledger:k1", "ask:sr-plan:k2"]))])

        #expect(Notices.due(both, .notifyingAsks).map(\.title) == [
            "Pick the plan's shape", "Choose how long the ledger keeps requests",
        ])
    }

    /// Its click goes to its session, as any notice's does, for the jump to carry it on (stage 8).
    @Test func anAwayAsksNoticeNamesItsSessionAndJumpsToIt() {
        let away = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["ask:sr-plan:k2"]))])

        #expect(Notices.due(away, .notifyingAsks) == [
            Banner(title: "Pick the plan's shape", subtitle: "Terrace · Plan the tool", body: "", work: "sr-plan"),
        ])
    }

    @Test func aRunsFirstBoardSendsNothingThoughItCarriedNew() {
        #expect(Notices.due(heard([.line(Self.newAsk)]), .notifyingAsks).isEmpty)
    }

    @Test func theFirstBoardOfARunAfterAnotherSendsNothing() {
        let restarted = heard([.line(Watched.line(rows: [])), .exited(.status(1), stderr: "")], [.line(Self.newAsk)])

        #expect(restarted.isRunsFirst)
        #expect(Notices.due(restarted, .notifyingAsks).isEmpty)
    }

    @Test func afterARunsFirstLineThatDidNotReadTheNextLinesNewAskIsSent() {
        let after = heard([.line(Watched.line(rows: [])), .exited(.status(1), stderr: "")], [.line("{"), .line(Self.newAsk)])

        #expect(!after.isRunsFirst)
        #expect(Notices.due(after, .notifyingAsks).map(\.work) == ["sr-ledger"])
    }

    @Test func aStaleBoardSendsNothingAgain() {
        let stale = heard([.line(Watched.line(rows: [])), .line(Self.newAsk), .exited(.status(1), stderr: "")])

        #expect(Notices.due(stale, .notifyingAsks).isEmpty)
    }

    @Test func theTestNoticeIsASampleThatJumpsNowhere() {
        #expect(Notices.test.title == "Test notification")
        #expect(Notices.test.subtitle == nil)
        #expect(Notices.test.body == "This is what SitRep's notifications look like.")
        #expect(Notices.test.work == nil)
    }
}
