import AppKit
import Foundation
@testable import SitRep
import SitRepEdge
import SitRepMenu
import SitRepPanel
import SwiftUI
import Testing

/// Settings' "Your turn folds after": a pop-up in General, not under What stays on screen, at its own width against
/// the card's right, saving what Lee chooses.
@MainActor
struct FoldPeriodRowTests {
    private static let width = CGFloat(956)

    private static func page(_ defaults: UserDefaults) async -> (Hosted, SettingsPage) {
        let page = await Hosted.pageView(defaults: defaults)

        return (Hosted(PageColumn(page: .settings, now: Date()) { page }, size: CGSize(width: width, height: 1400)), page)
    }

    private static func popUp(_ hosted: Hosted) throws -> NSPopUpButton {
        try #require(hosted.all(NSPopUpButton.self).first { $0.accessibilityLabel() == "Your turn folds after" })
    }

    private static func defaults() -> UserDefaults {
        UserDefaults(suiteName: "com.leeovery.sitrep.period.\(UUID().uuidString)")!
    }

    /// Its choices, an hour first and chosen, as Lee has set nothing.
    @Test func itOffersAnHourFourHoursTodayOrNeverAnHourChosen() async throws {
        let (hosted, _) = await Self.page(Self.defaults())
        let button = try Self.popUp(hosted)

        #expect(button.itemTitles == ["An hour", "Four hours", "Today", "Never"])
        #expect(button.titleOfSelectedItem == "An hour")
    }

    /// In General, under every control of What stays on screen and of Notifications, the last of which is Notification
    /// Settings…; at its widest choice's width, 10 in from the card's right, as the page's other controls.
    @Test func itIsInGeneralAtItsOwnWidth() async throws {
        let (hosted, _) = await Self.page(Self.defaults())
        let button = try Self.popUp(hosted)
        let frame = hosted.frame(of: button)
        let notifications = try #require(hosted.buttons().last)

        #expect(frame.minY > notifications.maxY)
        #expect(abs(frame.width - button.intrinsicContentSize.width) <= 0.5)
        #expect(abs(frame.maxX - (Self.width - 44 - 10)) < 1 / hosted.scale)
    }

    @Test func aChoiceIsSaved() async throws {
        let defaults = Self.defaults()
        let (hosted, page) = await Self.page(defaults)
        let button = try Self.popUp(hosted)

        button.selectItem(withTitle: "Today")
        _ = button.sendAction(button.action, to: button.target)

        #expect(page.settings.preferences.app.foldsAfter == .today)
        #expect(SavedSettings<AppSettings>(defaults).read().foldsAfter == .today)
    }
}
