import AppKit
import SitRepEdge
import SitRepPanel

/// One way of drawing the notch, in black or in glass: the list the panel holds, as it changes, and a frame at a time.
@MainActor
protocol NotchDrawing: NSView {
    /// What the panel lists from now on.
    func show(_ list: PanelList)
    /// The shape and the content as the frame has them.
    func show(_ scene: NotchScene)
    /// The light as the frame places it, in these colours, round the notch's outline, through the mirror of the last
    /// scene.
    func showLight(_ placed: Frame.Light, outline: CGPath, colours: LiveLight)
    /// These rows, by their keys, came new onto the board while the panel is out: each is washed orange from this
    /// time on the display's clock, ms.
    func wash(_ rows: Set<String>, at time: Double)
}

/// One frame as a drawing draws it.
struct NotchScene {
    let frame: Frame
    /// The row under the pointer, by its index among the items.
    let hover: Int?
    /// How far down the content is scrolled.
    let scroll: Double
    /// The display's clock, ms, which the washes run on.
    let time: Double
    /// The wall clock, ms, which the rows' times count on.
    let now: Double
    /// The stage into the window: mirrored on the right edge.
    let mirror: CGAffineTransform
    /// The calendar the rows' wake times are worded on, the run's.
    var calendar = WakeTime.calendar
    /// The rows' arrows that show, by their rows' keys, each lit or not (`NotchRun.arrows`).
    var arrows: [String: Bool] = [:]
    /// The asks panel, while it is open.
    var asks: AsksShown?
}

extension Frame.Panel {
    /// The content's clip in its own frame as drawn: the part shown, its two front corners rounded, the front away
    /// from the edge on either side.
    func clipPath(_ mirror: CGAffineTransform) -> CGPath {
        frontRounded(clip, top: topRadius, bottom: bottomRadius, through: mirror, from: drawn(mirror).origin)
    }
}

/// A part of the stage shown, its two front corners rounded, as a clip in the frame of what it is drawn in: through
/// the edge's mirror, so the front is away from the edge on either side, from that frame's origin.
func frontRounded(
    _ rect: CGRect, top: Double, bottom: Double, through mirror: CGAffineTransform, from origin: CGPoint
) -> CGPath {
    let path = CGMutablePath()

    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addArc(
        tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
        radius: top
    )
    path.addArc(
        tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY),
        radius: bottom
    )
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()

    var toFrame = mirror.concatenating(CGAffineTransform(translationX: -origin.x, y: -origin.y))

    return path.copy(using: &toFrame) ?? path
}

/// A layer and all under it drawn at the screen's pixel density, so the text and the light stay crisp on Retina:
/// what draws itself is drawn again.
@MainActor
func rescale(_ layer: CALayer, to scale: CGFloat) {
    layer.contentsScale = scale
    layer.mask.map { rescale($0, to: scale) }
    layer.sublayers?.forEach { rescale($0, to: scale) }
    if layer is TextLine || layer is LightLayer {
        layer.setNeedsDisplay()
    }
}
