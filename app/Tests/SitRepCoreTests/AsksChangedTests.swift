import Foundation
@testable import SitRepCore
import SitRepTestSupport
import Testing

/// The asks a line shows edited while they wait on Lee, whose banners then go, as their buttons would answer what the
/// ask no longer asks (DESIGN, "Its buttons"): a new title, yes, options or shape; only as the line comes, against the
/// board kept; none where a line's projects do not read, nor on the first line SitRep hears.
@Suite(.backstop)
struct AsksChangedTests {
    private static let noon = Date(timeIntervalSince1970: 1_792_445_600)
    private static let deploy = WatchLine.Ask(id: "k1", wants: .yes, yes: "Go", title: "Deploy to staging?")
    private static let k1 = AskOf(session: "sr-nw0001", ask: "k1")

    /// The last board after hearing each of what is given in turn, a minute apart from noon, in one run.
    private static func after(_ heard: Heard...) -> LastBoard {
        var last = LastBoard()

        last.begin()
        for (minute, said) in heard.enumerated() {
            _ = last.hear(said, at: noon.addingTimeInterval(Double(minute) * 60))
        }

        return last
    }

    /// Northwind's Ledger export holding these asks.
    private static func holding(_ asks: WatchLine.Ask...) -> Heard {
        .line(line(asks))
    }

    private static func line(_ asks: [WatchLine.Ask]) -> String {
        WatchLine(projects: [WatchLine.Project(sessions: [WatchLine.Session(asks: asks)])]).text
    }

    /// The staging deploy, edited as Claude may: retitled for production, its yes, wanting words, a choice.
    @Test(arguments: [
        WatchLine.Ask(id: "k1", wants: .yes, yes: "Go", title: "Deploy to production?"),
        WatchLine.Ask(id: "k1", wants: .yes, yes: "Ship it", title: "Deploy to staging?"),
        WatchLine.Ask(id: "k1", wants: .words, yes: nil, title: "Deploy to staging?"),
        WatchLine.Ask(id: "k1", wants: .choice, yes: nil, title: "Deploy to staging?", options: ["Go"]),
    ])
    func anAskEditedWhileItWaitsHasChanged(edited: WatchLine.Ask) {
        let last = Self.after(Self.holding(Self.deploy), Self.holding(edited))

        #expect(last.asksChanged == [Self.k1])
        #expect(last.asksLeft.isEmpty, "it still waits")
    }

    @Test func aChoiceGivenOtherOptionsHasChanged() {
        let choice = WatchLine.Ask(id: "k1", wants: .choice, yes: nil, options: ["Left", "Right"])
        let reordered = WatchLine.Ask(id: "k1", wants: .choice, yes: nil, options: ["Right", "Left"])
        let fewer = WatchLine.Ask(id: "k1", wants: .choice, yes: nil, options: ["Left"])

        #expect(Self.after(Self.holding(choice), Self.holding(reordered)).asksChanged == [Self.k1])
        #expect(Self.after(Self.holding(choice), Self.holding(fewer)).asksChanged == [Self.k1])
    }

    /// An ask as it was, or edited only in what its banner never shows, Claude's pick, what it needs or where, keeps
    /// its banner, line after line.
    @Test func anAskUnchangedOrChangedOnlyOffItsBannerKeepsIt() {
        let choice = WatchLine.Ask(id: "k1", wants: .choice, yes: nil, options: ["Left", "Right"])
        let picked = WatchLine.Ask(
            id: "k1", wants: .choice, yes: nil, where: "the guide", options: ["Left", "Right"], recommended: "Right",
            needs: "a look at both"
        )
        let unchanged = Self.after(Self.holding(Self.deploy), Self.holding(Self.deploy), Self.holding(Self.deploy))

        #expect(unchanged.asksChanged.isEmpty)
        #expect(Self.after(Self.holding(choice), Self.holding(picked)).asksChanged.isEmpty)
    }

    /// Only as the line comes: the next line, the same, leaves none.
    @Test func onlyTheLineThatChangesItSaysSo() {
        let retitled = WatchLine.Ask(id: "k1", wants: .yes, yes: "Go", title: "Deploy to production?")

        #expect(Self.after(Self.holding(Self.deploy), Self.holding(retitled), Self.holding(retitled)).asksChanged.isEmpty)
    }

    /// SitRep's very first line has no board kept to tell what changed.
    @Test func theFirstLineSitRepHearsChangesNothing() {
        #expect(Self.after(Self.holding(Self.deploy)).asksChanged.isEmpty)
    }

    /// A restarted run's first line tells what changed against the board the last run left.
    @Test func aRestartedRunsFirstLineTellsWhatChangedSinceTheLastRun() {
        var last = LastBoard()

        last.begin()
        _ = last.hear(Self.holding(Self.deploy), at: Self.noon)
        _ = last.hear(.exited(.status(1), stderr: ""), at: Self.noon.addingTimeInterval(60))
        last.begin()
        _ = last.hear(
            Self.holding(WatchLine.Ask(id: "k1", wants: .yes, yes: "Go", title: "Deploy to production?")),
            at: Self.noon.addingTimeInterval(120)
        )

        #expect(last.isRunsFirst)
        #expect(last.asksChanged == [Self.k1])
    }

    /// A line whose projects do not read says nothing of its asks, nor does the readable line after it tell a change
    /// against it.
    @Test func aLineWhoseProjectsDoNotReadChangesNothing() {
        let retitled = Self.line([WatchLine.Ask(id: "k1", wants: .yes, yes: "Go", title: "Deploy to production?")])
        let unread = retitled.replacingOccurrences(of: #""projects":["#, with: #""projects":[7,"#)

        #expect(unread != retitled)
        #expect(Self.after(Self.holding(Self.deploy), .line(unread)).asksChanged.isEmpty)
        #expect(Self.after(Self.holding(Self.deploy), .line(unread), .line(retitled)).asksChanged.isEmpty)
    }

    /// An ask new on the line, or one that waits on Lee no more, has not changed: the one is new, the other left.
    @Test func anAskNewOrNoLongerWaitingHasNotChanged() {
        let answered = WatchLine.Ask(
            id: "k1", wants: .yes, yes: "Go", title: "Deploy to production?", reply: .init(.onItsWay)
        )
        let added = Self.after(Self.holding(Self.deploy), Self.holding(Self.deploy, WatchLine.Ask(id: "k2")))
        let left = Self.after(Self.holding(Self.deploy), Self.holding(answered))

        #expect(added.asksChanged.isEmpty)
        #expect(left.asksChanged.isEmpty)
        #expect(left.asksLeft == [Self.k1])
    }
}
