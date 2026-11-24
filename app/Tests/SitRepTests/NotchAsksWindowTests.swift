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
    static let display = Display(
        id: "A", frame: CGRect(x: -20000, y: -20000, width: 1512, height: 982),
        visible: CGRect(x: -20000, y: -20000, width: 1512, height: 958)
    )
    static let frameMS = 1000.0 / 60
    private static let helpDesk = "needs:sr-nw0001"

    @Test(arguments: [EdgeSettings.Edge.left, .right])
    func overTheAsksPanelTheWideWindowTakesClicks(_ side: EdgeSettings.Edge) throws {
        let notch = try Driven(on: side)

        defer { notch.close() }
        try notch.openAsks()

        let asks = try #require(notch.run.asksShown), panel = try #require(notch.run.frame.panel)
        let onIt = CGPoint(x: asks.frame.maxX - 40, y: asks.frame.midY)

        #expect(notch.controller.window.frame == notch.edge.window(wide: true))
        notch.frames(for: Self.frameMS, at: onIt)
        #expect(!panel.contains(onIt))
        #expect(notch.controller.window.takesClicks)
        notch.frames(for: Self.frameMS, at: CGPoint(x: asks.frame.maxX + 40, y: asks.frame.midY))
        #expect(!notch.controller.window.takesClicks)
    }

    /// The frame the window widens or narrows on is drawn into the window as it now is: the black and the light
    /// mirrored across its new width, where the rows and the asks panel are, never across the width it had.
    @Test(arguments: [EdgeSettings.Edge.left, .right], [EdgeSettings.Material.black, .glass])
    func wideningOrNarrowingTheBlackIsDrawnAcrossTheNewWidth(
        _ side: EdgeSettings.Edge, material: EdgeSettings.Material
    ) throws {
        let notch = try Driven(on: side, material: material)

        defer { notch.close() }
        try notch.openAsks()
        #expect(notch.controller.window.frame == notch.edge.window(wide: true))
        #expect(notch.drawsTheBlack(through: notch.edge.mirror(wide: true)))

        try notch.pressArrow()
        #expect(notch.run.asksShown == nil)
        #expect(notch.controller.window.frame == notch.edge.window)
        #expect(notch.drawsTheBlack(through: notch.edge.mirror))
    }

    /// The middle of Help desk redesign's arrow on the stage.
    static func arrow(_ run: NotchRun, mirror: CGAffineTransform) throws -> CGPoint {
        let panel = try #require(run.frame.panel), index = try #require(run.list.index(of: helpDesk))
        let row = run.list.content.laidFrame(index), box = RowArrow.box(in: row.size)

        return panel.stagePoint(
            CGPoint(x: row.minX + box.midX, y: row.minY + box.midY), mirror: mirror, scroll: run.scroll
        )
    }

    /// Help desk redesign of Northwind in Needs you, asking a choice.
    static func board() -> PanelBoard {
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

/// A notch on the far-off display over the board, driven frame by frame with the pointer given on the stage.
@MainActor
private final class Driven {
    let controller: NotchController
    let edge: ScreenEdge
    private var time = Displays.now

    var run: NotchRun { controller.run }

    /// Shown, over the board, its panel opened by the pointer held on the notch, and at rest.
    init(on side: EdgeSettings.Edge, material: EdgeSettings.Material = .black) throws {
        var settings = EdgeSettings()

        settings.edge = side
        settings.material = material
        controller = NotchController(settings, on: NotchAsksWindowTests.display, folding: Folding()) {
            SnoozeSettings()
        }
        edge = ScreenEdge(NotchAsksWindowTests.display, settings)
        controller.isShown = true
        controller.show(NotchAsksWindowTests.board())
        frames(for: 3000, at: CGPoint(x: 3, y: edge.stage.notchY)) {
            self.run.phase == .open && !self.run.frame.isMoving
        }
        try #require(run.phase == .open)
        #expect(controller.window.frame == edge.window)
    }

    func close() {
        controller.window.close()
    }

    func frames(for ms: Double, at pointer: CGPoint, until done: () -> Bool = { false }) {
        let end = time + ms

        while time < end, !done() {
            time += NotchAsksWindowTests.frameMS
            controller.step(at: time, pointer: pointer)
        }
    }

    /// The asks panel opened from Help desk redesign's arrow, and the frame after drawn.
    func openAsks() throws {
        try pressArrow()
        try #require(run.asksShown != nil)
    }

    /// A press on Help desk redesign's arrow, and the frame after drawn.
    func pressArrow() throws {
        let arrow = try NotchAsksWindowTests.arrow(run, mirror: edge.mirror)

        frames(for: NotchAsksWindowTests.frameMS, at: arrow)
        controller.press(at: edge.screenRect(CGRect(origin: arrow, size: .zero)).origin)
        frames(for: NotchAsksWindowTests.frameMS, at: arrow)
    }

    /// Whether the black's outline is drawn in the window through this mirror, to within half a point.
    func drawsTheBlack(through mirror: CGAffineTransform) -> Bool {
        let box = run.frame.outline.boundingBoxOfPath
        let drawn = controller.surface.drawing.onView(box), wanted = box.applying(mirror)

        return abs(drawn.minX - wanted.minX) < 0.5 && abs(drawn.maxX - wanted.maxX) < 0.5
    }
}
