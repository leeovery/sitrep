import AppKit

/// A working title, as the prototype's shimmer: grey, with a light sweeping along it every 2.5s. The light is the
/// title again in ink, shown through a band of a gradient three times its width, so it rises from the grey and falls
/// back into it as the prototype's background gradient does; only the gradient moves.
@MainActor
struct Shimmer {
    let layer = CALayer()
    /// The sweep, to run on `band` only while the title shows.
    let band = CAGradientLayer()
    let sweep: CAAnimation

    init(grey: NSAttributedString, lit: NSAttributedString, in box: CGRect) {
        let local = CGRect(origin: .zero, size: box.size)
        let below = TextLine(grey, in: local), above = TextLine(lit, in: local)
        let width = box.width

        layer.frame = box
        band.colors = [CGColor.clear, CGColor.clear, PanelStyle.black, CGColor.clear, CGColor.clear]
        band.locations = [0, 0.36, 0.5, 0.64, 1]
        band.startPoint = CGPoint(x: 0, y: 0.5)
        band.endPoint = CGPoint(x: 1, y: 0.5)
        band.frame = CGRect(x: -2 * width, y: 0, width: 3 * width, height: above.bounds.height)
        above.mask = band
        layer.addSublayer(below)
        layer.addSublayer(above)

        let across = CABasicAnimation(keyPath: "position.x")
        across.fromValue = -0.5 * width
        across.toValue = 1.5 * width
        across.duration = 2.5
        across.repeatCount = .infinity
        sweep = across
    }
}
