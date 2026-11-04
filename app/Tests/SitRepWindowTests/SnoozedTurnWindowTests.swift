import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// A turn snoozed in the SitRep window, over what the real CLI printed (`Lines.snoozedTurn`): its row in Snoozed, out
/// of Your turn, with when it wakes, none until it moves; VoiceOver reading it as a snoozed ask, "until it moves" where
/// it has no time, and offering Wake now; and a your-turn row offering its menu's snoozes, Until it moves among them.
struct SnoozedTurnWindowTests {
    /// When the real `watch` printed its first line here: 19:19 in London on Wednesday 4 November 2026.
    private static let now = Date(timeIntervalSince1970: 1_793_819_990.622)
    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// The rows the window lists over `watch`'s first line.
    private static func rows() -> [Listed.Row] {
        let run = WindowRun(wall: { Self.now })

        run.show(heard(.line(Lines.snoozedTurn[0])), at: Self.now, reducesMotion: false)
        return run.listed(at: Self.now).rows
    }

    private static func row(_ session: String) throws -> Listed.Row {
        try #require(rows().first { $0.id == session })
    }

    @Test func aSnoozedTurnIsARowInSnoozedOutOfYourTurnWithWhenItWakes() {
        let rows = Self.rows()

        #expect(rows.map(\.id) == ["sr-fbrk3m", "sr-ctnbd2", "sr-nwtrn5"])
        #expect(rows.map(\.section) == [.yourTurn, .snoozed, .snoozed])
        #expect(rows.allSatisfy { $0.isTurn })
        #expect(rows.map(\.wakesAt) == [nil, Date(timeIntervalSince1970: 1_793_869_200), nil])
        #expect(rows.map(\.since) == [1_793_817_590, 1_793_819_270, 1_793_818_490].map(Date.init(timeIntervalSince1970:)))
        #expect(rows.map { $0.lines.map(\.ask) } == [[nil], [nil], [nil]])
    }

    /// Read as a snoozed ask: its line, what Claude left Lee, its project and its session, then when it wakes, or
    /// "until it moves"; and Wake now offered.
    @Test func voiceOverReadsASnoozedTurnAsASnoozedAskAndOffersWakeNow() throws {
        let timed = try Self.row("sr-ctnbd2"), moving = try Self.row("sr-nwtrn5")

        #expect(Spoken.row(timed, at: Self.now, in: Self.london)
            == "Rework the onboarding flow, Contoso, Onboarding flow, wakes Thursday 09:00")
        #expect(Spoken.row(moving, at: Self.now, in: Self.london)
            == "Export the ledger to CSV, Northwind, Ledger export, until it moves")
        #expect(Spoken.wake(moving) == "Wake now")
        #expect(SnoozeTime.offered(forTurn: true).compactMap {
            Spoken.snooze($0, of: moving, at: Self.now, in: Self.london)
        }.isEmpty)
    }

    /// A your-turn row offers the three snoozes, then until it moves, with no time to wake at.
    @Test func voiceOverOffersAYourTurnRowItsSnoozesUntilItMovesLast() throws {
        let turn = try Self.row("sr-fbrk3m")

        #expect(SnoozeTime.offered(forTurn: true).compactMap { Spoken.snooze($0, of: turn, at: Self.now, in: Self.london) } == [
            "Snooze later today, wakes 22:19", "Snooze tomorrow, wakes Thursday 09:00",
            "Snooze next week, wakes Monday 09:00", "Snooze until it moves",
        ])
        #expect(Spoken.wake(turn) == nil)
    }
}
