import AppKit
import SitRepPanel

/// The strip's window content, drawn in the material chosen: the last frame, replayed into a new drawing.
@MainActor
final class StripSurface: EdgeSurface<any StripDrawing> {
    private var scene: StripScene?

    init() {
        super.init(make: Self.drawing, view: { $0 })
    }

    func show(_ scene: StripScene) {
        self.scene = scene
        drawing.show(scene)
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
