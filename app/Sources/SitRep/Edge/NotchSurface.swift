import AppKit
import SitRepEdge
import SitRepPanel

/// The notch's window content, drawn in black.
@MainActor
final class NotchSurface: EdgeSurface {
    let drawing = NotchView()
    /// The list and the frame it was last told to draw, each internal only for the tests.
    private(set) var list: PanelList?
    private(set) var scene: NotchScene?

    init() {
        super.init(showing: drawing)
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
        drawing.showLight(placed, outline: outline, colours: colours)
    }

    func wash(_ rows: Set<String>, at time: Double) {
        drawing.wash(rows, at: time)
    }

    /// The run's latest frame, as it runs in `setting`: the panel's list, the shape and the content through `mirror`,
    /// the edge's as it stands once the frame has swapped edges, the row the keys lit or else the one under the pointer
    /// as the frame saw it, the rows' arrows and the asks panel, and the light, the rows' times as of `now` on the wall clock. The real notch
    /// draws through here, and the welcome's stage.
    func draw(
        _ run: NotchRun, in setting: NotchRun.Setting, mirror: CGAffineTransform, now: Double = Displays.wallNow
    ) {
        show(run.list)
        show(NotchScene(
            frame: run.frame, hover: run.lit(in: setting), scroll: run.scroll,
            time: run.time, now: now, mirror: mirror, calendar: run.calendar, arrows: run.arrows(in: setting),
            asks: run.asksShown, reducesMotion: setting.reducesMotion
        ))
        drawLight(run, at: run.lightTime(run.time), reducesMotion: setting.reducesMotion)
    }

    /// The run's light at this time on its own clock, round the frame's outline, in the colour of what lights it.
    func drawLight(_ run: NotchRun, at time: Double, reducesMotion: Bool) {
        showLight(run.frame.light, outline: run.frame.outline, colours: LiveLight(
            time: time, sinceAsk: run.sinceAsk(at: time), reducesMotion: reducesMotion, need: run.lightNeed
        ))
    }
}
