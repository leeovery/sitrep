import Foundation
@testable import SitRepCore
import SitRepLines
import Testing

/// What `watch` says of a turn snoozed, from what the real CLI printed (`Lines.snoozedTurn`): a row of its own in
/// Snoozed, its line the turn's, keyed as on Your turn, with when it wakes, none until it moves, the soonest first; out
/// of Your turn while it sleeps, and back there woken, or once its session takes another turn.
struct SnoozedTurnTests {
    private static func line(_ place: Int) throws -> Board {
        try Board.read(Lines.snoozedTurn[place])
    }

    @Test func aSnoozedTurnIsARowOfItsOwnItsLineTheTurnsAndWhenItWakes() throws {
        let rows = try Self.line(0).snoozed
        let line = try #require(rows.first?.lines.first)

        #expect(rows.map(\.id) == ["turn:sr-ctnbd2", "turn:sr-nx7bky"])
        #expect(rows.allSatisfy { $0.isTurn })
        #expect(rows.map(\.name) == ["Onboarding flow", "Ledger export"])
        #expect(rows.map { $0.lines.count } == [1, 1])
        #expect(line.key == "turn:sr-ctnbd2")
        #expect(line.kind == .yourTurn)
        #expect(line.ask == nil)
        #expect(line.first.lead == "Rework the onboarding flow")
        #expect(line.since == at(1_793_819_270_000))
        #expect(line.wakesAt == at(1_793_869_200_000))
    }

    /// Until it moves, it has no time to wake at, and sorts after every snooze that has one.
    @Test func aTurnSnoozedUntilItMovesWakesAtNoTimeAndComesLast() throws {
        let row = try #require(try Self.line(0).snoozed.last)

        #expect(row.session == "sr-nx7bky")
        #expect(row.wakesAt == nil)
        #expect(row.lines.map(\.wakesAt) == [nil])
    }

    /// Its session leaves Your turn while its turn sleeps, and its count with it.
    @Test func aSnoozedTurnLeavesYourTurn() throws {
        let board = try Self.line(0)

        #expect(board.rows.map(\.session) == ["sr-fbrk3m"])
        #expect(board.head.sessions == 1)
    }

    /// Woken, Contoso's turn is back on Your turn; Northwind's window at a new turn ends its snooze, and its turn is
    /// back at the top.
    @Test func wokenOrMovedOnTheTurnIsBackOnYourTurn() throws {
        let woken = try Self.line(1), moved = try Self.line(2)

        #expect(woken.rows.map(\.session) == ["sr-ctnbd2", "sr-fbrk3m"])
        #expect(woken.snoozed.map(\.id) == ["turn:sr-nx7bky"])
        #expect(moved.rows.map(\.session) == ["sr-nx7bky", "sr-ctnbd2", "sr-fbrk3m"])
        #expect(moved.rows.map(\.section) == [.yourTurn, .yourTurn, .yourTurn])
        #expect(moved.snoozed.isEmpty)
    }

    /// A session snoozed whole since 13 November 2026 is one row, its asks and its turn among its lines: the session's
    /// row, keyed as any, no turn's of its own.
    @Test func aRowOfAsksAndATurnIsTheSessionsOwn() throws {
        let turn = #"{"key":"turn:sr-4t2kq8","is":"yourTurn","ask":null,"first":{"lead":"Stage 2 is in","mono":null,"subject":null,"more":null,"until":null},"since":1792741100000,"wakesAt":1792745127000}"#
        let line = Lines.snoozed[0].replacingOccurrences(of: #""wakesAt":1792745127000}]"#, with: #""wakesAt":1792745127000},\#(turn)]"#)
        let row = try #require(try Board.read(line).snoozed.first)

        #expect(row.lines.map(\.kind) == [.ask, .ask, .yourTurn])
        #expect(!row.isTurn)
        #expect(row.id == "sr-4t2kq8")
        #expect(row.wakesAt == at(1_792_741_532_000))
    }

    /// A CLI from before a turn could be snoozed said nothing of what a Snoozed line is: each is an ask.
    @Test func snoozedLinesFromBeforeTurnsAreAsks() throws {
        let row = try #require(try Board.read(Lines.snoozed[0]).snoozed.first)

        #expect(row.lines.map(\.kind) == [.ask, .ask])
        #expect(!row.isTurn)
        #expect(row.id == "sr-4t2kq8")
    }
}
