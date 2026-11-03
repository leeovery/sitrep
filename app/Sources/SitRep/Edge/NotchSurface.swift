import AppKit
import SitRepEdge
import SitRepPanel

/// The notch's window content, drawn in the material chosen: what it was told last, replayed into a new drawing.
@MainActor
final class NotchSurface: EdgeSurface<any NotchDrawing> {
    /// The list and the frame it was last told to draw, each internal only for the tests.
    private(set) var list: PanelList?
    private(set) var scene: NotchScene?
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

    /// The run's latest frame, as it runs in `setting`: the panel's list, the shape and the content through `mirror`,
    /// the edge's as it stands once the frame has swapped edges, the row under the pointer as the frame saw it, and the
    /// light. The real notch draws through here, and the welcome's stage.
    func draw(_ run: NotchRun, in setting: NotchRun.Setting, mirror: CGAffineTransform) {
        show(run.list)
        show(NotchScene(
            frame: run.frame, hover: run.seen.flatMap { run.item(at: $0, in: setting) }, scroll: run.scroll,
            time: run.time, now: Displays.wallNow, mirror: mirror, calendar: run.calendar
        ))
        drawLight(run, at: run.lightTime(run.time), reducesMotion: setting.reducesMotion)
    }

    /// The run's light at this time on its own clock, round the frame's outline.
    func drawLight(_ run: NotchRun, at time: Double, reducesMotion: Bool) {
        showLight(run.frame.light, outline: run.frame.outline, colours: LiveLight(
            time: time, sinceAsk: run.sinceAsk(at: time), reducesMotion: reducesMotion
        ))
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
