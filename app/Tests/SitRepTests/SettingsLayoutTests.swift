import AppKit
import Foundation
@testable import SitRep
@testable import SitRepCore
import SitRepMenu
import SitRepPanel
@testable import SitRepWindow
import SwiftUI
import Testing

/// Settings as the window lays it out, against spec round 8, 4: the real page, its rows and the system's own controls,
/// hosted offscreen in a window never shown, their frames measured.
@MainActor
struct SettingsLayoutTests {
    /// The column's left, at the title's edge, in the page's points.
    private static let edge = CGFloat(44)
    /// The page whose column is the drawing's 704.
    private static let drawingsPage = CGFloat(704 + 88)

    /// The column at a page's width: the page less 44 on each side, as a session's and a project's are, with no cap.
    private static func column(_ page: CGFloat) -> CGFloat {
        page - 2 * edge
    }

    /// The column fills the page, less its insets, at any width: Notch's card spans it, and every control at a row's
    /// right stands 10 in from the card's.
    @Test(arguments: [(564.0, 476.0), (956.0, 868.0), (1003.0, 915.0), (1400.0, 1312.0)])
    func theColumnFillsThePageLessItsInsets(page: CGFloat, column: CGFloat) async throws {
        let hosted = await Hosted.page(width: page)
        let drawn = try Drawn(hosted.hosting)
        let popUp = try hosted.frame(of: #require(hosted.all(NSPopUpButton.self).first))
        let card = try #require(drawn.litSpans(atY: popUp.midY).first)
        let controls = hosted.trailingControls()
        let pixel = 1 / hosted.scale

        #expect((Self.edge ... Self.edge + column).isWithinAPixel(of: card, at: hosted.scale))
        // Edge, Display, Style, Material, Reduce motion; Send Test, Notify me, Notification Settings…; Your turn folds
        // after, Open at login
        #expect(controls.count == 10)
        for control in controls {
            #expect(abs(control.maxX - (Self.edge + column - 10)) < pixel)
        }
    }

    @Test func theControlsKeepTheirOwnWidths() async throws {
        let hosted = await Hosted.page(width: 956)
        let segmented = hosted.all(NSSegmentedControl.self).map(hosted.frame(of:))
        let button = try #require(hosted.all(NSPopUpButton.self).first)
        let popUp = hosted.frame(of: button)

        // Edge, Style, Material: Left · Right, Meniscus · Card, Black · Glass
        #expect(segmented.map { ($0.width * 2).rounded() / 2 } == [106, 155, 109])
        // to the window's half points, where the stock one, in none, rounds to whole ones
        #expect(abs(popUp.width - SystemControlsTests.stock(button.itemArray).intrinsicContentSize.width) <= 0.5)
        // Reduce motion, Notify me of a new ask, Open at login
        #expect(hosted.all(NSSwitch.self).count == 3)
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
        #expect(abs(slider.maxX - (Self.edge + Self.column(956) - 10)) < 0.5)
    }

    /// The page's push buttons at their own widths, as measured in a form, against the right: Send Test 84.5, and
    /// Notification Settings… 158.
    @Test func thePagesPushButtonsKeepTheirOwnWidths() async throws {
        let hosted = await Hosted.page(width: 956)
        let buttons = hosted.buttons()
        let pixel = 1 / hosted.scale

        #expect(buttons.count == 2)
        for (button, width) in zip(buttons, [84.5, 158]) {
            #expect(abs(button.width - width) < pixel)
            #expect(button.height == 24)
            #expect(abs(button.maxX - (Self.edge + Self.column(956) - 10)) < pixel)
        }
    }

    /// At the narrowest column, 476, in each state whose control is widest, the control keeps its own width, 10 in from
    /// the card's right, and the row's line wraps, growing the row past 52, where it no longer fits beside it: windows
    /// on an older plugin, Ghostty not allowed and opening at login waiting on Lee.
    @Test(arguments: [(General.plugin, 139.5), (.login, 158), (.ghostty, 169.5)])
    func aRowThatNeedsSomethingWrapsItsLineBeforeItsButtonShrinks(row: General, width: CGFloat) async throws {
        let hosted = await Hosted.page(width: 564, height: 1400, said: Hosted.needsLee, live: Hosted.live(needsReload: true))
        let drawn = try Drawn(hosted.hosting)
        // General's rows are the page's last
        let controls = hosted.trailingControls()
        let control = controls[controls.count - 3 + row.rawValue]
        let pixel = 1 / hosted.scale

        #expect(abs(control.width - width) < pixel)
        #expect(abs(control.maxX - (Self.edge + Self.column(564) - 10)) < pixel)

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

    /// Down the column, clear of the Show row's pictures, the page is black but for the cards and the desktop corner,
    /// Notch chosen: its card the Show row's 86 over the Notch's rows, 30 from a card to the next header, and the
    /// caption's row of 42 between the corner and its card. Within a pixel at the screen's scale, which lays the page
    /// out.
    @Test func thePagesCardsStandAtTheirHeights() async throws {
        let drawn = try await Hosted.drawn(width: Self.drawingsPage)
        let spans = drawn.litSpans(atX: Self.edge + 232)
        let drawing: [ClosedRange<CGFloat>] = [146 ... 480.5, 536.5 ... 686.5, 728.5 ... 833, 889 ... 1084.5]

        #expect(spans.count == drawing.count)
        for (span, expected) in zip(spans, drawing) {
            #expect(expected.isWithinAPixel(of: span, at: drawn.scale))
        }
    }

    /// Each header's line of 16 stands 10 over what it heads: What stays on screen's card at 146, the desktop corner
    /// at 536.5 and General's card at 889, the first header's line 28 under the title's line of 34 (58 to 92). Each
    /// header's capitals stand alike in their line, so the same distance over what each heads.
    @Test func eachHeaderStands10OverWhatItHeads() async throws {
        let drawn = try await Hosted.drawn(width: Self.drawingsPage)
        let first = try #require(drawn.litSpans(atX: Self.edge + 352).first)
        let heads = [first.lowerBound, 536.5, 889]
        // the header's first word's first letters, which hang below no line: What, Noti, Gene
        let capitals = try heads.map { head in
            try #require(drawn.litRows(in: CGRect(x: Self.edge + 10, y: head - 30, width: 30, height: 24)))
        }
        let pixel = 1 / drawn.scale

        #expect(abs(first.lowerBound - 146) < pixel)
        for (head, capital) in zip(heads, capitals) {
            // inside the line of 16 that ends 10 over the head
            #expect(capital.lowerBound >= head - 10 - 16)
            #expect(capital.upperBound <= head - 10)
            #expect(abs((head - capital.upperBound) - (heads[0] - capitals[0].upperBound)) < pixel)
        }
    }

    /// The title's glyphs, Settings' and a project's of the same name, drawn to the same pixels in the same place, so
    /// the title holds still as Lee goes between the pages.
    @Test func theTitleStandsWhereAProjectsStands() async throws {
        let project = ProjectPage(
            key: "settings", name: "Settings", waiting: 0, open: 0, sessions: [], asksWaiting: 0, asks: [], notes: [],
            parked: [], opened: []
        )
        let projectPage = PageColumn(page: .project(project), now: Date()).environment(\.isStill, true)
        let drawn = try Drawn(Hosted(projectPage, size: CGSize(width: 956, height: 1300)).hosting)
        // the title's line, 58 to 91, clear of the project's line under it
        let title = CGRect(x: Self.edge, y: 50, width: 200, height: 44)

        #expect(drawn.pixels(in: title).contains { $0.lightness > 2 })
        #expect(try await Hosted.drawn(width: 956).pixels(in: title) == drawn.pixels(in: title))
    }

    /// The Notch's card, Show, Edge, Display, Style, Material and Reduce motion: a hairline of 0.5 between each two
    /// rows, none at its top or its foot, 10 in from both its ends. Within a pixel at the screen's scale.
    @Test func aCardsHairlinesAreHalfAPointBetweenItsRowsOnly() async throws {
        let drawn = try await Hosted.drawn(width: Self.drawingsPage)
        let card = try #require(drawn.litSpans(atX: Self.edge + 232).first)
        let lines = { (x: CGFloat) in drawn.lines(atX: Self.edge + x, in: card) }
        let rows: [CGFloat] = [86, 52, 38, 52, 52]
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

    @Test(arguments: [(EdgeSettings.Show.notch, 1124.5), (.strip, 1177.0)])
    func thePageEnds40UnderGeneralsCard(show: EdgeSettings.Show, height: CGFloat) async {
        let page = await Hosted.pageView { $0.show = show }
        let size = NSHostingController(rootView: page).sizeThatFits(in: CGSize(width: 704, height: 10_000))

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

/// General's rows, top to bottom.
enum General: Int, Sendable {
    case plugin, login, ghostty
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

    /// The page's push buttons, top to bottom: SwiftUI draws them itself, so each is found by the focus ring AppKit
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

        // a pull-down keeps a focus ring of its own too
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

    /// The window's page on Settings, `width` wide, as tall as Lee's window unless `height` says.
    static func page(
        width: CGFloat, height: CGFloat = 1069, said: MacSays = allWell, live: LiveBoard = LiveBoard(),
        _ change: (inout EdgeSettings) -> Void = { _ in }
    ) async -> Hosted {
        let page = await pageView(said: said, live: live, change)

        return Hosted(PageColumn(page: .settings, now: Date()) { page }, size: CGSize(width: width, height: height))
    }

    /// The window's page on Settings drawn, Notch chosen unless `change` says, `width` wide and 1300 tall: as a still,
    /// so the whole page draws, but in a window, which lays it out to the screen's pixels, as the window on screen
    /// does.
    static func drawn(width: CGFloat, _ change: (inout EdgeSettings) -> Void = { _ in }) async throws -> Drawn {
        let page = await pageView(change)
        let still = PageColumn(page: .settings, now: Date()) { page }.environment(\.isStill, true)

        return try Drawn(Hosted(still, size: CGSize(width: width, height: 1300)).hosting)
    }

    static let allWell = MacSays(notices: .allowed(.banners), login: LoginItem(.enabled), ghostty: .allowed)
    /// Every General row's widest want: Ghostty not allowed, opening at login waiting on Lee's approval.
    static let needsLee = MacSays(notices: .allowed(.banners), login: LoginItem(.requiresApproval), ghostty: .denied)

    /// The plugin running, its board printed, with two windows on it, on an older plugin or not.
    static func live(needsReload: Bool) -> LiveBoard {
        let live = LiveBoard()
        let window = """
            {"writer":"w","session":"sr-aw3bgs","name":"The Mac app","project":"SitRep",\
            "version":"\(needsReload ? "0.1.0" : "0.2.0")","needsReload":\(needsReload),"where":null,"state":null,\
            "attachedAt":1792440000000}
            """
        let line = """
            {"v":2,"at":1792445574706,"version":"0.2.0","head":{"needYou":0,"sessions":1},"rows":[],"projects":[],\
            "windows":[\(window),\(window)],"new":[],"changed":[]}
            """
        var last = LastBoard()

        last.begin()
        _ = last.hear(.line(line), at: Date())
        live.last = last
        live.plugin = .running(.folder("~/Code/sitrep"), folder: "/Users/lee/Code/sitrep")
        return live
    }

    /// Settings, its Mac saying `said`, read as the page reads it as it appears, with a second display.
    static func pageView(
        said: MacSays = allWell, live: LiveBoard = LiveBoard(),
        defaults: UserDefaults = UserDefaults(suiteName: "com.leeovery.sitrep.layout.\(UUID().uuidString)")!,
        _ change: (inout EdgeSettings) -> Void = { _ in }
    ) async -> SettingsPage {
        let services = SettingsServices(
            displays: {
                [
                    DisplayChoice.Connected(id: "A", name: "Built-in Retina Display", isMain: true),
                    DisplayChoice.Connected(id: "B", name: "Studio Display", isMain: false),
                ]
            },
            hasGlass: true, jump: { _ in }, sendTest: {},
            noticeLeave: { said.notices ?? .unasked }, askForNotices: {}, login: { said.login ?? LoginItem(.notFound) },
            chooseLogin: {}, ghostty: { said.ghostty ?? .unknown }, allowGhostty: { .allowed }, open: { _ in }
        )
        let preferences = Preferences(defaults)
        let settings = SettingsModel(preferences: preferences, live: live, services: services)

        preferences.edit(change)
        settings.readDisplays()
        await settings.read()
        return SettingsPage(settings: settings)
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
