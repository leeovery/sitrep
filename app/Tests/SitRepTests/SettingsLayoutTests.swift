import AppKit
import Foundation
@testable import SitRep
import SitRepCore
import SitRepMenu
import SitRepPanel
import SitRepWindow
import SwiftUI
import Testing

/// Settings as the window lays it out, against spec round 8, 4: the real page, its rows and the system's own controls,
/// hosted offscreen in a window never shown, their frames measured.
@MainActor
struct SettingsLayoutTests {
    /// The column's left, at the title's edge, in the page's points.
    private static let edge = CGFloat(44)

    @Test(arguments: [(956.0, 704.0), (784.0, 704.0), (700.0, 620.0), (600.0, 520.0)])
    func theColumnIsAtMost704AtTheTitlesEdge(page: CGFloat, column: CGFloat) async throws {
        let hosted = await Hosted.page(width: page)
        let popUp = try #require(hosted.all(NSPopUpButton.self).first)

        // the trailing control, 10 in from the card's right
        #expect(abs(hosted.frame(of: popUp).maxX - (Self.edge + column - 10)) < 0.5)
    }

    @Test func theControlsStandAgainstTheCardsRightAtTheirOwnWidths() async throws {
        let hosted = await Hosted.page(width: 956)
        let segmented = hosted.all(NSSegmentedControl.self).map(hosted.frame(of:))
        let popUp = try hosted.frame(of: #require(hosted.all(NSPopUpButton.self).first))
        let switches = hosted.all(NSSwitch.self).map(hosted.frame(of:))
        let right = Self.edge + 704 - 10

        // Edge, Style, Material: Left · Right, Meniscus · Card, Black · Glass
        #expect(segmented.map { ($0.width * 2).rounded() / 2 } == [106, 155, 109])
        #expect(abs(popUp.width - 123) < 0.5)
        // Reduce motion, Notify me of a new ask, Open at login
        #expect(switches.count == 3)
        for frame in segmented + [popUp] + switches {
            #expect(abs(frame.maxX - right) < 0.5)
        }
    }

    @Test func eachSegmentedControlsSegmentsAreEqual() async throws {
        let hosted = await Hosted.page(width: 956)

        for control in hosted.all(NSSegmentedControl.self) {
            #expect(control.segmentDistribution == .fillEqually)
            #expect(control.controlSize == .regular)
        }
    }

    @Test func aSwitchIsTheMiniSwitch36By16() async throws {
        let hosted = await Hosted.page(width: 956)

        for control in hosted.all(NSSwitch.self) {
            #expect(control.controlSize == .mini)
            #expect(hosted.frame(of: control).size == CGSize(width: 36, height: 16))
        }
    }

    @Test func withTheStripLengthIsGrowsOrFullAndMaxASlider160Wide() async throws {
        let hosted = await Hosted.page(width: 956) { $0.show = .strip }
        let segmented = hosted.all(NSSegmentedControl.self).map { hosted.frame(of: $0).width }
        let slider = try hosted.frame(of: #require(hosted.all(NSSlider.self).first))

        // Edge, Length, Material
        #expect(segmented.map { ($0 * 2).rounded() / 2 } == [106, 117, 109])
        #expect(slider.size == CGSize(width: 160, height: 16))
        #expect(abs(slider.maxX - (Self.edge + 704 - 10)) < 0.5)
    }

    /// The system's push button at its own width: Send Test 84.5, Notification Settings… 158, as measured in a form.
    @Test(arguments: [("Send Test", 84.5), ("Notification Settings…", 158.0)])
    func aPushButtonKeepsItsOwnWidth(title: String, width: CGFloat) {
        let size = NSHostingController(rootView: Button(title) {}.buttonStyle(.bordered))
            .sizeThatFits(in: CGSize(width: 704, height: 100))

        #expect(abs(size.width - width) <= 0.5)
        #expect(size.height == 24)
    }

    /// The row's height at a width, measured in a window, its control the segmented Style.
    private static func row(line: String?, width: CGFloat) throws -> (height: CGFloat, control: CGRect) {
        let row = CardRow(label: "Style", line: line) {
            Picker("Style", selection: .constant(0)) { Text("Meniscus").tag(0); Text("Card").tag(1) }
                .pickerStyle(.segmented)
                .labelsHidden()
        }
        let hosted = Hosted(row.fixedSize(horizontal: false, vertical: true), size: CGSize(width: width, height: 400))
        let control = try #require(hosted.all(NSSegmentedControl.self).first)
        let height = NSHostingController(rootView: row).sizeThatFits(in: CGSize(width: width, height: 400)).height

        return (height, hosted.frame(of: control))
    }

    @Test func aRowIs52TallWithALineUnderItsLabelAnd38Without() throws {
        #expect(try Self.row(line: "Meniscus pours, Card slides", width: 704).height == 52)
        #expect(try Self.row(line: nil, width: 704).height == 38)
    }

    /// Narrow, the line wraps, and the row grows, before the control gives up any of its width.
    @Test func aLineWrapsBeforeItsControlShrinks() throws {
        let line = "SitRep follows the Mac's own setting either way, whatever the window's width"
        let wide = try Self.row(line: line, width: 704)
        let narrow = try Self.row(line: line, width: 300)

        #expect(narrow.height >= wide.height + 14)
        #expect(narrow.control.width == wide.control.width)
        #expect(abs(narrow.control.maxX - (300 - 10)) < 0.5)
    }

    /// Down the gap between the first two pictures, the page is black but for the cards and the desktop corner, at the
    /// drawing's heights, Notch chosen: 28 under the title to a header, 10 under each header, 30 from a card to the next
    /// header, 14 under the pictures, and the caption's row of 42 between the corner and its card.
    @Test func thePagesRhythmIsTheDrawings() async throws {
        let drawn = try await Hosted.drawn()
        let spans = drawn.litSpans(atX: Self.edge + 232)
        let drawing: [ClosedRange<CGFloat>] = [328 ... 576, 632 ... 782, 824 ... 928.5, 984.5 ... 1127.5]

        #expect(spans.count == drawing.count)
        for (span, drawn) in zip(spans, drawing) {
            #expect(abs(span.lowerBound - drawn.lowerBound) <= 0.5)
            #expect(abs(span.upperBound - drawn.upperBound) <= 0.5)
        }
    }

    /// The Notch's card, Edge, Display, Style, Material and Reduce motion: a hairline of 0.5 between each two rows,
    /// none at its top or its foot, 10 in from both its ends.
    @Test func aCardsHairlinesAreHalfAPointBetweenItsRowsOnly() async throws {
        let drawn = try await Hosted.drawn()
        let card = try #require(drawn.litSpans(atX: Self.edge + 232).first)
        let raise = { (x: CGFloat) in
            drawn.pixels(in: CGRect(x: Self.edge + x, y: card.lowerBound + 20, width: 0.5, height: 0.5))
        }
        let lines = { (x: CGFloat) in
            drawn.litSpans(atX: Self.edge + x, above: raise(x).first?.lightness ?? 0)
                .filter { card.lowerBound < $0.lowerBound && $0.upperBound < card.upperBound }
        }
        let rows: [CGFloat] = [52, 38, 52, 52]
        let tops = rows.indices.map { card.lowerBound + rows[...$0].reduce(0, +) + CGFloat($0) * 0.5 }

        #expect(lines(450).map(\.lowerBound) == tops)
        #expect(lines(450).allSatisfy { $0.upperBound - $0.lowerBound == 0.5 })
        #expect(lines(5).isEmpty)
        #expect(lines(704 - 5).isEmpty)
    }

    @Test(arguments: [(EdgeSettings.Show.notch, 1167.5), (.strip, 1220)])
    func thePageEnds40UnderGeneralsCard(show: EdgeSettings.Show, height: CGFloat) async {
        let page = await Hosted.pageView { $0.show = show }
        let size = NSHostingController(rootView: page).sizeThatFits(in: CGSize(width: 704, height: 10_000))

        #expect(abs(size.height - height) <= 0.5)
    }

    /// Narrower than 704, the desktop corner keeps its height and crops at its right, its banner going with it.
    @Test func theDesktopCornerCropsAtItsRight() throws {
        let wide = try Drawn(DesktopCorner(), size: CGSize(width: 704, height: 150))
        let narrow = try Drawn(DesktopCorner(), size: CGSize(width: 500, height: 150))
        // the wallpaper and the window behind, clear of the corner's curve and its hairline
        let left = CGRect(x: 20, y: 20, width: 300, height: 110)

        #expect(narrow.pixels(in: left) == wide.pixels(in: left))
    }
}

/// Settings over a world of its own, as the window hosts it.
@MainActor
struct Hosted {
    let hosting: NSView
    private let window: NSWindow

    /// The view in a window that is never shown, which the system's controls need to take their sizes.
    init(_ view: some View, size: CGSize) {
        let hosting = NSHostingView(rootView: view.environment(\.colorScheme, .dark))

        window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: true)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        self.hosting = hosting
    }

    /// Every view of this kind, top to bottom.
    func all<View: NSView>(_ kind: View.Type) -> [View] {
        Self.all(kind, in: hosting).sorted { frame(of: $0).minY < frame(of: $1).minY }
    }

    private static func all<View: NSView>(_ kind: View.Type, in view: NSView) -> [View] {
        view.subviews.flatMap { ($0 as? View).map { [$0] } ?? all(kind, in: $0) }
    }

    /// A view's frame in points from the hosting's top left.
    func frame(of view: NSView) -> CGRect {
        let frame = hosting.convert(view.bounds, from: view)

        return hosting.isFlipped ? frame : CGRect(
            x: frame.minX, y: hosting.bounds.height - frame.maxY, width: frame.width, height: frame.height
        )
    }

    /// The window's page on Settings, `width` wide, as tall as Lee's window.
    static func page(width: CGFloat, _ change: (inout EdgeSettings) -> Void = { _ in }) async -> Hosted {
        let page = await pageView(change)

        return Hosted(PageColumn(page: .settings, now: Date()) { page }, size: CGSize(width: width, height: 1069))
    }

    /// The window's page on Settings drawn, Notch chosen, 956 wide and tall enough for all of it: as a still, so the
    /// whole page draws, but in a window, which lays it out to the screen's pixels, as the window on screen does.
    static func drawn() async throws -> Drawn {
        let page = await pageView()
        let still = PageColumn(page: .settings, now: Date()) { page }.environment(\.isStill, true)

        return try Drawn(Hosted(still, size: CGSize(width: 956, height: 1300)).hosting)
    }

    /// Settings, its Mac saying all is well, read as the page reads it as it appears, with a second display.
    static func pageView(_ change: (inout EdgeSettings) -> Void = { _ in }) async -> SettingsPage {
        let services = SettingsServices(
            displays: {
                [
                    DisplayChoice.Connected(id: "A", name: "Built-in Retina Display", isMain: true),
                    DisplayChoice.Connected(id: "B", name: "Studio Display", isMain: false),
                ]
            },
            hasGlass: true, jump: { _ in }, sendTest: {},
            noticeLeave: { .allowed(.banners) }, askForNotices: {}, login: { LoginItem(.enabled) },
            chooseLogin: {}, ghostty: { .allowed }, allowGhostty: { .allowed }, open: { _ in }
        )
        let preferences = Preferences(UserDefaults(suiteName: "com.leeovery.sitrep.layout.\(UUID().uuidString)")!)
        let settings = SettingsModel(preferences: preferences, live: LiveBoard(), services: services)

        preferences.edit(change)
        settings.readDisplays()
        await settings.read()
        return SettingsPage(settings: settings)
    }
}

extension Drawn {
    /// Where a column of pixels down the drawing is lighter than `ground`, each span from its first lit pixel's top to
    /// its last's foot.
    func litSpans(atX x: CGFloat, above ground: CGFloat = 0) -> [ClosedRange<CGFloat>] {
        let column = Int((x * scale).rounded())
        var spans: [ClosedRange<CGFloat>] = []
        var start: Int?

        for y in 0...bitmap.pixelsHigh {
            let lightness = y < bitmap.pixelsHigh ? bitmap.colorAt(x: column, y: y)?.usingColorSpace(.sRGB)?.lightness : nil
            let isLit = (lightness ?? 0) > ground + 0.05

            if isLit, start == nil {
                start = y
            } else if !isLit, let first = start {
                spans.append(CGFloat(first) / scale ... CGFloat(y) / scale)
                start = nil
            }
        }
        return spans
    }
}
