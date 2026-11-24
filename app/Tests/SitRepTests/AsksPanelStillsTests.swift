import AppKit
import Foundation
@testable import SitRep
@testable import SitRepCore
@testable import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The row's arrow and the asks panel in black, and in glass dark and light, drawn by the real run into the real
/// surface at the README desktop's left edge, to read beside Paper's boards E2, F and A2: the pointer on a Needs you
/// row's words, then on its arrow; the asks panel on a session's choice, and on a words ask; and an answer sending, its
/// countdown under way. Only when `SITREP_STILLS` names a folder for them, so a run of the tests writes nothing: black
/// in it, glass in its `glass` and `glass-light` folders.
@MainActor
@Suite(.backstop, .enabled(if: stills != nil))
struct AsksPanelStillsTests {
    private static let frameMS = 1000.0 / 60
    private static let minute = 60_000
    /// The wall clock the stills are drawn at, ms: Wednesday 18 November 2026, 10:30 UTC.
    private static let now = 1_794_997_800_000.0
    private static let settings = EdgeSettings()
    private static let edge = ScreenEdge(
        frame: CGRect(origin: .zero, size: ReadmeDesktop.screen),
        visible: CGRect(
            x: 0, y: 0, width: ReadmeDesktop.screen.width, height: ReadmeDesktop.screen.height - ReadmeDesktop.menuBar
        ),
        edge: settings.edge, along: settings.along
    )
    private static let setting = NotchRun.Setting(
        stage: edge.stage, mirror: edge.mirror(wide: true), style: settings.style, reducesMotion: false,
        isChosen: true
    )
    private static let helpDesk = "needs:sr-nw0001", shifts = "needs:sr-ct0002"

    @Test(arguments: Look.allCases)
    func thePointerOnARowsWords(look: Look) throws {
        let run = try Self.opened()

        try Self.shoot(run, pointer: try Self.words(Self.helpDesk, run), as: "1-row-words", in: look)
    }

    @Test(arguments: Look.allCases)
    func thePointerOnTheRowsArrow(look: Look) throws {
        let run = try Self.opened()

        try Self.shoot(run, pointer: try Self.arrow(Self.helpDesk, run), as: "2-row-arrow", in: look)
    }

    @Test(arguments: Look.allCases)
    func theAsksPanelOnAChoice(look: Look) throws {
        let run = try Self.opened()

        try Self.open(Self.helpDesk, run)
        try Self.shoot(run, pointer: try Self.onTitle(run), as: "3-asks-choice", in: look)
    }

    @Test(arguments: Look.allCases)
    func theAsksPanelOnAWordsAsk(look: Look) throws {
        let run = try Self.opened()

        try Self.open(Self.shifts, run)
        try Self.shoot(run, pointer: try Self.onTitle(run), as: "4-asks-words", in: look)
    }

    /// "Sending Threaded", held 800ms before the still is drawn, so its ring has 60% to run.
    @Test(arguments: Look.allCases)
    func anAnswerSending(look: Look) throws {
        let run = try Self.opened(), at = Date(timeIntervalSince1970: Self.now / 1000 - 0.8)
        let threaded = Answering(.words("Threaded"), to: "k1", of: "sr-nw0001")

        try Self.open(Self.helpDesk, run)
        run.heard(
            .held(HeldAnswer(answering: threaded, heldAt: at, goesAt: at.addingTimeInterval(2))),
            NotchRun.Moment(time: run.time + Self.frameMS, pointer: try Self.onTitle(run), setting: Self.setting)
        )
        try Self.shoot(run, pointer: try Self.onTitle(run), as: "5-sending", in: look)
    }

    // MARK: The run

    /// The run over the board, its panel poured out and settled under the pointer held at the notch's home.
    private static func opened() throws -> NotchRun {
        let run = NotchRun(at: 0, in: setting, measure: AsksMeasure.drawn)
        let home = CGPoint(x: 4, y: edge.stage.notchY)

        _ = run.show(board(), NotchRun.Moment(time: 0, pointer: nil, setting: setting))
        step(run, for: 5000, pointer: home) { run.phase == .open && !run.frame.isMoving }
        try #require(run.phase == .open)
        return run
    }

    private static func open(_ row: String, _ run: NotchRun) throws {
        let arrow = try arrow(row, run)

        step(run, for: frameMS, pointer: arrow)
        try #require(run.press(NotchRun.Moment(time: run.time + frameMS, pointer: arrow, setting: setting)) == .asks)
    }

    private static func step(_ run: NotchRun, for ms: Double, pointer: CGPoint, until done: () -> Bool = { false }) {
        let end = run.time + ms

        while run.time < end, !done() {
            let time = run.time + frameMS

            run.step(NotchRun.Moment(time: time, pointer: pointer, pointerAt: time, setting: setting))
        }
    }

    /// A row's frame on the stage.
    private static func row(_ key: String, _ run: NotchRun) throws -> CGRect {
        let panel = try #require(run.frame.panel), index = try #require(run.list.index(of: key))

        return run.list.content.itemFrame(index).offsetBy(dx: panel.frame.minX, dy: panel.frame.minY - run.scroll)
    }

    private static func words(_ key: String, _ run: NotchRun) throws -> CGPoint {
        let row = try row(key, run)

        return CGPoint(x: row.minX + 90, y: row.midY)
    }

    private static func arrow(_ key: String, _ run: NotchRun) throws -> CGPoint {
        let row = try row(key, run), box = RowArrow.box(in: row.size)

        return CGPoint(x: row.minX + box.midX, y: row.minY + box.midY)
    }

