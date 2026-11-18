import AppKit
import Foundation
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The README's pictures (`app/screens`), drawn offscreen on one made-up Mac's desktop (`ReadmeDesktop`): Claude Code
/// in a Ghostty window, the board docked at its side, from the cells `screens/window.ts` wrote; the notch at the
/// screen's left edge, filmed as the pointer comes to it, it opens and the pointer leaves; and the strip there at rest;
/// the notch and the strip each by the real run into the real surface from a made-up board seeded as the tests seed
/// theirs. Only when `SITREP_SCREENS` names the folder they are drawn in, which holds `window.json`, so a run of the
/// tests writes nothing.
@MainActor
@Suite(.backstop, .enabled(if: screens != nil))
struct ReadmeScreensTests {
    /// The desktop shown round the window.
    private static let margin = 64.0
    /// How far the window stands from the screen's right, and under the menu bar.
    private static let windowInset = CGSize(width: 72, height: 44)
    /// The desktop shown over and under the notch's panel open, and the strip.
    private static let edgeMargin = 36.0
    /// How much of the screen shows from its edge: 220 wide with the bezel, the least a docs page shows it at.
    private static let stripWidth = 214.0
    /// Where in their turn the strip's working arcs are caught: an eighth of the way round, the same at every run.
    private static let stripTurned = 0.125
    private static let frameMS = 1000.0 / 60
    private static let minute = 60_000
    /// The wall clock the pictures are drawn at, ms: Wednesday 18 November 2026, 10:30 in `calendar`, held there.
    private static let now = 1_794_997_800_000.0
    /// The calendar the wake is worded on: the Gregorian in UTC, whatever the Mac's own.
    private static let calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    /// Claude Code in Ghostty, as `screens/window.ts` laid it out, on the desktop towards the screen's right.
    @Test func theWindow() throws {
        let folder = try #require(screens)
        let terminal = try JSONDecoder().decode(
            Terminal.self, from: Data(contentsOf: folder.appending(path: "window.json"))
        )
        let window = GhosttyWindow(terminal, fonts: try TerminalFonts())
        let at = CGPoint(
            x: ReadmeDesktop.screen.width - window.size.width - Self.windowInset.width,
            y: ReadmeDesktop.menuBar + Self.windowInset.height
        )
        let cut = CGRect(origin: at, size: window.size).insetBy(dx: -Self.margin, dy: -Self.margin)
        let canvas = try Canvas(cut.size)

        try ReadmeDesktop.drawWallpaper(cut, in: canvas.context)
        try window.draw(at: CGPoint(x: Self.margin, y: Self.margin), on: canvas)
        try canvas.png().write(to: folder.appending(path: "window.png"))
    }

    /// The notch at rest, lit for what needs Lee; the pointer coming to it, so it reaches for it and pours open with
    /// Snoozed unfolded; resting there; then leaving, so the edge clings to it, lets go and the notch comes home.
    @Test func theNotchOpening() throws {
        let folder = try #require(screens)
        let settings = EdgeSettings(), edge = Self.edge(settings)
        let setting = NotchRun.Setting(
            stage: edge.stage, mirror: edge.mirror, style: settings.style, reducesMotion: false, isChosen: true
        )
        let home = CGPoint(x: 4, y: edge.stage.notchY), board = try Self.board()
        let open = try Self.opened(board, home, setting).insetBy(dx: 0, dy: -Self.edgeMargin)
        let cut = CGRect(x: 0, y: open.minY, width: ScreenEdge.depth + 16, height: open.height)
        let outside = CGPoint(x: cut.maxX + 40, y: home.y + 160), away = CGPoint(x: cut.maxX + 40, y: home.y + 30)
        let run = Self.run(board, setting), surface = NotchSurface()

        surface.frame = CGRect(origin: .zero, size: edge.window.size)
        Self.step(run, for: 2000, pointer: outside, setting, each: {
            surface.draw(run, in: setting, mirror: edge.mirror, now: Self.now)
        })

        let film = try NotchFilm(
            run, surface: surface, setting: setting, mirror: edge.mirror, now: Self.now, cut: cut,
            into: folder.appending(path: "notch")
        )

        try film.rest(1200, pointer: outside)
        try film.glide(from: outside, to: home, over: 900)
        try film.settle(.open, pointer: home)
        try film.rest(2400, pointer: home)
        try film.glide(from: home, to: away, over: 1000)
        try film.settle(.closed, pointer: away)
        try film.rest(1000, pointer: away)
        try film.finish()
    }

    /// The strip at rest at the screen's left edge, as Lee's settings leave it at first, Grows and Black, the pointer
    /// away, each mark's ring telling its state: Snoozed unfolded, as the notch has it, and a session on its own work
    /// among the working.
    @Test func theStrip() throws {
        let folder = try #require(screens)
        let settings = EdgeSettings(), edge = Self.edge(settings)
        let setting = StripRun.Setting(stage: edge.stripStage, reducesMotion: false)
        let folding = Folding()

        folding.set(.snoozed, folded: false)

        let run = StripRun(at: 0, in: setting, settings, folding: folding, measure: StripWordsLayer.measure)
        let surface = StripSurface()

        run.show(try Self.board(onItsWork: true), StripRun.Moment(time: 0, pointer: nil, setting: setting))
        repeat {
            run.step(StripRun.Moment(time: run.time + Self.frameMS, pointer: nil, setting: setting))
        } while run.frame.isMoving && run.time < 5000
        try #require(!run.frame.isMoving)
        surface.frame = CGRect(origin: .zero, size: edge.stripWindow.size)
        surface.draw(run, in: setting, mirror: edge.stripMirror, now: Self.now)

        let strip = run.frame.strip.boundingBoxOfPath.insetBy(dx: 0, dy: -Self.edgeMargin)
        let cut = CGRect(x: 0, y: strip.minY, width: Self.stripWidth, height: strip.height)
        let shot = try EdgeShot(surface, cut: cut, hung: edge.stripStage.menu)

        try shot.shoot(turned: { _ in Self.stripTurned }).png().write(to: folder.appending(path: "strip.png"))
    }

