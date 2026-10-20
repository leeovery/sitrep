import AppKit

/// A working title, as the prototype's shimmer: grey, with a light sweeping along it every 2.5s. The light is the
/// title again in ink, or as much of it as shimmers, shown through a band of a gradient three times its width, so it
/// rises from the grey and falls back into it as the prototype's background gradient does; only the gradient moves.
@MainActor
struct Shimmer {
    let layer = CALayer()
    /// The sweep, to add to `band` once: it runs in the render server.
    let band: CAGradientLayer
    let sweep: CAAnimation
    /// How wide the grey title is drawn.
    let width: CGFloat

    init(grey: NSAttributedString, lit: NSAttributedString, in box: CGRect) {
        let local = CGRect(origin: .zero, size: box.size)
        let below = TextLine(grey, in: local), above = TextLine(lit, in: local)
        let light = ShimmerBand(width: box.width, height: above.bounds.height)

        width = below.width
        layer.frame = box
        band = light.layer
        sweep = light.sweep
        above.mask = band
        layer.addSublayer(below)
        layer.addSublayer(above)
    }
}

/// The shimmer's light: a band of a gradient three times the title's width, opaque only at its middle, which Core
/// Animation carries along the title every 2.5s in the render server. Shown through, it lights the title.
@MainActor
struct ShimmerBand {
    let layer = CAGradientLayer()
    let sweep: CAAnimation

    init(width: Double, height: Double) {
        layer.colors = [CGColor.clear, CGColor.clear, EdgeStyle.black, CGColor.clear, CGColor.clear]
        layer.locations = [0, 0.36, 0.5, 0.64, 1]
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.frame = CGRect(x: -2 * width, y: 0, width: 3 * width, height: height)

        let across = CABasicAnimation(keyPath: "position.x")
        across.fromValue = -0.5 * width
        across.toValue = 1.5 * width
        across.duration = 2.5
        across.repeatCount = .infinity
        sweep = across
    }
}
