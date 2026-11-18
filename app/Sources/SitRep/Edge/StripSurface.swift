import AppKit
import SitRepEdge
import SitRepPanel

/// The strip's window content, drawn in the material chosen: the last frame, replayed into a new drawing.
@MainActor
final class StripSurface: EdgeSurface<any StripDrawing> {
    /// What it was last told to draw: internal only for the tests.
    private(set) var scene: StripScene?

    init() {
        super.init(make: Self.drawing, view: { $0 })
    }

    func show(_ scene: StripScene) {
        self.scene = scene
        drawing.show(scene)
    }

    /// The run's latest frame, as it runs in `setting`, through the edge's mirror, hung from the menu bar its window
    /// starts under, its tabs' times as of `now` on the wall clock. The real strip draws through here, and the
    /// welcome's stage.
    func draw(
        _ run: StripRun, in setting: StripRun.Setting, mirror: CGAffineTransform, now: Double = Displays.wallNow
    ) {
        show(StripScene(
            frame: run.frame, hoverRow: run.hoverRow, note: run.note, now: now, mirror: mirror,
            menu: setting.stage.menu, reducesMotion: setting.reducesMotion
        ))
    }

    override func replay() {
        scene.map(drawing.show)
    }

    private static func drawing(_ material: EdgeSettings.Material) -> any StripDrawing {
        if #available(macOS 26, *), material == .glass {
            return StripGlassView()
        }
        return StripView()
    }
}
