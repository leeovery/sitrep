import AppKit
@testable import SitRep
@testable import SitRepCore
@testable import SitRepEdge
@testable import SitRepPanel
import SitRepTestSupport
import Testing

/// The strip's window with the asks panel open beside a tab, on either edge: wide for it, grown into the screen, taking
/// clicks over the asks panel as over the strip and the tab, none off them, and back to the strip's width once it
/// closes. The display is far off every screen, so nothing shows.
@MainActor
@Suite(.backstop)
struct StripAsksWindowTests {
    private static let frameMS = 1000.0 / 60

    @Test(arguments: [EdgeSettings.Edge.left, .right])
    func overTheAsksPanelTheWideWindowTakesClicks(_ side: EdgeSettings.Edge) throws {
        let strip = try Driven(on: side)

        defer { strip.close() }
        try strip.pressArrow()

        let asks = try #require(strip.run.asksShown)
        let onIt = CGPoint(x: asks.frame.maxX - 40, y: asks.frame.minY + 70)

        #expect(strip.controller.window.frame == strip.edge.stripWindow(wide: true))
        strip.frames(for: Self.frameMS, at: onIt)
        #expect(strip.controller.window.takesClicks)

        try strip.pressArrow()
        #expect(strip.run.asksShown == nil)
        #expect(strip.controller.window.frame == strip.edge.stripWindow)
    }
}

/// A strip on the far-off display over a board of one session asking, driven frame by frame with the pointer given on
/// the stage, its tab poured out on the session's mark.
@MainActor
private final class Driven {
    static let display = Display(
        id: "A", frame: CGRect(x: -20000, y: -20000, width: 1512, height: 982),
        visible: CGRect(x: -20000, y: -20000, width: 1512, height: 945)
    )

    let controller: StripController
    let edge: ScreenEdge
    private var time = Displays.now

    var run: StripRun { controller.run }

    init(on side: EdgeSettings.Edge) throws {
        var settings = EdgeSettings()

        settings.edge = side
        settings.show = .strip
        controller = StripController(settings, on: Self.display, folding: Folding()) { SnoozeSettings() }
        edge = ScreenEdge(Self.display, settings)
        controller.isShown = true
        controller.show(NotchAsksWindowTests.board())

        let mark = CGPoint(x: 18, y: run.strip.yOf(.session("sr-nw0001")))

        frames(for: 3000, at: mark) { self.run.strip.liveTab()?.phase == .open && !self.run.frame.isMoving }
        try #require(run.strip.liveTab()?.phase == .open)
        #expect(controller.window.frame == edge.stripWindow)
    }

    func close() {
        controller.window.close()
    }

    func frames(for ms: Double, at pointer: CGPoint, until done: () -> Bool = { false }) {
        let end = time + ms

        while time < end, !done() {
            time += 1000.0 / 60
            controller.step(at: time, pointer: pointer)
        }
    }

    /// A press on the tab's arrow, and the frame after drawn.
    func pressArrow() throws {
        let tab = try #require(run.frame.tabs.first { $0.isLive }), words = try #require(tab.words.last)
        let mirror = edge.stripMirror, box = RowArrow.tabBox(in: words.frame.size, pointsLeft: mirror.a < 0)
        let x = mirror.a < 0 ? tab.box.minX + words.frame.maxX - box.midX : tab.box.minX + words.frame.minX + box.midX
        let arrow = CGPoint(x: x, y: tab.box.minY + words.frame.minY + box.midY)

        frames(for: 1000.0 / 60, at: arrow)
        controller.press(at: edge.screenRect(CGRect(origin: arrow, size: .zero)).origin)
        frames(for: 1000.0 / 60, at: arrow)
    }
}
