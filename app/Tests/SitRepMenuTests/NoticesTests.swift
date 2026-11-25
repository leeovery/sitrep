@testable import SitRepCore
import SitRepMenu
import SitRepTestSupport
import Testing

@Suite(.backstop)
struct NoticesTests {
    private static let newAsk = Watched.line(new: ["ask:sr-l5c9tz:k1"])
    /// A board after the run's first, with the ask new on it.
    private static let asked = heard([.line(Watched.line(rows: [])), .line(newAsk)])

    /// A board after the run's first, Northwind's Ledger export holding these asks, its row's line for the ask with
    /// this id new on it.
    private static func asking(_ asks: [WatchLine.Ask], line ask: String? = "k2") -> LastBoard {
        let row = WatchLine.Row(
            session: "sr-nw0001", name: "Ledger export", projectName: "Northwind",
            lines: [.init("ask:sr-nw0001:k2", .ask, ask: ask, first: "Pick the export format")]
        )
        let line = WatchLine(
            rows: [row], projects: [WatchLine.Project(sessions: [WatchLine.Session(asks: asks)])],
            new: ["ask:sr-nw0001:k2"]
        )

        return heard([.line(Watched.line(rows: [])), .line(line.text)])
    }

    @Test func aNewAskSendsItsTitleItsProjectAndSessionSilentlyJumpingToIt() {
        #expect(Notices.due(Self.asked, .notifyingAsks) == [
            Banner(title: "Choose how long the archive keeps reports", subtitle: "Woodgrove · Usage", body: "", work: "sr-l5c9tz"),
        ])
    }

    @Test func withTheSwitchOffNothingIsSent() {
        #expect(Notices.due(Self.asked, AppSettings()).isEmpty)
    }

    @Test func aWindowsNewStopSendsNothing() {
        let stopped = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["stop:sr-dash:w1:1792445500000"]))])

        #expect(Notices.due(stopped, .notifyingAsks).isEmpty)
    }

    /// Each its own, the oldest first, so Notification Center stacks the newest on top: Humongous's ask, older, though
    /// core lists it after Woodgrove's.
    @Test func eachNewAskSendsItsOwnTheOldestFirst() {
        let both = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["ask:sr-l5c9tz:k1", "ask:sr-plan:k2"]))])

        #expect(Notices.due(both, .notifyingAsks).map(\.title) == [
            "Pick the plan's shape", "Choose how long the archive keeps reports",
        ])
    }

    /// Its click goes to its session, as any notice's does, for the jump to carry it on (stage 8).
    @Test func anAwayAsksNoticeNamesItsSessionAndJumpsToIt() {
        let away = heard([.line(Watched.line(rows: [])), .line(Watched.line(new: ["ask:sr-plan:k2"]))])

        #expect(Notices.due(away, .notifyingAsks) == [
            Banner(title: "Pick the plan's shape", subtitle: "Humongous · Plan the launch", body: "", work: "sr-plan"),
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
        #expect(Notices.due(after, .notifyingAsks).map(\.work) == ["sr-l5c9tz"])
    }

    @Test func aStaleBoardSendsNothingAgain() {
        let stale = heard([.line(Watched.line(rows: [])), .line(Self.newAsk), .exited(.status(1), stderr: "")])

        #expect(Notices.due(stale, .notifyingAsks).isEmpty)
    }

    /// It tells of the ask its line names, whatever the ask wants, for the banner to be taken down by once the ask
    /// waits on Lee no more.
    @Test(arguments: [
        WatchLine.Ask(id: "k2", wants: .yes, yes: "Go"),
        WatchLine.Ask(id: "k2", wants: .choice, yes: nil, options: ["Left", "Right"], recommended: "Right"),
        WatchLine.Ask(id: "k2", wants: .words, yes: nil, needs: "the command's output"),
    ])
    func aNewAsksBannerTellsOfItsAsk(ask: WatchLine.Ask) {
        #expect(Notices.due(Self.asking([ask]), .notifyingAsks).map(\.ask) == [AskOf(session: "sr-nw0001", ask: "k2")])
    }

    /// A line naming no ask tells of none.
    @Test func aNewAsksBannerWhoseLineNamesNoAskTellsOfNone() {
        let banners = Notices.due(Self.asking([WatchLine.Ask(id: "k2")], line: nil), .notifyingAsks)

        #expect(banners.map(\.title) == ["Pick the export format"])
        #expect(banners.map(\.ask) == [nil])
    }

    /// Lee's turn's banner tells of no ask, nor does the test notification.
    @Test func noOtherBannerTellsOfAnAsk() {
        var settings = AppSettings.notifyingAsks

        settings.notifiesTurns = true

        let installer = { (line: WatchLine.Row.Line) in
            Heard.line(Watched.line(rows: [
                WatchLine.Row(session: "sr-boot", name: "The installer", projectName: "Litware", lines: [line]),
            ]))
        }
        let turned = Notices.due(heard([
            installer(.init("work:sr-boot", .working, first: "Writing", since: 1_792_445_000_000)),
            installer(.init("turn:sr-boot", .yourTurn, first: "Write round 4 into the spec")),
        ]), settings)

        #expect(turned.map(\.title) == ["Stopped"])
        #expect(turned.map(\.ask) == [nil])
        #expect(Notices.test.ask == nil)
    }

    @Test func theTestNoticeIsASampleThatJumpsNowhere() {
        #expect(Notices.test.title == "Test notification")
        #expect(Notices.test.subtitle == nil)
        #expect(Notices.test.body == "This is what SitRep's notifications look like.")
        #expect(Notices.test.work == nil)
    }
}
