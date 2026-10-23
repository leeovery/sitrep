import AppKit
@testable import SitRep
import SitRepPanel
import Testing

/// A row's right-click menu, on the card and in the sidebar (Paper's boards F, G and H): Open in SitRep on the card;
/// Jump to the window, disabled away; then Snooze and its three times on a row whose lines hold asks, or Wake now on a
/// row in Snoozed; neither on a row of stops alone. What it snoozes or wakes is what the row showed as it was drawn.
@MainActor
struct RowMenuTests {
    /// Friday 23 October 2026, 14:00 in London.
    private static let now = Date(timeIntervalSince1970: 1_792_760_400)
    private static let london: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    /// What each choice was asked for, in the order chosen.
    private final class Heard {
        var said: [String] = []
    }

    private static func menu(_ row: RowMenu.Row, opens: Bool = true, _ heard: Heard) -> NSMenu {
        RowMenu.make(
            for: row, at: now, in: london,
            RowMenu.Actions(
                open: opens ? { heard.said.append("open") } : nil,
                jump: { heard.said.append("jump") },
                snooze: { heard.said.append("snooze \($0)") },
                wake: { heard.said.append("wake") }
            )
        )
    }

    private static func titles(_ menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "—" : $0.title }
    }

    @Test(arguments: [false, true])
    func aRowOfStopsAloneOffersOpenAndJumpJumpingDisabledAway(away: Bool) {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(jumps: !away, asks: [], isSnoozed: false), heard)

        #expect(Self.titles(menu) == ["Open in SitRep", "Jump to the window"])
        #expect(menu.items.map(\.isEnabled) == [true, !away])

        menu.performActionForItem(at: 0)
        menu.performActionForItem(at: 1)
        #expect(heard.said == (away ? ["open"] : ["open", "jump"]))
    }

    @Test func aRowWithAsksOffersSnoozeItsThreeTimesEachWithWhenItWakes() throws {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(jumps: true, asks: ["k1", "k3"], isSnoozed: false), heard)
        let snooze = try #require(menu.items.last?.submenu)

        #expect(Self.titles(menu) == ["Open in SitRep", "Jump to the window", "—", "Snooze"])
        #expect(snooze.items.map { $0.attributedTitle?.string } == [
            "Later today\t17:00", "Tomorrow\tSat 09:00", "Next week\tMon 09:00",
        ])

        snooze.performActionForItem(at: 1)
        #expect(heard.said == ["snooze tomorrow"])
    }

    @Test func aSnoozedRowOffersWakeNow() {
        let heard = Heard()
        let menu = Self.menu(RowMenu.Row(jumps: false, asks: ["k1"], isSnoozed: true), heard)

        #expect(Self.titles(menu) == ["Open in SitRep", "Jump to the window", "—", "Wake now"])

        menu.performActionForItem(at: 3)
        #expect(heard.said == ["wake"])
    }

    /// The sidebar's offers no Open in SitRep: the row is its page there already.
    @Test func inTheWindowItOffersNoOpen() {
        let menu = Self.menu(RowMenu.Row(jumps: true, asks: ["k1"], isSnoozed: false), opens: false, Heard())

        #expect(Self.titles(menu) == ["Jump to the window", "—", "Snooze"])
    }

    /// The times sit on one right tab stop past the longest name, dim, and brighter on the one highlighted.
    @Test func theTimesSitAtTheRightBrighterHighlighted() throws {
        let snooze = SnoozeMenu(at: Self.now, in: Self.london) { _ in }
        let stops = try snooze.items.map { item in
            try #require(item.attributedTitle?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        }
        let ink = { (item: NSMenuItem) in
            item.attributedTitle?.attribute(.foregroundColor, at: item.attributedTitle!.length - 1, effectiveRange: nil) as? NSColor
        }

        #expect(Set(stops.map(\.tabStops)).count == 1)
        #expect(stops[0].tabStops.map(\.alignment) == [.right])
        #expect(snooze.items.allSatisfy { ink($0) == SnoozeMenu.dim })

        snooze.menu(snooze, willHighlight: snooze.items[2])
        #expect(snooze.items.map(ink) == [SnoozeMenu.dim, SnoozeMenu.dim, SnoozeMenu.lit])
    }

    /// The card's row offers what it shows: its asks, a window's stops aside; Wake now in Snoozed.
    @Test func theCardsRowOffersTheAsksItShows() {
        let lines = [
            Session.Line(ask: "k1", title: "Review the plan", since: 0),
            Session.Line(title: "Allow Bash", code: "gh pr create", since: 1),
        ]
        let needs = Session(id: "sr-4g01a7", project: "Harness", kind: .needs, lines: lines, sub: "Harness")
        let asleep = Session(id: "sr-4g01a7", project: "Harness", kind: .snoozed, lines: [lines[0]], sub: "Harness", wakesAt: 9)

        #expect(RowMenu.Row(needs) == RowMenu.Row(jumps: true, asks: ["k1"], isSnoozed: false))
        #expect(RowMenu.Row(asleep) == RowMenu.Row(jumps: true, asks: ["k1"], isSnoozed: true))
    }
}
