import AppKit
import Foundation
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import SwiftUI
import Testing

/// The README's screens of the app (`app/screens`), drawn offscreen by the real runs into the real surfaces, from a
/// made-up board seeded as the tests seed theirs: the notch's panel out, the strip with a mark's tab poured, and
/// Settings' Snooze pane. Only when `SITREP_SCREENS` names a folder for them, so a run of the tests writes nothing.
@MainActor
@Suite(.backstop, .enabled(if: screens != nil))
struct ReadmeScreensTests {
    /// A 14-inch MacBook Pro's screen, under its menu bar.
    private static let screen = CGSize(width: 1512, height: 982), menuBar = 37.0
    /// What the edge stands over in a picture: the pane's screens' ground, Tokyo Night's, so the set reads as one.
    private static let desktop = CGColor(srgbRed: 0x1A / 255, green: 0x1B / 255, blue: 0x26 / 255, alpha: 1)
    /// The desktop shown round the shape: the panel's front corner's radius.
    private static let margin = 24.0
    /// The display's black bezel shown beside the screen's edge, which the shapes flare into (DESIGN, "The notch and its
    /// panel").
    private static let bezel = 6.0
    private static let frameMS = 1000.0 / 60

    private static let minute = 60_000

    /// Four sessions over four projects: two asking, one at Lee's turn, one at work, by the wall clock now, so each
    /// row's age reads the same at every run.
    private static func board() -> PanelBoard {
        let now = Int(Displays.wallNow)
        let ago = { (minutes: Int) in now - minutes * minute }
        let rows = [
            WatchLine.Row(
                session: "sr-nw0001", name: "Help desk redesign", projectName: "Northwind",
                lines: [
                    .init("ask:sr-nw0001:k1", .ask, ask: "k1", first: "Review Tickets & Replies, round 1", since: ago(4)),
                    .init("ask:sr-nw0001:k2", .ask, ask: "k2", first: "Choose the reply editor", since: ago(12)),
                ]
            ),
            WatchLine.Row(
                session: "sr-ct0002", name: "Shift schedules", projectName: "Contoso",
                lines: [.init("ask:sr-ct0002:k1", .ask, ask: "k1", first: "Approve the rota", since: ago(26))]
            ),
            WatchLine.Row(
                session: "sr-fb0003", name: "Supplier portal", projectName: "Fabrikam",
                lines: [.init("turn:sr-fb0003", .yourTurn, first: "Import the supplier list", since: ago(9))]
            ),
            WatchLine.Row(
                session: "sr-nw0004", name: "Invoice ledger", projectName: "Northwind",
                lines: [.init("turn:sr-nw0004", .working, first: "Exporting the ledger as CSV", since: ago(2))]
            ),
        ]
        var last = LastBoard()

        _ = last.hear(.line(WatchLine(at: now, version: "0.2.0", rows: rows).text), at: Date())
        return PanelBoard(last)
    }

    /// The screen's edge as Lee's settings place it.
    private static func edge(_ settings: EdgeSettings) -> ScreenEdge {
        ScreenEdge(
            frame: CGRect(origin: .zero, size: screen),
            visible: CGRect(x: 0, y: 0, width: screen.width, height: screen.height - menuBar),
            edge: settings.edge, along: settings.along
        )
    }

    /// The notch at its home, its panel poured out and settled under the pointer held on it, as the real notch draws
    /// it.
    @Test func theNotch() throws {
        let settings = EdgeSettings(), edge = Self.edge(settings), setting = NotchRun.Setting.on(edge, settings)
        let run = NotchRun(at: 0, in: setting), surface = NotchSurface()
        let home = CGPoint(x: 4, y: edge.stage.notchY)
        let moment = { (time: Double) in NotchRun.Moment(time: time, pointer: home, pointerAt: time, setting: setting) }

        surface.frame = CGRect(origin: .zero, size: edge.window.size)
        _ = run.show(Self.board(), moment(0))
        while run.phase != .open || run.frame.isMoving, run.time < 5000 {
            run.step(moment(run.time + Self.frameMS))
        }
        #expect(run.phase == .open)
        surface.draw(run, in: setting, mirror: edge.mirror)

        try Self.write(surface, cut: run.frame.outline.boundingBox, "notch")
    }

    /// The strip at Grows, the pointer resting on the second session's mark until its tab has poured, so the tab stands
    /// near the strip's middle, as the real strip draws it.
    @Test func theStrip() throws {
        var settings = EdgeSettings()

        settings.show = .strip

        let edge = Self.edge(settings), setting = StripRun.Setting.on(edge, settings)
        let run = StripRun(at: 0, in: setting, settings, measure: StripWordsLayer.measure)
        let surface = StripSurface()
        let moment = { (time: Double, pointer: CGPoint?) in
            StripRun.Moment(time: time, pointer: pointer, pointerAt: time, setting: setting)
        }
        let board = Self.board()

        surface.frame = CGRect(origin: .zero, size: edge.stripWindow.size)
        run.show(board, moment(0, nil))
        Self.settle(run) { moment($0, nil) }

        let mark = try #require(board.sessions.dropFirst().first.flatMap { run.markTarget(ofMark: $0.markID) })

        Self.settle(run) { moment($0, mark) }
        #expect(run.frame.tabs.contains { $0.isLive })
        surface.draw(run, in: setting, mirror: edge.stripMirror)

        let shape = run.frame.tabs.reduce(run.frame.strip.boundingBox) { $0.union($1.outline.boundingBox) }

        // the frame is the screen's, from its top; the strip's window hangs from under the menu bar
        try Self.write(surface, cut: shape.offsetBy(dx: 0, dy: -setting.stage.menu), "strip")
    }

    /// Settings' Snooze pane at the window's first width, as tall as it is, dark and light.
    @Test(arguments: [ColorScheme.dark, .light])
    func settingsSnooze(scheme: ColorScheme) async throws {
        let settings = await Hosted.settings()
        let width = SettingsWindow.size.width - 188
        let view = SettingsPaneContent(pane: .snooze, settings: settings)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width)
        let height = NSHostingView(rootView: view).fittingSize.height
        let pane = view
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color(nsColor: .windowBackgroundColor))
        let name = scheme == .dark ? "settings-snooze" : "settings-snooze-light"

        try Still.png(pane, size: CGSize(width: width, height: height), scheme: scheme)
            .write(to: try #require(screens).appending(path: "\(name).png"))
    }

    /// Frames a refresh apart until the strip stops moving.
    private static func settle(_ run: StripRun, _ moment: (Double) -> StripRun.Moment) {
        let end = run.time + 5000

        repeat {
            run.step(moment(run.time + frameMS))
        } while run.frame.isMoving && run.time < end
    }

    /// An edge's drawing over the desktop, cut from the screen's edge to its shape's front, flares and all, with the
    /// margin round it and the bezel beside the edge. Its layers are drawn out of their view, under `Drawn`'s flipped
    /// root, so the flip AppKit gave them for the view comes off first.
    private static func write(_ surface: NSView, cut shape: CGRect, _ name: String) throws {
        let drawing = try #require(surface.subviews.first?.layer)
        let cut = CGRect(x: 0, y: shape.minY - margin, width: shape.maxX + margin, height: shape.height + 2 * margin)
            .intersection(surface.bounds)

        drawing.isGeometryFlipped = false
        try Still.png(drawing, over: desktop, cut: cut, bezel: bezel)
            .write(to: try #require(screens).appending(path: "\(name).png"))
    }
}

/// Where the screens go.
private let screens = ProcessInfo.processInfo.environment["SITREP_SCREENS"].map(URL.init(fileURLWithPath:))
