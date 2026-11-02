import AppKit
import Foundation
@testable import SitRep
import SitRepEdge
import SitRepLines
import SitRepMenu
import SitRepPanel
import SwiftUI
import Testing

/// Settings' "Your turn folds after": a pop-up in General's Sessions, not in Edge, at its own width against the card's
/// right, saving what Lee chooses.
@MainActor
struct FoldPeriodRowTests {
    private static let width = CGFloat(744)

    private static func page(_ defaults: UserDefaults) async -> (Hosted, SettingsModel) {
        let settings = await Hosted.settings(defaults: defaults)

        return (Hosted(Hosted.content(.general, settings), size: CGSize(width: width, height: 620)), settings)
    }

    private static func popUp(_ hosted: Hosted) throws -> NSPopUpButton {
        try #require(hosted.all(NSPopUpButton.self).first { $0.accessibilityLabel() == "Your turn folds after" })
    }

    /// Its choices, an hour first and chosen, as Lee has set nothing.
    @Test func itOffersAnHourFourHoursTodayOrNeverAnHourChosen() async throws {
        let (hosted, _) = await Self.page(MemoryDefaults())
        let button = try Self.popUp(hosted)

        #expect(button.itemTitles == ["An hour", "Four hours", "Today", "Never"])
        #expect(button.titleOfSelectedItem == "An hour")
    }

    /// In General, under Open at login's switch; at its widest choice's width, 10 in from the card's right, as the
    /// pane's other controls.
    @Test func itIsInGeneralAtItsOwnWidth() async throws {
        let (hosted, _) = await Self.page(MemoryDefaults())
        let button = try Self.popUp(hosted)
        let frame = hosted.frame(of: button)
        let login = try #require(hosted.all(NSSwitch.self).first)

        #expect(frame.minY > hosted.frame(of: login).maxY)
        #expect(abs(frame.width - button.intrinsicContentSize.width) <= 0.5)
        #expect(abs(frame.maxX - (Self.width - 20 - 10)) < 1 / hosted.scale)
    }

    @Test func aChoiceIsSaved() async throws {
        let defaults = MemoryDefaults()
        let (hosted, settings) = await Self.page(defaults)
        let button = try Self.popUp(hosted)

        button.selectItem(withTitle: "Today")
        _ = button.sendAction(button.action, to: button.target)

        #expect(settings.preferences.app.foldsAfter == .today)
        #expect(SavedSettings<AppSettings>(defaults).read().foldsAfter == .today)
    }
}
