import Foundation
@testable import SitRepCore
import SitRepLines
import Testing

/// What `watch` and `board --json` say of Snooze, from what the real CLI printed (`Lines.snoozed`): the Snoozed rows
/// apart from the rest, each ask's `snoozedUntil`, each session's and project's `snoozed`; and what a CLI from before
/// Snooze printed, without them.
struct SnoozedTests {
    private static func at(_ milliseconds: Double) -> Date {
        Date(timeIntervalSince1970: milliseconds / 1000)
    }

    private static func line(_ place: Int) throws -> Board {
        try Board.read(Lines.snoozed[place])
    }

    @Test func aSnoozedRowIsItsSessionItsAsksAsleepTheSoonestFirstAndWhenTheSoonestWakes() throws {
        let row = try #require(try Self.line(0).snoozed.first)

        #expect(row.session == "sr-4g01a7")
        #expect(row.isAway)
        #expect(row.project == "harness")
        #expect(row.name == "Finish the Harness modernisation")
        #expect(row.projectName == "Harness")
        #expect(row.letters == "Ha")
        #expect(row.second == "No window holds it. Carry it on in Claude.")
        #expect(row.lines.map(\.key) == ["ask:sr-4g01a7:k1", "ask:sr-4g01a7:k2"])
        #expect(row.lines.map(\.ask) == ["k1", "k2"])
        #expect(row.lines.map(\.first.lead) == ["Review the plan", "Pick when stage 2 runs"])
        #expect(row.lines.map(\.since) == [Self.at(1_792_740_927_000), Self.at(1_792_741_027_000)])
        #expect(row.lines.map(\.wakesAt) == [Self.at(1_792_741_532_000), Self.at(1_792_745_127_000)])
        #expect(row.wakesAt == Self.at(1_792_741_532_000))
    }

    /// The session in Snoozed has its row in Needs you too, for the ask still waiting.
    @Test func theSnoozedRowsAreApartFromTheRows() throws {
        let board = try Self.line(0)

        #expect(board.rows.map(\.session) == ["sr-4g01a7"])
        #expect(board.rows[0].lines.map(\.ask) == ["k3"])
        #expect(board.head.needYou == 1)
    }

    @Test func eachAskSaysWhenItWakesWhileItSleeps() throws {
        let asks = try #require(try Self.line(0).projects.first?.sessions.first?.asks)

        #expect(asks.map(\.snoozedUntil) == [Self.at(1_792_741_532_000), Self.at(1_792_745_127_000), nil])
        #expect(try SessionBoard.read(Lines.snoozedBoard).asks.map(\.snoozedUntil) == asks.map(\.snoozedUntil))
    }

    @Test func aSessionAndItsProjectCountTheirAsksAsleepApartFromThoseWaiting() throws {
        let project = try #require(try Self.line(0).projects.first)

        #expect((project.waiting, project.snoozed) == (1, 2))
        #expect(project.sessions.map { [$0.waiting, $0.snoozed] } == [[1, 2]])
        #expect(try Self.line(2).projects.map { [$0.waiting, $0.snoozed] } == [[3, 0]])
    }

    /// k1 woken at its time comes back to Needs you new; k2 woken by Lee comes back new on no line.
    @Test func aWakeAtItsTimeIsNewAndAWakeNowIsNot() throws {
        let timed = try Self.line(1), now = try Self.line(2)

        #expect(timed.new == ["ask:sr-4g01a7:k1"])
        #expect(timed.newRows == ["sr-4g01a7"])
        #expect(timed.snoozed.map { $0.lines.map(\.ask) } == [["k2"]])
        #expect(now.new.isEmpty)
        #expect(now.newRows.isEmpty)
        #expect(now.rows[0].lines.map(\.ask) == ["k1", "k2", "k3"])
        #expect(now.snoozed.isEmpty)
    }

    /// A CLI from before Snooze printed none of it: no Snoozed rows, no ask asleep, none counted.
    @Test func outputFromBeforeSnoozeReadsWithNoneAsleep() throws {
        let board = try Board.read(Lines.watch[0])

        #expect(board.snoozed.isEmpty)
        #expect(board.projects.allSatisfy { $0.snoozed == 0 && $0.sessions.allSatisfy { $0.snoozed == 0 } })
        #expect(board.projects.flatMap(\.sessions).flatMap(\.asks).allSatisfy { $0.snoozedUntil == nil })
        #expect(try SessionBoard.read(Lines.board).asks.allSatisfy { $0.snoozedUntil == nil })
    }
}
