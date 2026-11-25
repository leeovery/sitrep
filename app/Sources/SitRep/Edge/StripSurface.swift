import AppKit
import SitRepEdge
import SitRepPanel

/// The strip's window content, drawn in black.
@MainActor
final class StripSurface: EdgeSurface {
    private let drawing = StripView()
    /// What it was last told to draw: internal only for the tests.
    private(set) var scene: StripScene?

    init() {
        super.init(showing: drawing)
    }

    func show(_ scene: StripScene) {
        self.scene = scene
        drawing.show(scene)
    }

    /// The run's latest frame, as it runs in `setting`, through the edge's mirror, hung from the menu bar its window
    /// starts under, the tab's arrow and the asks panel, its tabs' times as of `now` on the wall clock. The real strip
    /// draws through here, and the welcome's stage.
    func draw(
        _ run: StripRun, in setting: StripRun.Setting, mirror: CGAffineTransform, now: Double = Displays.wallNow
    ) {
        show(StripScene(
            frame: run.frame, hoverRow: run.hoverRow, note: run.note, now: now, mirror: mirror,
            menu: setting.stage.menu, reducesMotion: setting.reducesMotion, arrow: run.arrow(in: setting),
            asks: run.asksShown
        ))
    }
}
