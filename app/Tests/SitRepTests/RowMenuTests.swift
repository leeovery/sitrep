import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepPanel
import Testing

/// A row's right-click menu on the card (Paper's boards F, G and I): Jump to the window, away too; then Snooze and
/// its three times on a Needs you row, its asks' or its turn's, or Wake now on a row in Snoozed; neither on a row of
/// stops alone. A snooze puts off the row's session, naming the asks the row showed as it was drawn (13 November 2026).
@MainActor
struct RowMenuTests {
    /// Friday 23 October 2026, 14:00 in London.
    private static let now = Date(timeIntervalSince1970: 1_792_760_400)
    /// The turn a your-turn row shows, ended at 13:12:07.5, ms.
    private static let ended = 1_792_757_527.5 * 1000
    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// What each choice was asked for, in the order chosen, and the asks each snooze named.
    private final class Heard {
        var said: [String] = []
        var named: [[String]] = []
    }

    private static func menu(_ row: RowMenu.Row, _ heard: Heard) -> NSMenu {
        RowMenu.make(
            for: row, at: now, in: london,
            RowMenu.Actions(
                jump: { heard.said.append("jump") },
                snooze: { heard.said.append("snooze \($1.title)"); heard.named.append($0) },
                wake: { heard.said.append("wake") }
            )
        )
    }

    private static func titles(_ menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "—" : $0.title }
    }

    private static func choices(_ menu: NSMenu) -> [String?] {
        menu.items.map { $0.isSeparatorItem ? "—" : $0.attributedTitle?.string }
    }

    @Test func aRowOfStopsAloneOffersJumpAlone() {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(asks: nil, isSnoozed: false), heard)

        #expect(Self.titles(menu) == ["Jump to the window"])
        #expect(menu.items.map(\.isEnabled) == [true])

        menu.performActionForItem(at: 0)
        #expect(heard.said == ["jump"])
    }

    /// An away row's Jump carries its session on, as its click does (stage 8): its menu is any row's.
    @Test func anAwayRowsMenuIsAnyRowsItsJumpEnabled() {
        let line = Session.Line(ask: "k1", title: "Review the plan", since: 0)
        let away = Session(id: "sr-4g01a7", project: "Harness", kind: .needs, away: true, lines: [line], sub: "Harness")
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(away), heard)

        #expect(RowMenu.Row(away) == RowMenu.Row(asks: ["k1"], isSnoozed: false))
        #expect(menu.items.first?.isEnabled == true)

        menu.performActionForItem(at: 0)
        #expect(heard.said == ["jump"])
    }

    @Test func aRowWithAsksOffersSnoozeItsThreeTimesEachWithWhenItWakes() throws {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(asks: ["k1", "k3"], isSnoozed: false), heard)
        let snooze = try #require(menu.items.last?.submenu)

        #expect(Self.titles(menu) == ["Jump to the window", "—", "Snooze"])
        #expect(Self.choices(snooze) == ["Later today\t17:00", "Tomorrow\tSat 09:00", "Next week\tMon 09:00"])

        snooze.performActionForItem(at: 1)
        #expect(heard.said == ["snooze Tomorrow"])
        #expect(heard.named == [["k1", "k3"]])
    }

    /// A your-turn row's Snooze is any row's: the same three times, and no Until it moves, whose waking, the turn's
    /// next end, is one Lee ruled out (13 November 2026). It names no ask.
    @Test func aYourTurnRowOffersTheSameThreeTimes() throws {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(asks: [], isSnoozed: false), heard)
        let snooze = try #require(menu.items.last?.submenu)

        #expect(Self.titles(menu) == ["Jump to the window", "—", "Snooze"])
        #expect(Self.choices(snooze) == ["Later today\t17:00", "Tomorrow\tSat 09:00", "Next week\tMon 09:00"])

        snooze.performActionForItem(at: 0)
        #expect(heard.said == ["snooze Later today"])
        #expect(heard.named == [[]])
    }

    @Test(arguments: [["k1"], []])
    func aSnoozedRowOffersWakeNow(asks: [String]) {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(asks: asks, isSnoozed: true), heard)

        #expect(Self.titles(menu) == ["Jump to the window", "—", "Wake now"])

        menu.performActionForItem(at: 2)
        #expect(heard.said == ["wake"])
    }

    /// The times sit on one right tab stop past the longest name, dim, and brighter on the one highlighted.
    @Test func theTimesSitAtTheRightBrighterHighlighted() throws {
        let snooze = SnoozeMenu(SnoozeChoice.allCases, at: Self.now, in: Self.london) { _ in }
        let stops = try snooze.items.map { item in
            try #require(item.attributedTitle?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        }
        let ink = { (item: NSMenuItem) in
            item.attributedTitle?.attribute(.foregroundColor, at: item.attributedTitle!.length - 1, effectiveRange: nil) as? NSColor
        }

        #expect(snooze.items.count == 3)
        #expect(Set(stops.map(\.tabStops)).count == 1)
        #expect(stops[0].tabStops.map(\.alignment) == [.right])
        #expect(snooze.items.allSatisfy { ink($0) == SnoozeMenu.dim })

        snooze.menu(snooze, willHighlight: snooze.items[2])
        #expect(snooze.items.map(ink) == [SnoozeMenu.dim, SnoozeMenu.dim, SnoozeMenu.lit])
    }

    /// The card's row offers what it shows: its asks, a window's stops aside, on Needs you and in Snoozed; on a turn's
    /// row, Snooze or Wake now naming no ask; on a row of stops alone, neither.
    @Test func theCardsRowOffersWhatItShows() {
        let lines = [
            Session.Line(ask: "k1", title: "Review the plan", since: 0),
            Session.Line(title: "Allow Bash", code: "gh pr create", since: 1),
        ]
        let needs = Session(id: "sr-4g01a7", project: "Harness", kind: .needs, lines: lines, sub: "Harness")
        let stops = Session(id: "sr-4g01a7", project: "Harness", kind: .needs, lines: [lines[1]], sub: "Harness")
        let asleep = Session(id: "sr-4g01a7", project: "Harness", kind: .snoozed, lines: [lines[0]], sub: "Harness", wakesAt: 9)
        let turn = Session(
            id: "sr-4g01a7", project: "Harness", kind: .turn, title: "Stage 2 is in", sub: "Harness", since: Self.ended
        )
        let turnAsleep = Session(
            id: "sr-4g01a7", project: "Harness", name: "Finish the Harness modernisation", kind: .snoozedTurn,
            lines: turn.lines, sub: "Harness"
        )

        #expect(RowMenu.Row(needs) == RowMenu.Row(asks: ["k1"], isSnoozed: false))
        #expect(RowMenu.Row(stops) == RowMenu.Row(asks: nil, isSnoozed: false))
        #expect(RowMenu.Row(asleep) == RowMenu.Row(asks: ["k1"], isSnoozed: true))
        #expect(RowMenu.Row(turn) == RowMenu.Row(asks: [], isSnoozed: false))
        #expect(RowMenu.Row(turnAsleep) == RowMenu.Row(asks: [], isSnoozed: true))
    }
}
