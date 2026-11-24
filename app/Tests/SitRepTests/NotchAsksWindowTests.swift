import AppKit
@testable import SitRep
@testable import SitRepCore
import SitRepEdge
import SitRepPanel
import SitRepTestSupport
import Testing

/// The notch's window with the asks panel open beside the panel, on either edge: wide for it, grown into the screen,
/// taking clicks over the asks panel as over the panel, and none off both. The display is far off every screen, so
/// nothing shows.
@MainActor
@Suite(.backstop)
struct NotchAsksWindowTests {
    private static let display = Display(
        id: "A", frame: CGRect(x: -20000, y: -20000, width: 1512, height: 982),
        visible: CGRect(x: -20000, y: -20000, width: 1512, height: 958)
    )
    private static let frameMS = 1000.0 / 60
    private static let helpDesk = "needs:sr-nw0001"

    @Test(arguments: [EdgeSettings.Edge.left, .right])
    func overTheAsksPanelTheWideWindowTakesClicks(_ side: EdgeSettings.Edge) throws {
        var settings = EdgeSettings()

        settings.edge = side

        let notch = NotchController(settings, on: Self.display, folding: Folding()) { SnoozeSettings() }
        let edge = ScreenEdge(Self.display, settings)
        var time = Displays.now

        defer { notch.window.close() }

        func frames(for ms: Double, at pointer: CGPoint, until done: () -> Bool = { false }) {
            let end = time + ms

            while time < end, !done() {
                time += Self.frameMS
                notch.step(at: time, pointer: pointer)
            }
        }

        notch.isShown = true
        notch.show(Self.board())
        frames(for: 3000, at: CGPoint(x: 3, y: edge.stage.notchY)) {
            notch.run.phase == .open && !notch.run.frame.isMoving
        }
        #expect(notch.window.frame == edge.window)

        let arrow = try Self.arrow(notch.run, mirror: edge.mirror)

        frames(for: Self.frameMS, at: arrow)
        notch.press(at: edge.screenRect(CGRect(origin: arrow, size: .zero)).origin)
        frames(for: Self.frameMS, at: arrow)

        let asks = try #require(notch.run.asksShown), panel = try #require(notch.run.frame.panel)
        let onIt = CGPoint(x: asks.frame.maxX - 40, y: asks.frame.midY)

        #expect(notch.window.frame == edge.window(wide: true))
        frames(for: Self.frameMS, at: onIt)
        #expect(!panel.contains(onIt))
        #expect(notch.window.takesClicks)
        frames(for: Self.frameMS, at: CGPoint(x: asks.frame.maxX + 40, y: asks.frame.midY))
        #expect(!notch.window.takesClicks)
    }

    /// The middle of Help desk redesign's arrow on the stage.
    private static func arrow(_ run: NotchRun, mirror: CGAffineTransform) throws -> CGPoint {
        let panel = try #require(run.frame.panel), index = try #require(run.list.index(of: helpDesk))
        let row = run.list.content.drawnFrame(index), box = RowArrow.box(in: row.size)

        return panel.stagePoint(
            CGPoint(x: row.minX + box.midX, y: row.minY + box.midY), mirror: mirror, scroll: run.scroll
        )
    }

    /// Help desk redesign of Northwind in Needs you, asking a choice.
    private static func board() -> PanelBoard {
        let at = Int(Date().timeIntervalSince1970 * 1000)
        let rows = [
            WatchLine.Row(
                session: "sr-nw0001", name: "Help desk redesign", projectName: "Northwind",
                lines: [.init("ask:sr-nw0001:k1", .ask, ask: "k1", first: "Thread replies?", since: at - 240_000)]
            ),
        ]
        let projects = [
            WatchLine.Project(name: "Northwind", sessions: [
                WatchLine.Session(id: "sr-nw0001", name: "Help desk redesign", state: .needsYou, asks: [
                    WatchLine.Ask(
                        id: "k1", wants: .choice, yes: nil, title: "Thread replies, or keep them flat?",
                        options: ["Threaded", "Flat"], recommended: "Threaded", at: at - 240_000
                    ),
                ]),
            ]),
        ]
        var last = LastBoard()

        _ = last.hear(
            .line(WatchLine(at: at, rows: rows, projects: projects).text),
            at: Date(timeIntervalSince1970: Double(at) / 1000)
        )
        return PanelBoard(last)
    }
}
