import AppKit
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

/// What the panel lists: its head, and its items laid out, in the order the model has them.
struct PanelList: Equatable {
    var head: Head
    var content: Content

    /// The item at an index, while there is one.
    func item(_ index: Int) -> Item? {
        content.entries.indices.contains(index) ? content.entries[index].item : nil
    }
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
}

/// A new row's orange wash, as the prototype washes it: held at its full, then easing out.
enum Wash {
    /// How long it lasts, ms, and how long of that it is held.
    static let length = 2000.0, held = 300.0

    /// How washed a row is this long after its wash began, ms: from 1 as it comes to 0.
    static func amount(since elapsed: Double) -> Double {
        let out = min(max((elapsed - held) / (length - held), 0), 1)

        return 1 - out * out * (3 - 2 * out)
    }

    /// The washes still under way at this time, of those begun when each says.
    static func live(_ began: [String: Double], at time: Double) -> [String: Double] {
        began.filter { time - $0.value < length }
    }
}

extension Frame.Panel {
    /// The content's clip in its own frame as drawn: the part shown, its two front corners rounded, the front away
    /// from the edge on either side.
    func clipPath(_ mirror: CGAffineTransform) -> CGPath {
        let path = CGMutablePath(), rect = clip

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: topRadius
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY),
            radius: bottomRadius
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        let origin = drawn(mirror).origin
        var toContent = mirror.concatenating(CGAffineTransform(translationX: -origin.x, y: -origin.y))

        return path.copy(using: &toContent) ?? path
    }
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
