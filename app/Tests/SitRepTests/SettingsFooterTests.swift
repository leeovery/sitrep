import AppKit
@testable import SitRep
import SitRepWindow
import SwiftUI
import Testing

/// Settings at the sidebar's foot, laid out by the system's own list in the window's split, made, never shown, against
/// spec 2.6: under its hairline, 8, then its row 32 tall, then 10.
@MainActor
struct SettingsFooterTests {
    /// The foot at the sidebar's bottom, its row in the window, and the foot's top and bottom there.
    private static func laidOut() throws -> (row: CGRect, top: CGFloat, bottom: CGFloat) {
        let sidebar = NSHostingController(rootView: VStack(spacing: 0) {
            Color.clear
            SettingsFooter(pick: .settings, now: Date())
        })
        sidebar.sizingOptions = []

        let window = SitRepWindow.window(SitRepWindow.split(sidebar: sidebar, page: NSHostingController(rootView: Color.clear)))

        window.contentView?.layoutSubtreeIfNeeded()

        let table = try #require(Self.tables(in: sidebar.view).first)
        let bottom = sidebar.view.convert(sidebar.view.bounds, to: nil).minY

        return (table.convert(table.rect(ofRow: 0), to: nil), bottom + SettingsFooter.height, bottom)
    }

    @Test func itsRowIs32Tall8UnderItsHairlineAnd10AboveItsBottom() throws {
        let (row, top, bottom) = try Self.laidOut()

        #expect(row.height == 32)
        // the window's points count up from its bottom
        #expect(top - 1 - row.maxY == 8)
        #expect(row.minY - bottom == 10)
    }

    @Test func itIsItsHairlineAndItsRowWithTheirSpace() {
        #expect(SettingsFooter.height == CGFloat(1 + 8 + 32 + 10))
    }

    private static func tables(in view: NSView) -> [NSTableView] {
        view.subviews.flatMap { ($0 as? NSTableView).map { [$0] } ?? tables(in: $0) }
    }
}
