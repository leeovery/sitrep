import AppKit
import SitRepEdge
import SitRepPanel

/// The notch's window content, drawn in the material chosen: what it was told last, replayed into a new drawing.
@MainActor
final class NotchSurface: EdgeSurface<any NotchDrawing> {
    private var list: PanelList?
    private var scene: NotchScene?
    private var light: (placed: Frame.Light, outline: CGPath, colours: LiveLight)?

    init() {
        super.init(make: Self.drawing, view: { $0 })
    }

    func show(_ list: PanelList) {
        self.list = list
        drawing.show(list)
    }

    func show(_ scene: NotchScene) {
        self.scene = scene
        drawing.show(scene)
    }

    func showLight(_ placed: Frame.Light, outline: CGPath, colours: LiveLight) {
        light = (placed, outline, colours)
        drawing.showLight(placed, outline: outline, colours: colours)
    }

    func wash(_ rows: Set<String>, at time: Double) {
        drawing.wash(rows, at: time)
    }

    override func replay() {
        list.map(drawing.show)
        scene.map(drawing.show)
        if let light {
            drawing.showLight(light.placed, outline: light.outline, colours: light.colours)
        }
    }

    private static func drawing(_ material: EdgeSettings.Material) -> any NotchDrawing {
        if #available(macOS 26, *), material == .glass {
            return NotchGlassView()
        }
        return NotchView()
    }
}
