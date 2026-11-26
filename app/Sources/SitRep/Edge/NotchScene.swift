import AppKit
import SitRepEdge
import SitRepPanel

/// One frame as the notch draws it.
struct NotchScene {
    let frame: Frame
    /// The row lit, the keys' or the one under the pointer, by its index among the items.
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
    /// Whether the Mac reduces motion, when the arrows turn at once.
    var reducesMotion = false

    /// The arrow of the row `key`, where it shows: lit or not, pointing toward where the asks panel opens, away from
    /// the screen's edge, and turned while the asks panel is open beside its row.
    func arrow(_ key: String) -> SessionRow.Arrow? {
        arrows[key].map { isLit in
            SessionRow.Arrow(
                isLit: isLit, pointsLeft: mirror.a < 0, isTurned: asks?.row == key, turnsAtOnce: reducesMotion
            )
        }
    }
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