    /// The panel's bounds once poured out and settled under the pointer held at the notch's home.
    private static func opened(_ board: PanelBoard, _ home: CGPoint, _ setting: NotchRun.Setting) throws -> CGRect {
        let run = Self.run(board, setting)

        step(run, for: 5000, pointer: home, setting, until: { run.phase == .open && !run.frame.isMoving })
        try #require(run.phase == .open)
        return run.frame.outline.boundingBox
    }

    /// The notch's run showing the board, Snoozed unfolded, its wake worded on `calendar`.
    private static func run(_ board: PanelBoard, _ setting: NotchRun.Setting) -> NotchRun {
        let folding = Folding()

        folding.set(.snoozed, folded: false)

        let run = NotchRun(at: 0, in: setting, folding: folding, calendar: calendar)

        _ = run.show(board, NotchRun.Moment(time: 0, pointer: nil, setting: setting))
        return run
    }

    /// Frames a refresh apart for `ms`, or until `done`, the pointer held where it is, `each` after every frame.
    private static func step(
        _ run: NotchRun, for ms: Double, pointer: CGPoint, _ setting: NotchRun.Setting, until done: () -> Bool = { false },
        each: () -> Void = {}
    ) {
        let end = run.time + ms

        while run.time < end, !done() {
            let time = run.time + frameMS

            run.step(NotchRun.Moment(time: time, pointer: pointer, pointerAt: time, setting: setting))
            each()
        }
    }

    /// Six sessions over five projects: two asking, two stopped at Lee's turn, two at work, one of them running a
    /// command, and with `onItsWork` a seventh, on its own work, waiting on the agents it started; and two snoozed, an
    /// ask until Lee's morning in two days and a turn until it moves. As of `now`, so each row's age and the wake's
    /// weekday read the same at every run.
    private static func board(onItsWork: Bool = false) throws -> PanelBoard {
        let at = Date(timeIntervalSince1970: now / 1000)
        let ago = { (minutes: Int) in Int(now) - minutes * minute }
        let later = try #require(calendar.date(byAdding: .day, value: 2, to: at))
        let morning = try #require(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: later))
        let ownWork = WatchLine.Row(
            session: "sr-fb0009", name: "Catalog sync", projectName: "Fabrikam",
            lines: [
                .init("turn:sr-fb0009", .onItsWork, first: .init(lead: "Waiting on", subject: "2 agents"), since: ago(15)),
            ]
        )
        let rows = [
            WatchLine.Row(
                session: "sr-nw0001", name: "Help desk redesign", projectName: "Northwind",
                lines: [
                    .init("ask:sr-nw0001:k1", .ask, ask: "k1", first: "Review Tickets & Replies, round 1", since: ago(4)),
                    .init("ask:sr-nw0001:k2", .ask, ask: "k2", first: "Thread replies, or keep them flat?", since: ago(12)),
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
                session: "sr-ts0004", name: "Release notes", projectName: "Tailspin",
                lines: [.init("turn:sr-ts0004", .yourTurn, first: "Write the release notes", since: ago(31))]
            ),
            WatchLine.Row(
                session: "sr-nw0005", name: "Invoice ledger", projectName: "Northwind",
                lines: [.init("turn:sr-nw0005", .working, first: "Exporting the ledger as CSV", since: ago(2))]
            ),
            WatchLine.Row(
                session: "sr-wg0006", name: "Mobile app", projectName: "Woodgrove",
                lines: [
                    .init("turn:sr-wg0006", .working, first: .init(lead: "Running", mono: "npm test"), since: ago(6)),
                ]
            ),
        ] + (onItsWork ? [ownWork] : [])
        let snoozed = [
            WatchLine.SnoozedRow(
                session: "sr-ct0007", name: "Onboarding flow", projectName: "Contoso",
                lines: [
                    .init(
                        "ask:sr-ct0007:k1", ask: "k1", first: "Pick the onboarding steps", since: ago(90),
                        wakesAt: Int(morning.timeIntervalSince1970 * 1000)
                    ),
                ]
            ),
            WatchLine.SnoozedRow(
                session: "sr-lw0008", name: "Data import", projectName: "Litware",
                lines: [.init("turn:sr-lw0008", .yourTurn, first: "Map the import's columns", since: ago(140), wakesAt: nil)]
            ),
        ]
        var last = LastBoard()

        _ = last.hear(.line(WatchLine(at: Int(now), version: "0.2.0", rows: rows, snoozed: snoozed).text), at: at)
        return PanelBoard(last)
    }

    /// The screen's edge as Lee's settings place it.
    private static func edge(_ settings: EdgeSettings) -> ScreenEdge {
        let screen = ReadmeDesktop.screen

        return ScreenEdge(
            frame: CGRect(origin: .zero, size: screen),
            visible: CGRect(x: 0, y: 0, width: screen.width, height: screen.height - ReadmeDesktop.menuBar),
            edge: settings.edge, along: settings.along
        )
    }
}

/// Where the pictures are drawn.
private let screens = ProcessInfo.processInfo.environment["SITREP_SCREENS"].map(URL.init(fileURLWithPath:))
