import AppKit
@testable import SitRep
import SitRepWindow
import SwiftUI
import Testing

/// Settings at the sidebar's foot as the window lays it out, made, never shown: the whole sidebar in the window's
/// split, the foot in the list's bar, against spec 2.6: its hairline, 8, its row 32 tall, then 10.
@MainActor
struct SettingsFooterTests {
    @Test func itsRowIs32Tall8UnderItsHairlineAnd10AboveTheSidebarsFoot() throws {
        let foot = try Foot.laidOut()

        #expect(abs(foot.row.height - 32) < 0.5)
        #expect(abs(foot.hairline.height - 1) < 0.5)
        // the window's points count up from its bottom
        #expect(abs(foot.hairline.minY - foot.row.maxY - 8) < 0.5)
        #expect(abs(foot.row.minY - foot.bottom - 10) < 0.5)
    }
}

/// The foot as the window lays it out: its row, the system's own, and its hairline, found in the sidebar's drawing, in
/// the window's points; the sidebar's bottom; and the drawing.
@MainActor
struct Foot {
    let row: CGRect
    let hairline: CGRect
    let bottom: CGFloat
    let drawing: NSBitmapImageRep

    static func laidOut() throws -> Foot {
        let sidebar = NSHostingController(
            rootView: BoardColumn(listed: Listed(), pick: .settings, sidebar: .projects, filter: Filter(), now: Date())
        )
        sidebar.sizingOptions = []

        let window = SitRepWindow.window(SitRepWindow.split(sidebar: sidebar, page: NSHostingController(rootView: Color.clear)))

        window.contentView?.layoutSubtreeIfNeeded()

        let view = sidebar.view
        let table = try #require(tables(in: view).first { $0.numberOfRows == 1 })
        let frame = view.convert(view.bounds, to: nil)
        let drawing = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))

        view.cacheDisplay(in: view.bounds, to: drawing)

        return Foot(
            row: table.convert(table.rect(ofRow: 0), to: nil),
            hairline: try hairline(in: drawing, of: frame),
            bottom: frame.minY,
            drawing: drawing
        )
    }

    /// The hairline's lines of pixels, `#FFFFFF14` over the sidebar's clear, down the middle of the sidebar's foot.
    private static func hairline(in drawing: NSBitmapImageRep, of frame: CGRect) throws -> CGRect {
        let scale = CGFloat(drawing.pixelsHigh) / frame.height
        let foot = drawing.pixelsHigh - Int((SettingsFooter.height + 10) * scale)
        let lines = (foot..<drawing.pixelsHigh).filter { y in
            let alpha = drawing.colorAt(x: Int(frame.width / 2 * scale), y: y)?.alphaComponent ?? 0

            return abs(alpha - Double(0x14) / 255) < 0.01
        }
        let top = try #require(lines.first)
        let bottom = try #require(lines.last)

        return CGRect(
            x: frame.minX, y: frame.maxY - CGFloat(bottom + 1) / scale,
            width: frame.width, height: CGFloat(bottom + 1 - top) / scale
        )
    }

    private static func tables(in view: NSView) -> [NSTableView] {
        view.subviews.flatMap { ($0 as? NSTableView).map { [$0] } ?? tables(in: $0) }
    }
}
