import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepTestSupport
import Testing

/// The asks a line leaves no longer waiting on Lee, whose banners then go (DESIGN, "The menu bar"): answered, ignored,
/// resolved, or gone with their session; only as the line comes, against the board kept, the last run's among them;
/// none where a line's projects do not read.
@Suite(.backstop)
struct AsksLeftTests {
    private static let noon = Date(timeIntervalSince1970: 1_792_445_600)

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
    private static func holding(_ asks: [WatchLine.Ask]) -> Heard {
        .line(WatchLine(projects: [WatchLine.Project(sessions: [WatchLine.Session(asks: asks)])]).text)
    }

    /// Northwind holding these sessions.
    private static func listing(_ sessions: [WatchLine.Session]) -> Heard {
        .line(WatchLine(projects: [WatchLine.Project(sessions: sessions)]).text)
    }

    /// The real CLI's lines: the yes answered and the words ask ignored, both on their way, wait on Lee no more.
    @Test func anAskAnsweredOrIgnoredLeaves() {
        let last = Self.after(.line(Lines.watch[0]), .line(Lines.watch[1]))

        #expect(last.asksLeft == [AskOf(session: "sr-m4h6qe", ask: "k1"), AskOf(session: "sr-m4h6qe", ask: "k3")])
    }

    @Test func anAskResolvedOrGoneWithItsSessionLeaves() {
        let resolved = Self.after(
            Self.holding([WatchLine.Ask(id: "k1"), WatchLine.Ask(id: "k2")]),
            Self.holding([WatchLine.Ask(id: "k1"), WatchLine.Ask(id: "k2", state: .closed)])
        )
        let ledger = WatchLine.Session(asks: [WatchLine.Ask(id: "k1")])
        let invoices = WatchLine.Session(id: "sr-nw0002", name: "Invoice ledger", asks: [WatchLine.Ask(id: "k1")])
        let finished = Self.after(Self.listing([ledger, invoices]), Self.listing([invoices]))

        #expect(resolved.asksLeft == [AskOf(session: "sr-nw0001", ask: "k2")])
        #expect(finished.asksLeft == [AskOf(session: "sr-nw0001", ask: "k1")])
    }

    /// A line whose projects are missing, or do not read, says nothing of its asks: no banner goes for one still
    /// waiting, which the watch would never post again; nor on the readable line after it.
    @Test(arguments: [(#""projects":"#, #""projectz":"#), (#""projects":["#, #""projects":[7,"#)])
    func aLineWhoseProjectsDoNotReadLeavesNothing(projects: String, broken: String) throws {
        let waiting = WatchLine(projects: [WatchLine.Project(sessions: [WatchLine.Session(asks: [WatchLine.Ask()])])])
        let unread = waiting.text.replacingOccurrences(of: projects, with: broken)
        let last = Self.after(.line(waiting.text), .line(unread))

        #expect(unread != waiting.text)
        #expect(try #require(last.board).waitingOnLee == nil, "its projects read")
        #expect(last.asksLeft.isEmpty)
        #expect(Self.after(.line(waiting.text), .line(unread), .line(waiting.text)).asksLeft.isEmpty)
    }

    /// Only as the line comes: the next line, or `watch` ending, leaves none; nor does the first line SitRep hears,
    /// with no board kept to tell what left.
    @Test func onlyTheLineThatLeavesThemSaysSo() {
        let again = Self.after(.line(Lines.watch[0]), .line(Lines.watch[1]), .line(Lines.watch[1]))
        let ended = Self.after(.line(Lines.watch[0]), .line(Lines.watch[1]), .exited(.status(1), stderr: ""))

        #expect(again.asksLeft.isEmpty)
        #expect(ended.asksLeft.isEmpty)
        #expect(Self.after(.line(Lines.watch[1])).asksLeft.isEmpty)
    }

    /// A restarted run's first line tells what left against the board the last run left, as asks may leave between
    /// the runs.
    @Test func aRestartedRunsFirstLineTellsWhatLeftSinceTheLastRun() {
        var last = LastBoard()

        last.begin()
        _ = last.hear(.line(Lines.watch[0]), at: Self.noon)
        _ = last.hear(.exited(.status(1), stderr: ""), at: Self.noon.addingTimeInterval(60))
        last.begin()
        _ = last.hear(.line(Lines.watch[1]), at: Self.noon.addingTimeInterval(120))

        #expect(last.isRunsFirst)
        #expect(last.asksLeft == [AskOf(session: "sr-m4h6qe", ask: "k1"), AskOf(session: "sr-m4h6qe", ask: "k3")])
    }

    /// An ask that came in, or still waits, leaves nothing.
    @Test func anAskStillWaitingOrNewLeavesNothing() {
        let last = Self.after(
            Self.holding([WatchLine.Ask(id: "k1")]), Self.holding([WatchLine.Ask(id: "k1"), WatchLine.Ask(id: "k2")])
        )

        #expect(last.asksLeft.isEmpty)
    }
}
