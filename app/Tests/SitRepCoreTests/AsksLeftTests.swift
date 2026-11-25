import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepTestSupport
import Testing

/// The asks a line leaves no longer waiting on Lee, whose banners then go (DESIGN, "Its buttons"): answered, ignored,
/// resolved, or gone with their session; only as the line comes.
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
        let finished = Self.after(Self.holding([WatchLine.Ask(id: "k1")]), .line(WatchLine().text))

        #expect(resolved.asksLeft == [AskOf(session: "sr-nw0001", ask: "k2")])
        #expect(finished.asksLeft == [AskOf(session: "sr-nw0001", ask: "k1")])
    }

    /// Only as the line comes: the next line, or `watch` ending, leaves none; nor does a run's first.
    @Test func onlyTheLineThatLeavesThemSaysSo() {
        let again = Self.after(.line(Lines.watch[0]), .line(Lines.watch[1]), .line(Lines.watch[1]))
        let ended = Self.after(.line(Lines.watch[0]), .line(Lines.watch[1]), .exited(.status(1), stderr: ""))

        #expect(again.asksLeft.isEmpty)
        #expect(ended.asksLeft.isEmpty)
        #expect(Self.after(.line(Lines.watch[1])).asksLeft.isEmpty)
    }

    /// An ask that came in, or still waits, leaves nothing.
    @Test func anAskStillWaitingOrNewLeavesNothing() {
        let last = Self.after(
            Self.holding([WatchLine.Ask(id: "k1")]), Self.holding([WatchLine.Ask(id: "k1"), WatchLine.Ask(id: "k2")])
        )

        #expect(last.asksLeft.isEmpty)
    }
}
