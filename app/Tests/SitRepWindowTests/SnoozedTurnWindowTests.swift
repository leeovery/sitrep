import Foundation
@testable import SitRepCore
import SitRepLines
import SitRepPanel
@testable import SitRepWindow
import Testing

/// A turn snoozed in the SitRep window, over what the real CLI printed (`Lines.snoozedTurn`): a row under Needs you's
/// "N snoozed", among the asks asleep and counted with them, out of Your turn, its mark the faint ring, its time when it
/// wakes or "until it moves"; a session's asks and its turn asleep two rows, each its own, acting on their session;
/// VoiceOver reading it as an ask asleep and offering Wake now; a Your turn row offering its menu's snoozes, Until it
/// moves among them; and a pick let go as its row moves, snoozed or woken.
struct SnoozedTurnWindowTests {
    /// When the real `watch` printed its first line here: 19:19 in London on Wednesday 4 November 2026.
    private static let now = Date(timeIntervalSince1970: 1_793_819_990.622)
    private static let contoso = ListPick.snoozed("turn:sr-ctnbd2")
    private static let northwind = ListPick.snoozed("turn:sr-nwtrn5")
    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// The board as `watch`'s line, its first unless another.
    private static func listed(_ line: String = Lines.snoozedTurn[0]) -> Listed {
        Listed(heard(.line(line)))
    }

    private static func needsYou(_ listed: Listed = listed()) -> PlaceList {
        PlaceList(.needsYou, in: listed, isFoldOpen: true)
    }

    private static func line(_ pick: ListPick) throws -> PlaceList.LineRow {
        try #require(needsYou().row(pick)?.lineRow)
    }

    /// A window open on `watch`'s line.
    private static func opened(_ line: String) -> WindowRun {
        let run = WindowRun(wall: { Self.now })

        run.show(heard(.line(line)), at: Self.now, reducesMotion: false)
        run.open()
        return run
    }

    @Test func aTurnAsleepIsARowUnderNSnoozedOutOfYourTurn() throws {
        let listed = Self.listed()
        let fold = try #require(Self.needsYou(listed).fold)

        #expect(fold.kind == .snoozed && fold.title == "2 snoozed")
        #expect(Spoken.fold(PlaceList(.needsYou, in: listed).fold!) == "2 snoozed, folded")
        #expect(Self.needsYou(listed).picks == [Self.contoso, Self.northwind])
        #expect(PlaceList(.yourTurn, in: listed).picks == [.session("sr-fbrk3m")])
        #expect(Places(listed).count(of: .yourTurn) == 1)
        #expect(Places(listed).count(of: .needsYou) == 0)
    }

    /// Its mark the faint ring, its words what Claude left Lee, its time its turn's end, and what its menu wakes its
    /// turn by that end.
    @Test func aTurnAsleepIsMarkedByTheFaintRingAndWakesByItsEnd() throws {
        let timed = try Self.line(Self.contoso), moving = try Self.line(Self.northwind)

        #expect([timed.mark, moving.mark] == [.snoozedTurn, .snoozedTurn])
        #expect(timed.isAsleep && timed.isTurn && timed.asks.isEmpty)
        #expect(timed.line.words == "Rework the onboarding flow")
        #expect(timed.line.wakesAt == Date(timeIntervalSince1970: 1_793_869_200))
        #expect(moving.line.wakesAt == nil)
        #expect(timed.snoozable == .turn(ended: Date(timeIntervalSince1970: 1_793_819_270)))
        #expect(PlaceList.Row.line(moving).snoozable == .turn(ended: Date(timeIntervalSince1970: 1_793_818_490)))
        #expect(Spoken.mark(.snoozedTurn) == "snoozed")
    }

    /// A session with its asks and its turn both asleep: two rows under "N snoozed", the turn's keyed apart from the
    /// asks', so no two share an id, the board's rows too; each acting on its session, its jump, its menu and its page.
    @Test func aSessionsAsksAndItsTurnAsleepAreTwoRowsEachItsOwn() throws {
        let both = edited(Lines.snoozedTurn[0]) { line in
            var rows = line["snoozed"] as! [[String: Any]]
            var asks = rows[1]

            asks["lines"] = [[
                "key": "ask:sr-nwtrn5:k1", "is": "ask", "ask": "k1", "since": 1_793_818_000_000,
                "wakesAt": 1_793_869_200_000,
                "first": ["lead": "Pick the export's columns", "mono": NSNull(), "subject": NSNull(), "more": NSNull(),
                          "until": NSNull()],
            ]]
            asks["wakesAt"] = 1_793_869_200_000
            rows.insert(asks, at: 1)
            line["snoozed"] = rows
        }
        let listed = Self.listed(both)
        let list = Self.needsYou(listed)
        let ids = list.items.map(\.id)

        #expect(list.picks == [.snoozed("ask:sr-nwtrn5:k1"), Self.contoso, Self.northwind])
        #expect(Set(ids).count == ids.count)
        #expect(list.shown.map { $0.lineRow?.mark } == [.snoozed, .snoozedTurn, .snoozedTurn])
        #expect(listed.rows(in: .snoozed).map(\.id) == ["turn:sr-ctnbd2", "sr-nwtrn5", "turn:sr-nwtrn5"])
        #expect(list.shown.map(\.session) == ["sr-nwtrn5", "sr-ctnbd2", "sr-nwtrn5"])
        #expect(list.selection(of: Self.northwind)?.session == "sr-nwtrn5")
    }

