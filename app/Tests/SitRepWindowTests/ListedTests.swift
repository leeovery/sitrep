import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// The board as the window takes it, from what the real `watch` printed: a row for each of core's, in its section,
/// each session once; and every project.
struct ListedTests {
    private static let listed = Listed(heard(line(0)))
    /// Harness's three asks, Switchboard's ask and prompt and Goosemates' away ask; SitRep working, Kit on its own work;
    /// Fumi's turn.
    private static let bySession = Listed(heard(.line(Lines.bySession[0])))

    @Test func eachSessionHasOneRowInItsSectionInCoresOrder() {
        #expect(Self.bySession.rows.map(\.id) == [
            "sr-4g01a7", "sr-dash02", "sr-gs7kq2", "sr-macapp", "sr-k7bt2s", "sr-v3t7a0",
        ])
        #expect(Self.bySession.rows.map(\.section) == [.needsYou, .needsYou, .needsYou, .working, .working, .yourTurn])
        #expect(Self.bySession.needsYou.map(\.id) == ["sr-4g01a7", "sr-dash02", "sr-gs7kq2"])
    }

    /// Goosemates' ask, which no window holds, takes the away ring.
    @Test func aRowTakesItsMarkFromItsLineAndNamesItsProject() {
        #expect(Self.bySession.rows.map(\.mark) == [.needs, .needs, .awayAsk, .working, .onItsWork, .turn])
        #expect(Self.bySession.rows.map(\.isAway) == [false, false, true, false, false, false])
        #expect(Self.bySession.rows.map(\.project) == ["Harness", "Switchboard", "Goosemates", "SitRep", "Kit", "Fumi"])
    }

    /// A working row's verb and what it acts on, a your-turn row's words, each its one line.
    @Test func aRowsLinesAreCoresWithTheirWords() {
        let rows = Self.bySession.rows

        #expect(rows.map(\.lines.count) == [3, 2, 1, 1, 1, 1])
        #expect(rows[3].lines.map(\.words) == ["Grouping the rows by session"])
        #expect(rows[4].lines.map(\.words) == ["Waiting on 3 agents"])
        #expect(rows[5].lines.map(\.words) == ["Comparing licence servers"])
        #expect(rows[1].lines.map(\.words) == ["Paste the load test's output", "Allow Bash gh pr create --draft"])
    }

    /// Kit's window waits on a wake 12 minutes off: its line counts down to it.
    @Test func aWakesLineCountsDownToIt() throws {
        let listed = Listed(heard(.line(Lines.onItsWork)))
        let kit = try #require(listed.rows.first { $0.id == "sr-k7bt2s" }?.lines.first)
        let board = try Board.read(Lines.onItsWork)

        #expect(kit.lead == "Wakes")
        #expect(kit.subject(at: board.at) == "in 12m")
    }

    @Test func everyProjectOnTheBoardIsListedQuietOnesTooInWatchsOrder() {
        #expect(Self.listed.projects.map(\.name) == ["SitRep", "Switchboard", "Goosemates", "Kit"])
        #expect(Self.listed.projects.map(\.id) == ["sitrep", "switchboard", "goosemates", "kit"])
    }

    /// Kit's away session waits on nothing, so core has no row for it: it is reached by its project's page.
    @Test func anAwaySessionWithNothingWaitingHasNoRow() {
        #expect(!Self.listed.rows.contains { $0.id == "sr-k7t001" })
        #expect(Self.listed.homes["sr-k7t001"] == "kit")
    }

    @Test func aRowsTimeIsItsOldestLines() throws {
        let ledger = try #require(Self.listed.rows.first { $0.id == "sr-rq7dgr" })

        #expect(ledger.since == minutes(before: 12))
    }

    @Test func theHeadSaysWhatNeedsLeeAsThePanelsDoes() {
        #expect(Self.listed.head == Head(needYou: 6, sessions: 4))
    }

    @Test func staleTheHeadSaysWhenTheBoardWasLastKnownCurrent() {
        let stale = Listed(heard(line(0), .exited(.status(1), stderr: "")))

        #expect(stale.head.title == "6 need you")
        #expect(stale.head.count.hasPrefix("as of "))
        #expect(stale.projects.count == 4)
    }
}
