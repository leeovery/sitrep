@testable import SitRepCore
import SitRepMenu
import Testing

struct NoticesTests {
    private static let newAsk = Watched.line(new: ["ask:sr-ledger:k1"])
    /// A board after the run's first, with the ask new on it.
    private static let asked = heard([.line(Watched.line(rows: [])), .line(newAsk)])

    @Test func aNewAskSendsItsTitleItsProjectAndSessionSilentlyJumpingToIt() {
        #expect(Notices.due(Self.asked, isOn: true) == [
            Banner(title: "Choose how long the ledger keeps requests", subtitle: "Switchboard · Usage", body: "", work: "sr-ledger"),
        ])
    }

    @Test func withTheSwitchOffNothingIsSent() {
        #expect(Notices.due(Self.asked, isOn: false).isEmpty)
    }

    @Test func aWindowsNewStopSendsNothing() {
        let stopped = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["stop:sr-dash:w1:1792445500000"]))])

        #expect(Notices.due(stopped, isOn: true).isEmpty)
    }

    @Test func eachNewAskSendsItsOwn() {
        let both = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["ask:sr-ledger:k1", "ask:sr-plan:k2"]))])

        #expect(Notices.due(both, isOn: true).map(\.title) == ["Choose how long the ledger keeps requests", "Pick the plan's shape"])
    }

    @Test func anAwayAsksNoticeNamesItsSessionAndJumpsNowhere() {
        let away = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["ask:sr-plan:k2"]))])

        #expect(Notices.due(away, isOn: true) == [
            Banner(title: "Pick the plan's shape", subtitle: "Terrace · Plan the tool", body: "", work: nil),
        ])
    }

    @Test func aRunsFirstBoardSendsNothingThoughItCarriedNew() {
        #expect(Notices.due(heard([.line(Self.newAsk)]), isOn: true).isEmpty)
    }

    @Test func aResumedBoardSendsNothing() {
        let resumed = heard([.line(Watched.line(rows: [])), .exited(.status(1), stderr: "")], [.line(Self.newAsk)])

        #expect(resumed.isResumed)
        #expect(Notices.due(resumed, isOn: true).isEmpty)
    }

    @Test func afterARunsFirstLineThatDidNotReadTheNextLinesNewAskIsSent() {
        let after = heard([.line(Watched.line(rows: [])), .exited(.status(1), stderr: "")], [.line("{"), .line(Self.newAsk)])

        #expect(after.isResumed)
        #expect(Notices.due(after, isOn: true).map(\.work) == ["sr-ledger"])
    }

    @Test func aStaleBoardSendsNothingAgain() {
        let stale = heard([.line(Watched.line(rows: [])), .line(Self.newAsk), .exited(.status(1), stderr: "")])

        #expect(Notices.due(stale, isOn: true).isEmpty)
    }

    @Test func theTestNoticeIsOfTheFirstRowAWindowHoldsAndJumpsToIt() {
        let test = Notices.test(heard([.line(Watched.line())]))

        #expect(test.title == "Choose how long the ledger keeps requests")
        #expect(test.subtitle == "Switchboard · Usage")
        #expect(test.work == "sr-ledger")
    }

    @Test func withNoRowAWindowHoldsTheTestNoticeJumpsNowhere() {
        let test = Notices.test(heard([.line(Watched.line(rows: [Watched.rows[2]]))]))

        #expect(test.work == nil)
        #expect(test.body == "A test notification. No window holds a session, so it jumps nowhere.")
    }
}
