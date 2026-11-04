import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepLines
import SitRepPanel
import SitRepWindow
import Testing

/// A row's right-click menu, on the card and in the sidebar (Paper's boards F, G, H and I): Open in SitRep on the card;
/// Jump to the window, disabled away; then Snooze and its three times on a row whose lines hold asks, those and Until
/// it moves on a your-turn row, or Wake now on a row in Snoozed; neither on a row of stops alone. What it snoozes or
/// wakes is what the row showed as it was drawn.
@MainActor
struct RowMenuTests {
    /// Friday 23 October 2026, 14:00 in London.
    private static let now = Date(timeIntervalSince1970: 1_792_760_400)
    /// The turn a your-turn row shows, ended at 13:12:07.5.
    private nonisolated static let ended = Date(timeIntervalSince1970: 1_792_757_527.5)
    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// What each choice was asked for, in the order chosen, and what it snoozed or woke.
    private final class Heard {
        var said: [String] = []
        var named: [Snoozable] = []
    }

    private static func menu(_ row: RowMenu.Row, opens: Bool = true, _ heard: Heard) -> NSMenu {
        RowMenu.make(
            for: row, at: now, in: london,
            RowMenu.Actions(
                open: opens ? { heard.said.append("open") } : nil,
                jump: { heard.said.append("jump") },
                snooze: { heard.said.append("snooze \($1.title)"); heard.named.append($0) },
                wake: { heard.said.append("wake"); heard.named.append($0) }
            )
        )
    }

