import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepTestSupport
import Testing

/// What `watch` says of Snooze, from what the real CLI printed (`Lines.snoozed`): the Snoozed rows apart from the
/// rest; and what a CLI from before Snooze printed, without them.
@Suite(.backstop)
struct SnoozedTests {
    private static func line(_ place: Int) throws -> Board {
        try Board.read(Lines.snoozed[place])
    }

    @Test func aSnoozedRowIsItsSessionItsAsksAsleepTheSoonestFirstAndWhenTheSoonestWakes() throws {
        let row = try #require(try Self.line(0).snoozed.first)

        #expect(row.session == "sr-4t2kq8")
        #expect(row.isAway)
        #expect(row.project == "tailspin")
        #expect(row.name == "Finish the Tailspin migration")
        #expect(row.projectName == "Tailspin")
        #expect(row.letters == "Ta")
        #expect(row.second == "No window holds it. Carry it on in Claude.")
        #expect(row.lines.map(\.key) == ["ask:sr-4t2kq8:k1", "ask:sr-4t2kq8:k2"])
        #expect(row.lines.map(\.ask) == ["k1", "k2"])
        #expect(row.lines.map(\.first.lead) == ["Review the plan", "Pick when stage 2 runs"])
        #expect(row.lines.map(\.since) == [at(1_792_740_927_000), at(1_792_741_027_000)])
        #expect(row.lines.map(\.wakesAt) == [at(1_792_741_532_000), at(1_792_745_127_000)])
        #expect(row.wakesAt == at(1_792_741_532_000))
    }

    /// The session in Snoozed has its row in Needs you too, for the ask still waiting.
    @Test func theSnoozedRowsAreApartFromTheRows() throws {
        let board = try Self.line(0)

        #expect(board.rows.map(\.session) == ["sr-4t2kq8"])
        #expect(board.rows[0].lines.map(\.ask) == ["k3"])
        #expect(board.head.needYou == 1)
    }

    /// k1 woken at its time comes back to Needs you new; k2 woken by Lee comes back new on no line.
    @Test func aWakeAtItsTimeIsNewAndAWakeNowIsNot() throws {
        let timed = try Self.line(1), now = try Self.line(2)

        #expect(timed.new == ["ask:sr-4t2kq8:k1"])
        #expect(timed.newRows == ["sr-4t2kq8"])
        #expect(timed.snoozed.map { $0.lines.map(\.ask) } == [["k2"]])
        #expect(now.new.isEmpty)
        #expect(now.newRows.isEmpty)
        #expect(now.rows[0].lines.map(\.ask) == ["k1", "k2", "k3"])
        #expect(now.snoozed.isEmpty)
    }

    /// A CLI from before Snooze printed none of it: no Snoozed rows.
    @Test func outputFromBeforeSnoozeReadsWithNoneAsleep() throws {
        #expect(try Board.read(Lines.watch[0]).snoozed.isEmpty)
    }
}