    /// On the asks panel's title, where nothing lifts.
    private static func onTitle(_ run: NotchRun) throws -> CGPoint {
        let asks = try #require(run.asksShown(in: setting))

        return CGPoint(x: asks.frame.minX + asks.layout.title.midX, y: asks.frame.minY + asks.layout.title.midY)
    }

    /// What a still is drawn in, and the folder it goes in.
    enum Look: CaseIterable {
        case black, glass, glassLight

        var material: EdgeSettings.Material { self == .black ? .black : .glass }

        var appearance: NSAppearance? { NSAppearance(named: self == .glassLight ? .aqua : .darkAqua) }

        var folder: String? {
            switch self {
            case .black: nil
            case .glass: "glass"
            case .glassLight: "glass-light"
            }
        }
    }

    /// The run moved on a few frames with the pointer here, drawn in the look, and shot from the screen's edge past the
    /// asks panel, over the panel's height and the asks panel's, with room round them.
    private static func shoot(_ run: NotchRun, pointer: CGPoint, as name: String, in look: Look) throws {
        let root = try #require(stills), surface = NotchSurface()
        let folder = look.folder.map { root.appending(path: $0) } ?? root

        step(run, for: 6 * frameMS, pointer: pointer)
        surface.appearance = look.appearance
        surface.material = look.material
        surface.frame = CGRect(origin: .zero, size: edge.window(wide: true).size)
        surface.draw(run, in: setting, mirror: edge.mirror(wide: true), now: now)

        let outline = run.frame.outline.boundingBox
        let shown = run.asksShown(in: setting).map { outline.union($0.frame) } ?? outline
        let cut = CGRect(x: 0, y: shown.minY - 40, width: AsksLayout.reach + 24, height: shown.height + 80)
        let shot = look == .black
            ? try EdgeShot(surface, cut: cut).shoot(turned: Running.at(0.3)) : try cached(surface, cut)

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try shot.png().write(to: folder.appending(path: "\(name).png"))
    }

    /// The glass, whose SwiftUI draws only into a view's cache out of a window, over the desktop's wallpaper: the
    /// Liquid Glass itself is the window server's, which draws none here.
    private static func cached(_ surface: NSView, _ cut: CGRect) throws -> Canvas {
        let canvas = try Canvas(cut.size)
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(cut.width * Canvas.scale),
            pixelsHigh: Int(cut.height * Canvas.scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )?.retagging(with: .sRGB))

        bitmap.size = cut.size
        surface.layoutSubtreeIfNeeded()
        surface.cacheDisplay(in: cut, to: bitmap)
        try ReadmeDesktop.drawWallpaper(cut, in: canvas.context)
        canvas.draw(try #require(bitmap.cgImage), in: CGRect(origin: .zero, size: cut.size))
        return canvas
    }

    // MARK: The board

    /// Paper's: in Needs you, Help desk redesign of Northwind asking two, a choice and a yes; Shift schedules of
    /// Contoso asking for words; Invoice ledger of Fabrikam stopped at a permission prompt; and two at work.
    private static func board() -> PanelBoard {
        let ago = { (minutes: Int) in Int(now) - minutes * minute }
        let rows = [
            WatchLine.Row(
                session: "sr-nw0001", name: "Help desk redesign", projectName: "Northwind",
                lines: [
                    .init("ask:sr-nw0001:k1", .ask, ask: "k1", first: "Thread replies?", since: ago(4)),
                    .init("ask:sr-nw0001:k2", .ask, ask: "k2", first: "Review Tickets & Replies", since: ago(12)),
                ]
            ),
            WatchLine.Row(
                session: "sr-ct0002", name: "Shift schedules", projectName: "Contoso",
                lines: [.init("ask:sr-ct0002:k1", .ask, ask: "k1", first: "Empty rota words", since: ago(7))]
            ),
            WatchLine.Row(
                session: "sr-fb0003", name: "Invoice ledger", projectName: "Fabrikam",
                lines: [.init("stop:w3", .permission, writer: "w3", first: .init(lead: "Allow"), since: ago(2))]
            ),
            WatchLine.Row(
                session: "sr-wg0004", name: "Mobile app", projectName: "Woodgrove",
                lines: [.init("work:sr-wg0004", .working, first: .init(lead: "Running", mono: "tests"), since: ago(3))]
            ),
            WatchLine.Row(
                session: "sr-lw0005", name: "Data import", projectName: "Litware",
                lines: [.init("work:sr-lw0005", .working, first: "Mapping the import's columns", since: ago(6))]
            ),
        ]
        let projects = [
            WatchLine.Project(name: "Northwind", sessions: [
                WatchLine.Session(id: "sr-nw0001", name: "Help desk redesign", state: .needsYou, asks: [
                    WatchLine.Ask(
                        id: "k1", wants: .choice, yes: nil, title: "Thread replies, or keep them flat?",
                        options: ["Threaded", "Flat"], recommended: "Threaded", at: ago(4)
                    ),
                    WatchLine.Ask(id: "k2", wants: .yes, yes: "Approve", title: "Review Tickets & Replies, round 1"),
                ]),
            ]),
            WatchLine.Project(name: "Contoso", sessions: [
                WatchLine.Session(id: "sr-ct0002", name: "Shift schedules", state: .needsYou, asks: [
                    WatchLine.Ask(id: "k1", wants: .words, yes: nil, title: "Say what an empty rota should read"),
                ]),
            ]),
        ]
        var last = LastBoard()

        _ = last.hear(
            .line(WatchLine(at: Int(now), version: "0.2.0", rows: rows, projects: projects).text),
            at: Date(timeIntervalSince1970: now / 1000)
        )
        return PanelBoard(last)
    }
}

/// Where the stills are drawn.
private let stills = ProcessInfo.processInfo.environment["SITREP_STILLS"].map(URL.init(fileURLWithPath:))