    private static func titles(_ menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "—" : $0.title }
    }

    private static func choices(_ menu: NSMenu) -> [String?] {
        menu.items.map { $0.isSeparatorItem ? "—" : $0.attributedTitle?.string }
    }

    @Test(arguments: [false, true])
    func aRowOfStopsAloneOffersOpenAndJumpJumpingDisabledAway(away: Bool) {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(jumps: !away, snoozable: nil, isSnoozed: false), heard)

        #expect(Self.titles(menu) == ["Open in SitRep", "Jump to the window"])
        #expect(menu.items.map(\.isEnabled) == [true, !away])

        menu.performActionForItem(at: 0)
        menu.performActionForItem(at: 1)
        #expect(heard.said == (away ? ["open"] : ["open", "jump"]))
    }

    @Test func aRowWithAsksOffersSnoozeItsThreeTimesEachWithWhenItWakes() throws {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(jumps: true, snoozable: .asks(["k1", "k3"]), isSnoozed: false), heard)
        let snooze = try #require(menu.items.last?.submenu)

        #expect(Self.titles(menu) == ["Open in SitRep", "Jump to the window", "—", "Snooze"])
        #expect(Self.choices(snooze) == ["Later today\t17:00", "Tomorrow\tSat 09:00", "Next week\tMon 09:00"])

        snooze.performActionForItem(at: 1)
        #expect(heard.said == ["snooze Tomorrow"])
        #expect(heard.named == [.asks(["k1", "k3"])])
    }

    /// A your-turn row's Snooze offers the same three times, then, after a separator, Until it moves, with no time;
    /// what it snoozes is the turn the row showed, by the turn's end.
    @Test func aYourTurnRowOffersUntilItMovesAfterASeparator() throws {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(jumps: true, snoozable: .turn(ended: Self.ended), isSnoozed: false), heard)
        let snooze = try #require(menu.items.last?.submenu)

        #expect(Self.titles(menu) == ["Open in SitRep", "Jump to the window", "—", "Snooze"])
        #expect(Self.choices(snooze) == [
            "Later today\t17:00", "Tomorrow\tSat 09:00", "Next week\tMon 09:00", "—", "Until it moves",
        ])

        snooze.performActionForItem(at: 4)
        snooze.performActionForItem(at: 0)
        #expect(heard.said == ["snooze Until it moves", "snooze Later today"])
        #expect(heard.named == [.turn(ended: Self.ended), .turn(ended: Self.ended)])
    }

    @Test(arguments: [Snoozable.asks(["k1"]), .turn(ended: ended)])
    func aSnoozedRowOffersWakeNow(asleep: Snoozable) {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(jumps: false, snoozable: asleep, isSnoozed: true), heard)

        #expect(Self.titles(menu) == ["Open in SitRep", "Jump to the window", "—", "Wake now"])

        menu.performActionForItem(at: 3)
        #expect(heard.said == ["wake"])
        #expect(heard.named == [asleep])
    }

    /// The sidebar's offers no Open in SitRep: the row is its page there already.
    @Test func inTheWindowItOffersNoOpen() {
        let menu = Self.menu(RowMenu.Row(jumps: true, snoozable: .asks(["k1"]), isSnoozed: false), opens: false, Heard())

        #expect(Self.titles(menu) == ["Jump to the window", "—", "Snooze"])
    }

    /// The times sit on one right tab stop past the longest name, dim, and brighter on the one highlighted; Until it
    /// moves, past the separator, its name alone.
    @Test func theTimesSitAtTheRightBrighterHighlighted() throws {
        let snooze = SnoozeMenu(SnoozeTime.offered(forTurn: true), at: Self.now, in: Self.london) { _ in }
        let timed = Array(snooze.items.prefix(3))
        let stops = try timed.map { item in
            try #require(item.attributedTitle?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        }
        let ink = { (item: NSMenuItem) in
            item.attributedTitle?.attribute(.foregroundColor, at: item.attributedTitle!.length - 1, effectiveRange: nil) as? NSColor
        }

        #expect(Set(stops.map(\.tabStops)).count == 1)
        #expect(stops[0].tabStops.map(\.alignment) == [.right])
        #expect(timed.allSatisfy { ink($0) == SnoozeMenu.dim })
        #expect(ink(snooze.items[4]) == nil)

        snooze.menu(snooze, willHighlight: snooze.items[2])
        #expect(timed.map(ink) == [SnoozeMenu.dim, SnoozeMenu.dim, SnoozeMenu.lit])
    }

    /// The card's row offers what it shows: its asks, a window's stops aside; its turn, by the turn's end, on Your turn
    /// and in Snoozed; Wake now in Snoozed.
    @Test func theCardsRowOffersWhatItShows() {
        let lines = [
            Session.Line(ask: "k1", title: "Review the plan", since: 0),
            Session.Line(title: "Allow Bash", code: "gh pr create", since: 1),
        ]
        let needs = Session(id: "sr-4g01a7", project: "Harness", kind: .needs, lines: lines, sub: "Harness")
        let asleep = Session(id: "sr-4g01a7", project: "Harness", kind: .snoozed, lines: [lines[0]], sub: "Harness", wakesAt: 9)
        let turn = Session(
            id: "sr-4g01a7", project: "Harness", kind: .turn, title: "Stage 2 is in", sub: "Harness",
            since: Self.ended.timeIntervalSince1970 * 1000
        )
        let turnAsleep = Session(
            id: "sr-4g01a7", project: "Harness", name: "Finish the Harness modernisation", kind: .snoozedTurn,
            lines: turn.lines, sub: "Harness"
        )

        #expect(RowMenu.Row(needs) == RowMenu.Row(jumps: true, snoozable: .asks(["k1"]), isSnoozed: false))
        #expect(RowMenu.Row(asleep) == RowMenu.Row(jumps: true, snoozable: .asks(["k1"]), isSnoozed: true))
        #expect(RowMenu.Row(turn) == RowMenu.Row(jumps: true, snoozable: .turn(ended: Self.ended), isSnoozed: false))
        #expect(RowMenu.Row(turnAsleep) == RowMenu.Row(jumps: true, snoozable: .turn(ended: Self.ended), isSnoozed: true))
    }

    /// The sidebar's row offers the same, over what the real CLI printed (`Lines.snoozedTurn`): a your-turn row's turn,
    /// and each turn in Snoozed, by the turn's end.
    @Test func theSidebarsRowOffersWhatItShows() {
        var last = LastBoard()

        _ = last.hear(.line(Lines.snoozedTurn[0]), at: .now)

        let ended = { (seconds: TimeInterval) in Snoozable.turn(ended: Date(timeIntervalSince1970: seconds)) }

        #expect(Listed(last).rows.map { RowMenu.Row($0) } == [
            RowMenu.Row(jumps: true, snoozable: ended(1_793_817_590), isSnoozed: false),
            RowMenu.Row(jumps: true, snoozable: ended(1_793_819_270), isSnoozed: true),
            RowMenu.Row(jumps: true, snoozable: ended(1_793_818_490), isSnoozed: true),
        ])
    }
}
