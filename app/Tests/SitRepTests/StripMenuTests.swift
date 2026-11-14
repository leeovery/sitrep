import AppKit
@testable import SitRep
import SitRepPanel
import Testing

/// The strip's right-click menus (14 November 2026): on a session's mark, its row's menu on the card, the same, with
/// Collapse its section at its foot after a separator; on a section folded, Expand it alone; on a count past its
/// section's room, Collapse it alone.
@MainActor
struct StripMenuTests {
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

    private static func menu(_ target: StripTarget, _ heard: Heard) -> NSMenu {
        StripMenu.make(
            for: target, at: now, in: london,
            row: { session in
                RowMenu.Actions(
                    jump: { heard.said.append("jump \(session.id)") },
                    snooze: { _, _ in heard.said.append("snooze \(session.id)") },
                    wake: { heard.said.append("wake \(session.id)") }
                )
            },
            fold: { heard.said.append("\($1 ? "fold" : "unfold") \($0.title)") }
        )
    }

    private static func titles(_ menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "—" : $0.title }
    }

    /// A menu's item chosen, as AppKit sends its action, through the app, made if no other test has.
    private static func choose(_ index: Int, in menu: NSMenu) throws {
        let item = menu.items[index]

        NSApplication.shared.sendAction(try #require(item.action), to: item.target, from: item)
    }

    private static func session(_ kind: Session.Kind) -> Session {
        Session(id: "sr-a", project: "SitRep", kind: kind, ask: "k1", title: "Approve", sub: "SitRep", since: 0)
    }

    @Test(arguments: [
        (Session.Kind.needs, "Needs you"), (.turn, "Needs you"), (.working, "Working"), (.snoozed, "Snoozed"),
    ])
    func aSessionsMarkOffersItsRowsMenuThenCollapseItsSection(_ kind: Session.Kind, _ section: String) throws {
        let heard = Heard(), session = Self.session(kind)
        let menu = Self.menu(.session(session), heard)
        let row = RowMenu.make(
            for: RowMenu.Row(session), at: Self.now, in: Self.london,
            RowMenu.Actions(jump: {}, snooze: { _, _ in }, wake: {})
        )

        #expect(Self.titles(menu) == Self.titles(row) + ["—", "Collapse \(section)"])
        #expect(menu.items.last?.isEnabled == true)

        try Self.choose(0, in: menu)
        try Self.choose(menu.items.count - 1, in: menu)
        #expect(heard.said == ["jump sr-a", "fold \(section)"])
    }

    @Test(arguments: [BoardSection.needsYou, .working, .snoozed])
    func aFoldedCountOffersExpandAlone(_ section: BoardSection) throws {
        let heard = Heard()
        let menu = Self.menu(.count(section, isFolded: true), heard)

        #expect(Self.titles(menu) == ["Expand \(section.title)"])
        #expect(menu.items.map(\.isEnabled) == [true])

        try Self.choose(0, in: menu)
        #expect(heard.said == ["unfold \(section.title)"])
    }

    @Test(arguments: [BoardSection.needsYou, .working, .snoozed])
    func aCountPastItsRoomOffersCollapseAlone(_ section: BoardSection) throws {
        let heard = Heard()
        let menu = Self.menu(.count(section, isFolded: false), heard)

        #expect(Self.titles(menu) == ["Collapse \(section.title)"])

        try Self.choose(0, in: menu)
        #expect(heard.said == ["fold \(section.title)"])
    }
}
