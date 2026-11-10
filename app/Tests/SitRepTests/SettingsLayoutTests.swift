import AppKit
import Foundation
@testable import SitRep
@testable import SitRepCore
import SitRepLines
import SitRepMenu
import SitRepPanel
import SwiftUI
import Testing

/// Settings' panes as the window lays them out, against spec round 8, 4 and Paper's "Settings window": the real panes,
/// their rows and the system's own controls, hosted offscreen in a window never shown, their frames measured. A pane's
/// width is the window's right of the sidebar.
@MainActor
struct SettingsLayoutTests {
    /// The column's left, 20 in from the sidebar.
    private static let edge = CGFloat(20)
    /// The pane whose column is the drawing's 704.
    private static let drawingsPane = CGFloat(704 + 40)
    /// The pane at the window's least width, beside the sidebar's 188: a column of 476.
    nonisolated private static let narrowest = SettingsWindow.smallest.width - 188

    /// The column at a pane's width: the pane less 20 on each side, with no cap.
    private static func column(_ pane: CGFloat) -> CGFloat {
        pane - 2 * edge
    }

    /// Each pane's controls at its rows' right, top to bottom: Open at login, Terminal, Open command; Edge, Display,
    /// Style, Material, Reduce motion; Send Test, Notify me, Notification Settings…, Play a sound, Sound; the two
    /// windows' Show and Copy.
    private static let controls: [(SettingsPane, Int)] = [(.general, 3), (.edge, 5), (.notifications, 5), (.claudeCode, 3)]

    /// The column fills the pane, less its insets, at any width: each card spans it, and every control at a row's
    /// right stands 10 in from the card's.
    @Test(arguments: [narrowest, 744, 1200])
    func theColumnFillsThePaneLessItsInsets(width: CGFloat) async throws {
        for (pane, count) in Self.controls {
            let hosted = await Hosted.pane(pane, width: width, live: Hosted.live(needsReload: true))
            let drawn = try Drawn(hosted.hosting)
            let controls = hosted.trailingControls()
            // across a pop-up's row, or where a pane has none, the first control's
            let row = try #require(hosted.all(NSPopUpButton.self).first.map(hosted.frame(of:)) ?? controls.first)
            let card = try #require(drawn.litSpans(atY: row.midY).first)
            let pixel = 1 / hosted.scale

            #expect((Self.edge ... Self.edge + Self.column(width)).isWithinAPixel(of: card, at: hosted.scale))
            #expect(controls.count == count)
            for control in controls {
                #expect(abs(control.maxX - (Self.edge + Self.column(width) - 10)) < pixel)
            }
        }
    }

    @Test func theControlsKeepTheirOwnWidths() async throws {
        let hosted = await Hosted.pane(.edge, width: 744)
        let segmented = hosted.all(NSSegmentedControl.self).map(hosted.frame(of:))
        let button = try #require(hosted.all(NSPopUpButton.self).first)
        let popUp = hosted.frame(of: button)

        // Edge, Style, Material: Left · Right, Meniscus · Card, Black · Glass
        #expect(segmented.map { ($0.width * 2).rounded() / 2 } == [106, 155, 109])
        // to the window's half points, where the stock one, in none, rounds to whole ones
        #expect(abs(popUp.width - SystemControlsTests.stock(button.itemArray).intrinsicContentSize.width) <= 0.5)
    }

    /// Open at login; Reduce motion; Notify me of a new ask and Play a sound for a new ask.
    @Test(arguments: [(SettingsPane.general, 1), (.edge, 1), (.notifications, 2), (.claudeCode, 0)])
    func eachSwitchIsTheMiniSwitch36By16(pane: SettingsPane, switches: Int) async throws {
        let hosted = await Hosted.pane(pane, width: 744)

        #expect(hosted.all(NSSwitch.self).count == switches)
        for control in hosted.all(NSSwitch.self) {
            #expect(control.controlSize == .mini)
            #expect(hosted.frame(of: control).size == CGSize(width: 36, height: 16))
        }
    }

    @Test func eachSegmentedControlsSegmentsAreEqual() async throws {
        let hosted = await Hosted.pane(.edge, width: 744)

        for control in hosted.all(NSSegmentedControl.self) {
            #expect(control.segmentDistribution == .fillEqually)
            #expect(control.controlSize == .regular)
        }
    }