    /// Read as an ask asleep: its line, its project and its session, then when it wakes, or "until it moves"; Wake now
    /// offered, and no snooze.
    @Test func voiceOverReadsATurnAsleepAsAnAskAsleepAndOffersWakeNow() throws {
        let timed = try Self.line(Self.contoso), moving = try Self.line(Self.northwind)

        #expect(Spoken.line(timed, at: Self.now, in: Self.london)
            == "Rework the onboarding flow, Contoso, Onboarding flow, wakes Thursday 09:00")
        #expect(Spoken.line(moving, at: Self.now, in: Self.london)
            == "Export the ledger to CSV, Northwind, Ledger export, until it moves")
        #expect(Spoken.wake(.line(moving)) == "Wake now")
        #expect(SnoozeTime.offered(forTurn: true).compactMap {
            Spoken.snooze($0, of: .line(moving), at: Self.now, in: Self.london)
        }.isEmpty)
    }

    /// A Your turn row offers the three snoozes, then until it moves, for its turn by its end; a Working row none.
    @Test func voiceOverOffersAYourTurnRowItsSnoozesUntilItMovesLast() throws {
        let turn = try #require(PlaceList(.yourTurn, in: Self.listed()).rows.first)
        let snoozes = { (row: PlaceList.Row) in
            SnoozeTime.offered(forTurn: true).compactMap { Spoken.snooze($0, of: row, at: Self.now, in: Self.london) }
        }
        let working = PlaceList.Row.session(Listed.Row(
            id: "sr-kit", session: "sr-kit", name: "Kit", project: "Kit", section: .working, mark: .working,
            isAway: false, since: Self.now,
            lines: [Listed.Line(id: "sr-kit", lead: "Running", code: "swift test", more: nil, since: Self.now)]
        ))

        #expect(snoozes(turn) == [
            "Snooze later today, wakes 22:19", "Snooze tomorrow, wakes Thursday 09:00",
            "Snooze next week, wakes Monday 09:00", "Snooze until it moves",
        ])
        #expect(turn.snoozable == .turn(ended: Date(timeIntervalSince1970: 1_793_817_590)))
        #expect(Spoken.wake(turn) == nil)
        #expect(working.snoozable == nil && snoozes(working).isEmpty)
    }

    // MARK: The pick

    /// Snoozed, a Your turn row picked leaves Your turn for "N snoozed", so its pick is let go, as a line picked and
    /// snoozed is: Your turn shows it picked no more, ↓ goes on from where it stood, and the page stays on its session.
    @Test func aYourTurnRowPickedAndSnoozedIsLetGoItsPageStaying() throws {
        let run = Self.opened(Lines.snoozedTurn[1])
        let contoso = ListPick.session("sr-ctnbd2")

        run.click(.place(.yourTurn))
        #expect(run.pickInList(contoso, at: Self.now))
        run.show(heard(.line(Lines.snoozedTurn[0])), at: Self.now, reducesMotion: false)
        #expect(run.location.picked?.pick == contoso)
        #expect(try #require(run.list(at: Self.now)).position(of: contoso) == nil)
        #expect(run.page(at: Self.now).session?.id == "sr-ctnbd2")
        run.step(down: true, at: Self.now)
        #expect(run.location.picked?.pick == .session("sr-fbrk3m"))
    }

    /// Woken, a turn asleep picked leaves "N snoozed" for Your turn, so its pick is let go, as any pick whose row
    /// leaves the list: Needs you shows it picked no more, and the page stays on its session.
    @Test func aTurnAsleepPickedAndWokenIsLetGoItsPageStaying() throws {
        let run = Self.opened(Lines.snoozedTurn[0])

        run.toggleFold(of: .needsYou)
        #expect(run.pickInList(Self.contoso, at: Self.now))
        #expect(run.location.picked?.session == "sr-ctnbd2")
        run.show(heard(.line(Lines.snoozedTurn[1])), at: Self.now, reducesMotion: false)
        #expect(run.location.picked?.pick == Self.contoso)
        #expect(try #require(run.list(at: Self.now)).position(of: Self.contoso) == nil)
        #expect(run.page(at: Self.now).session?.id == "sr-ctnbd2")
    }
}
