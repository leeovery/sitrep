import AppKit
@testable import SitRep
import SitRepCore
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The notch's menus as `Edge` makes them: a row's Snooze offers the choices as Preferences has them as its menu
/// opens, a change Lee made since it was made among them. Their display is far off every screen, so
/// nothing shows.
@MainActor
@Suite(.backstop)
struct EdgeMenusTests {
    private static let display = Display(
        id: "A", frame: CGRect(x: -20000, y: -20000, width: 1512, height: 982),
        visible: CGRect(x: -20000, y: -20000, width: 1512, height: 958)
    )

    private static let session = Session(
        id: "sr-a", project: "Contoso", kind: .needs, ask: "k1", title: "Approve", sub: "Contoso", since: 0
    )

    /// The choices a menu's Snooze offers, by name.
    private static func offered(_ menu: NSMenu) throws -> [String] {
        let snooze = try #require(menu.items.first { $0.title == RowMenu.snoozeTitle }?.submenu)

        return snooze.items.map { $0.isSeparatorItem ? "—" : String($0.title.prefix { $0 != "\t" }) }
    }

    /// Only the choices whose offer the clock never changes, so the test holds at any hour: In an hour, Tonight, This
    /// weekend and Next week switched off since the menus were made.
    @Test func aRowsSnoozeOffersTheChoicesAsPreferencesHasThemAsItsMenuOpens() throws {
        let preferences = Preferences(MemoryDefaults())
        let notch = Edge.notch(preferences, on: Self.display)

        defer { notch.window.close() }
        for choice in [SnoozeChoice.inAnHour, .tonight, .thisWeekend, .nextWeek] {
            preferences.snooze.set(choice, on: false)
        }

        let menu = notch.menu(for: Self.session, row: "row")

        #expect(try Self.offered(menu) == ["Later today", "Tomorrow", "—", "Until it moves"])
    }
}