    @Test func withTheStripLengthIsGrowsOrFullAndMaxASlider160Wide() async throws {
        let hosted = await Hosted.pane(.edge, width: 744) { $0.show = .strip }
        let segmented = hosted.all(NSSegmentedControl.self).map { hosted.frame(of: $0).width }
        let slider = try hosted.frame(of: #require(hosted.all(NSSlider.self).first))

        // Edge, Length, Material
        #expect(segmented.map { ($0 * 2).rounded() / 2 } == [106, 117, 109])
        #expect(slider.size == CGSize(width: 160, height: 16))
        #expect(abs(slider.maxX - (Self.edge + Self.column(744) - 10)) < 0.5)
    }

    /// Notifications' push buttons at their own widths, as measured in a form, against the right: Send Test 84.5, and
    /// Notification Settings… 158.
    @Test func notificationsPushButtonsKeepTheirOwnWidths() async throws {
        let hosted = await Hosted.pane(.notifications, width: 744)
        let buttons = hosted.buttons()
        let pixel = 1 / hosted.scale

        #expect(buttons.count == 2)
        for (button, width) in zip(buttons, [84.5, 158]) {
            #expect(abs(button.width - width) < pixel)
            #expect(button.height == 24)
            #expect(abs(button.maxX - (Self.edge + Self.column(744) - 10)) < pixel)
        }
    }

    /// At the narrowest column, 476, in each state whose control is widest, the control keeps its own width, 10 in from
    /// the card's right, and the row's line wraps, growing the row past 52, where it no longer fits beside it: opening
    /// at login waiting on Lee and Ghostty not allowed.
    @Test(arguments: [(General.login, 158.0), (.ghostty, 169.5)])
    func aRowThatNeedsSomethingWrapsItsLineBeforeItsButtonShrinks(row: General, width: CGFloat) async throws {
        let hosted = await Hosted.pane(.general, width: Self.narrowest, said: Hosted.needsLee)
        let drawn = try Drawn(hosted.hosting)
        // Open at login's button, Ghostty's button
        let control = hosted.trailingControls()[row.rawValue]
        let pixel = 1 / hosted.scale

        #expect(abs(control.width - width) < pixel)
        #expect(abs(control.maxX - (Self.edge + Self.column(Self.narrowest) - 10)) < pixel)

        let height = try drawn.row(around: control).upperBound - drawn.row(around: control).lowerBound

        #expect(height > 52)
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

    /// Down the column, each pane is black but for its cards and the desktop corner, and the words of a caption under a
    /// card, its first 13 under the toolbar: a section's header's line of 16 and 10 over its card, the sections 26
    /// apart. General's first two cards a row of 52 each, then New windows' two rows of 38, its caption's words in the
    /// 8 and two lines of 14 under it; Edge's the Show row's 86, then Notch's four, 52, 38, 52 and 52, then Motion's
    /// 52; Notifications' corner of 150 and the caption's row of 32, then Banners' two rows of 52 and Sound's 52 and
    /// 38. What is shorter than a row is a caption's words, and lies in its lines. Within a pixel at the screen's
    /// scale, which lays the pane out.
    @Test(arguments: [
        (SettingsPane.general, [39 ... 91, 143 ... 195, 247 ... 323.5], [323.5 ... 361.5]),
        (.edge, [13 ... 99, 151 ... 346.5, 398.5 ... 450.5], []),
        (.notifications, [13 ... 163, 247 ... 351.5, 403.5 ... 494], [163 ... 195]),
    ] as [(SettingsPane, [ClosedRange<CGFloat>], [ClosedRange<CGFloat>])])
    func eachPanesCardsStandAtTheirHeights(
        pane: SettingsPane, drawing: [ClosedRange<CGFloat>], captions: [ClosedRange<CGFloat>]
    ) async throws {
        let drawn = try await Hosted.drawn(pane, width: Self.drawingsPane)
        let spans = drawn.litSpans(atX: Self.edge + 232)
        let isCard = { (span: ClosedRange<CGFloat>) in span.upperBound - span.lowerBound >= SettingsStyle.oneLineRow }
        let cards = spans.filter(isCard)

        #expect(cards.count == drawing.count)
        for (span, expected) in zip(cards, drawing) {
            #expect(expected.isWithinAPixel(of: span, at: drawn.scale))
        }
        for words in spans.filter({ !isCard($0) }) {
            #expect(captions.contains { $0.contains(words.lowerBound) && $0.contains(words.upperBound) }, "\(words)")
        }
    }

    /// Each header's line of 16 stands 10 over its card: General's Startup, Ghostty and New windows. Each header's
    /// capitals stand alike in their line, so the same distance over what each heads.
    @Test func eachHeaderStands10OverWhatItHeads() async throws {
        let drawn = try await Hosted.drawn(.general, width: Self.drawingsPane)
        let heads: [CGFloat] = [39, 143, 247]
        // the header's first word's first letters, which hang below no line: Star, Ghos, New
        let capitals = try heads.map { head in
            try #require(drawn.litRows(in: CGRect(x: Self.edge + 10, y: head - 30, width: 30, height: 24)))
        }
        let pixel = 1 / drawn.scale

        for (head, capital) in zip(heads, capitals) {
            // inside the line of 16 that ends 10 over the head
            #expect(capital.lowerBound >= head - 10 - 16)
            #expect(capital.upperBound <= head - 10)
            #expect(abs((head - capital.upperBound) - (heads[0] - capitals[0].upperBound)) < pixel)
        }
    }

    /// Notch's card, Edge, Display, Style and Material: a hairline of 0.5 between each two rows, none at its top or its
    /// foot, 10 in from both its ends. Within a pixel at the screen's scale.
    @Test func aCardsHairlinesAreHalfAPointBetweenItsRowsOnly() async throws {
        let drawn = try await Hosted.drawn(.edge, width: Self.drawingsPane)
        let card = try #require(drawn.litSpans(atX: Self.edge + 232).dropFirst().first)
        let lines = { (x: CGFloat) in drawn.lines(atX: Self.edge + x, in: card) }
        let rows: [CGFloat] = [52, 38, 52]
        let drawing = rows.indices.map { row in
            let top = card.lowerBound + rows[...row].reduce(0, +) + CGFloat(row) * 0.5

            return top ... top + 0.5
        }

        #expect(lines(450).count == drawing.count)
        for (line, expected) in zip(lines(450), drawing) {
            #expect(expected.isWithinAPixel(of: line, at: drawn.scale))
        }
        #expect(lines(5).isEmpty)
        #expect(lines(704 - 5).isEmpty)
    }

    /// Edge ends 20 under Motion's card: the notch's four rows in its card, the strip's five, Max among them.
    @Test(arguments: [(EdgeSettings.Show.notch, 470.5), (.strip, 523.0)])
    func edgeEnds20UnderItsLastCard(show: EdgeSettings.Show, height: CGFloat) async {
        let settings = await Hosted.settings { $0.show = show }
        let pane = SettingsPaneContent(pane: .edge, settings: settings)
        let size = NSHostingController(rootView: pane).sizeThatFits(in: CGSize(width: Self.drawingsPane, height: 10_000))

        #expect(abs(size.height - height) <= 0.5)
    }

    /// The desktop corner fills the column's width at its 150, whatever the width.
    @Test(arguments: [500.0, 704, 1200])
    func theDesktopCornerFillsTheColumn150Tall(width: CGFloat) {
        let size = NSHostingController(rootView: DesktopCorner()).sizeThatFits(in: CGSize(width: width, height: 1000))

        #expect(size == CGSize(width: width, height: 150))
    }

    /// The time every desktop corner's clock tells here, so two drawings of it compared tell the same one, whenever the
    /// minute turns: Tue 20 Oct 20:20 in London.
    private static let cornersTime = Date(timeIntervalSince1970: 1_792_524_000)

    /// The desktop corner `width` wide, its clock at `time`.
    private static func corner(_ width: CGFloat, at time: Date = cornersTime) throws -> Drawn {
        try Drawn(DesktopCorner(time: time), size: CGSize(width: width, height: 150))
    }

    /// The clock tells the time it is given: a minute later, the menu bar's right, where the clock stands, is drawn
    /// otherwise.
    @Test func theDesktopCornersClockTellsTheTimeItIsGiven() throws {
        let clock = CGRect(x: 704 - 120, y: 0, width: 108, height: 24)
        let later = try Self.corner(704, at: Self.cornersTime + 60)

        #expect(try Self.corner(704).pixels(in: clock) != later.pixels(in: clock))
    }

    /// Narrower than its drawing's 704, the desktop corner crops at its left: all of it inside its hairline and its
    /// corners' curve is the drawing's right, the clock, the banner and the window behind, to the same pixels.
    @Test func narrowerTheDesktopCornerCropsAtItsLeft() throws {
        let drawing = try Self.corner(704)
        let narrow = try Self.corner(500)
        let inside = { (width: CGFloat) in CGRect(x: width - 488, y: 12, width: 476, height: 126) }

        #expect(Self.alike(narrow.pixels(in: inside(500)), drawing.pixels(in: inside(704))))
    }

    /// The same pixels but for the wallpaper's dither, which follows where its pixels fall in the gradient: no channel
    /// more than `levels` of its 255 apart. Measured, the dither moves a channel 1.3 levels at most, and 4.5 under the
    /// menu bar's shade; a mark a pixel out of place moves it by far more.
    private static func alike(_ some: [NSColor], _ others: [NSColor], within levels: CGFloat = 2) -> Bool {
        some.count == others.count && zip(some, others).allSatisfy { one, other in
            let channels = [
                one.redComponent - other.redComponent, one.greenComponent - other.greenComponent,
                one.blueComponent - other.blueComponent,
            ]

            return channels.allSatisfy { abs($0) * 255 <= levels }
        }
    }

    /// Wider than its drawing, the desktop corner runs on with nothing stretched: at its right, the menu bar's items and
    /// the banner, and at its left, the window behind 28 in, are the drawing's to the same pixels.
    @Test func widerTheDesktopCornerRunsOnBetweenItsTwoEnds() throws {
        let drawing = try Self.corner(704)
        let wide = try Self.corner(1200)
        // the menu bar's items, clear of the corners' curve
        let bar = { (width: CGFloat) in CGRect(x: width - 480, y: 0, width: 468, height: 24) }
        // under them the banner, clear of where the window behind stands in the drawing
        let banner = { (width: CGFloat) in CGRect(x: width - 290, y: 24, width: 278, height: 114) }
        // the window behind, clear of the banner and its shadow in the drawing
        let behind = CGRect(x: 12, y: 24, width: 250, height: 114)

        #expect(Self.alike(wide.pixels(in: bar(1200)), drawing.pixels(in: bar(704)), within: 5))
        #expect(Self.alike(wide.pixels(in: banner(1200)), drawing.pixels(in: banner(704))))
        #expect(Self.alike(wide.pixels(in: behind), drawing.pixels(in: behind)))
    }
}

/// General's rows with a control, top to bottom.
enum General: Int, Sendable {
    case login, ghostty
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

    /// The screen's scale, to which the window lays its views out.
    var scale: CGFloat { window.backingScaleFactor }

    /// Every view of this kind, top to bottom.
    func all<View: NSView>(_ kind: View.Type) -> [View] {
        Self.all(kind, in: hosting).sorted { frame(of: $0).minY < frame(of: $1).minY }
    }

    private static func all<View: NSView>(_ kind: View.Type, in view: NSView) -> [View] {
        view.subviews.flatMap { ($0 as? View).map { [$0] } ?? all(kind, in: $0) }
    }

    /// The pane's push buttons, top to bottom: SwiftUI draws them itself, so each is found by the focus ring AppKit
    /// keeps for it, as tall as the button.
    func buttons() -> [CGRect] {
        Self.all(NSView.self, in: hosting, where: { String(describing: type(of: $0)) == "_FocusRingView" })
            .map(frame(of:))
            .filter { $0.height == 24 }
            .sorted { $0.minY < $1.minY }
    }

    /// Every control at a row's right, top to bottom: the system's own, and the push buttons.
    func trailingControls() -> [CGRect] {
        let controls = all(NSSegmentedControl.self).map(frame(of:)) + all(NSPopUpButton.self).map(frame(of:))
            + all(NSSwitch.self).map(frame(of:)) + all(NSSlider.self).map(frame(of:))
            + all(NSTextField.self).map(frame(of:))

        // a pop-up keeps a focus ring of its own too
        let all = (controls + buttons()).reduce(into: [CGRect]()) { found, frame in
            if !found.contains(frame) {
                found.append(frame)
            }
        }

        return all.sorted { $0.minY < $1.minY }
    }

    private static func all(_ kind: NSView.Type, in view: NSView, where matches: (NSView) -> Bool) -> [NSView] {
        view.subviews.flatMap { matches($0) ? [$0] : all(kind, in: $0, where: matches) }
    }

    /// A view's frame in points from the hosting's top left.
    func frame(of view: NSView) -> CGRect {
        let frame = hosting.convert(view.bounds, from: view)

        return hosting.isFlipped ? frame : CGRect(
            x: frame.minX, y: hosting.bounds.height - frame.maxY, width: frame.width, height: frame.height
        )
    }

    /// A pane, `width` wide, as tall as the window starts unless `height` says, over Settings as given.
    static func pane(
        _ pane: SettingsPane, width: CGFloat, height: CGFloat = SettingsWindow.size.height, said: MacSays = allWell,
        live: LiveBoard = LiveBoard(), _ change: (inout EdgeSettings) -> Void = { _ in }
    ) async -> Hosted {
        let settings = await settings(said: said, live: live, change)

        return Hosted(content(pane, settings), size: CGSize(width: width, height: height))
    }

    /// A pane drawn, Notch chosen unless `change` says, `width` wide and 900 tall, all of it, over `ground`, in a
    /// window, which lays it out to the screen's pixels, as the window on screen does.
    static func drawn(
        _ pane: SettingsPane, width: CGFloat, over ground: Color = .black,
        _ change: (inout EdgeSettings) -> Void = { _ in }
    ) async throws -> Drawn {
        let settings = await settings(change)

        return try Drawn(Hosted(content(pane, settings, over: ground), size: CGSize(width: width, height: 900)).hosting)
    }

    /// A pane's sections from the window's top, as they stand under the toolbar, unscrolled, over black unless
    /// `ground` says, so its cards and words read lit against it.
    static func content(_ pane: SettingsPane, _ settings: SettingsModel, over ground: Color = .black) -> some View {
        SettingsPaneContent(pane: pane, settings: settings)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(ground)
    }


    static let allWell = MacSays(notices: .allowed(.banners), login: LoginItem(.enabled), ghostty: .allowed)
    /// Every General row's widest want: Ghostty not allowed, opening at login waiting on Lee's approval.
    static let needsLee = MacSays(notices: .allowed(.banners), login: LoginItem(.requiresApproval), ghostty: .denied)

    /// The plugin running, its board printed, with two windows on it, on an older plugin or not.
    static func live(needsReload: Bool) -> LiveBoard {
        let live = LiveBoard()
        let window = { (writer: String) in
            """
            {"writer":"\(writer)","session":"sr-aw3bgs","name":"The Mac app","project":"SitRep",\
            "version":"\(needsReload ? "0.1.0" : "0.2.0")","needsReload":\(needsReload),"where":null,"state":null,\
            "attachedAt":1792440000000}
            """
        }
        let line = """
            {"v":3,"at":1792445574706,"version":"0.2.0","head":{"needYou":0,"sessions":1},"rows":[],"projects":[],\
            "windows":[\(window("w1")),\(window("w2"))],"new":[],"boards":{}}
            """
        var last = LastBoard()

        last.begin()
        _ = last.hear(.line(line), at: Date())
        live.last = last
        live.plugin = .running(.folder("~/Code/sitrep"), folder: "/Users/lee/Code/sitrep")
        return live
    }

    /// The Mac's own services for Settings, saying `said`, with a second display, the sounds given, and what Show and
    /// Copy were asked kept in `asked`.
    static func services(said: MacSays = allWell, sounds: AlertSounds = .silent, asked: Asked = Asked()) -> SettingsServices {
        SettingsServices(
            displays: {
                [
                    DisplayChoice.Connected(id: "A", name: "Built-in Retina Display", isMain: true),
                    DisplayChoice.Connected(id: "B", name: "Studio Display", isMain: false),
                ]
            },
            hasGlass: true, jump: { asked.jumps.append($0) }, sendTest: {}, copy: { asked.copies.append($0) },
            sounds: sounds, noticeLeave: { said.notices ?? .unasked }, askForNotices: {},
            login: { said.login ?? LoginItem(.notFound) }, chooseLogin: {}, ghostty: { said.ghostty ?? .unknown },
            allowGhostty: { .allowed }, open: { _ in }
        )
    }

    /// What Settings asked of the Mac.
    @MainActor
    final class Asked {
        var jumps: [String] = []
        var copies: [String] = []
    }

    /// Settings, its Mac saying `said`, read as the window reads it as a pane comes into sight, its displays read as
    /// Edge reads them as it appears.
    static func settings(
        said: MacSays = allWell, live: LiveBoard = LiveBoard(), defaults: UserDefaults = MemoryDefaults(),
        sounds: AlertSounds = .silent, asked: Asked = Asked(), _ change: (inout EdgeSettings) -> Void = { _ in }
    ) async -> SettingsModel {
        let preferences = Preferences(defaults)
        let settings = SettingsModel(
            preferences: preferences, live: live, services: services(said: said, sounds: sounds, asked: asked)
        )

        preferences.edit(change)
        settings.readDisplays()
        await settings.read()
        return settings
    }
}

extension ClosedRange<CGFloat> {
    /// Each end within a pixel of the other's at this scale: the same, where the scale draws these points exactly.
    func isWithinAPixel(of other: Self, at scale: CGFloat) -> Bool {
        abs(lowerBound - other.lowerBound) < 1 / scale && abs(upperBound - other.upperBound) < 1 / scale
    }
}

extension Drawn {
    /// Where a column of pixels down the drawing is lighter than `ground`, each span from its first lit pixel's top to
    /// its last's foot.
    func litSpans(atX x: CGFloat, above ground: CGFloat = 0) -> [ClosedRange<CGFloat>] {
        let column = Int((x * scale).rounded())

        return litSpans(across: bitmap.pixelsHigh, above: ground) { bitmap.colorAt(x: column, y: $0) }
    }

    /// Where a row of pixels across the drawing is lighter than `ground`, each span from its first lit pixel's left to
    /// its last's right.
    func litSpans(atY y: CGFloat, above ground: CGFloat = 0) -> [ClosedRange<CGFloat>] {
        let row = Int((y * scale).rounded())

        return litSpans(across: bitmap.pixelsWide, above: ground) { bitmap.colorAt(x: $0, y: row) }
    }

    private func litSpans(
        across pixels: Int, above ground: CGFloat, at color: (Int) -> NSColor?
    ) -> [ClosedRange<CGFloat>] {
        var spans: [ClosedRange<CGFloat>] = []
        var start: Int?

        for pixel in 0...pixels {
            let lightness = pixel < pixels ? color(pixel)?.usingColorSpace(.sRGB)?.lightness : nil
            let isLit = (lightness ?? 0) > ground + 0.05

            if isLit, start == nil {
                start = pixel
            } else if !isLit, let first = start {
                spans.append(CGFloat(first) / scale ... CGFloat(pixel) / scale)
                start = nil
            }
        }
        return spans
    }

    /// A card's hairlines down a column: what is lighter than the card's raise there, a pixel tall, inside it.
    func lines(atX x: CGFloat, in card: ClosedRange<CGFloat>) -> [ClosedRange<CGFloat>] {
        let raise = pixels(in: CGRect(x: x, y: card.lowerBound + 20, width: 1 / scale, height: 1 / scale)).first

        return litSpans(atX: x, above: raise?.lightness ?? 0).filter { line in
            card.lowerBound < line.lowerBound && line.upperBound < card.upperBound
                && line.upperBound - line.lowerBound <= 1 / scale
        }
    }

    /// The row of a card around a control at its right: from the hairline or the card's edge over it to the one under
    /// it, down the 8 of the gap between the control and the words.
    func row(around control: CGRect) throws -> ClosedRange<CGFloat> {
        let x = control.minX - 8
        let card = try #require(litSpans(atX: x).first { $0.contains(control.midY) })
        let bounds = [card.lowerBound] + lines(atX: x, in: card).flatMap { [$0.lowerBound, $0.upperBound] } + [card.upperBound]
        let top = try #require(bounds.last { $0 <= control.minY })
        let foot = try #require(bounds.first { $0 >= control.maxY })

        return top ... foot
    }

    /// The rows of pixels lit in `rect`, from the first's top to the last's foot.
    func litRows(in rect: CGRect) -> ClosedRange<CGFloat>? {
        let columns = Int((rect.minX * scale).rounded())..<Int((rect.maxX * scale).rounded())
        let rows = (Int((rect.minY * scale).rounded())..<Int((rect.maxY * scale).rounded())).filter { y in
            columns.contains { x in (bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)?.lightness ?? 0) > 0.3 }
        }

        guard let first = rows.first, let last = rows.last else {
            return nil
        }
        return CGFloat(first) / scale ... CGFloat(last + 1) / scale
    }
}
