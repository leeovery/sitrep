import AppKit
import SitRepPanel

/// The Live light in the notch, drawn as the prototype's `drawLive` draws it: the halo, a shadow of the bar alone
/// held inside the notch's outline; the body's gradient, its spots and deeper tips; and the faint lighter line down
/// its middle; all at the breath's opacity, times the light's level. It sits on the light's centre, and redraws
/// only when told.
final class LightLayer: CALayer {
    /// What one drawing shows: the light's colours at a moment, how lit it is, and the notch's outline around it, in
    /// the layer's own coordinates.
    struct Look {
        var colours: LiveLight
        var level: Double
        var outline: CGPath
    }

    var look: Look?

    /// Room round the bar for its halo, which fades out within 3σ.
    private static let box = LiveLight.bar.insetBy(dx: -6, dy: -6)

    override init() {
        super.init()

        isHidden = true
        needsDisplayOnBoundsChange = true
        bounds = Self.box
        anchorPoint = CGPoint(x: -Self.box.minX / Self.box.width, y: -Self.box.minY / Self.box.height)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// The light as the frame places it, in these colours, round the notch's outline: hidden while it is out.
    func show(_ placed: Frame.Light, outline: CGPath, colours: LiveLight) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        isHidden = placed.level <= 0.001
        if !isHidden {
            var toLight = CGAffineTransform(translationX: -placed.centre.x, y: -placed.centre.y)

            position = placed.centre
            look = Look(colours: colours, level: placed.level, outline: outline.copy(using: &toLight) ?? outline)
            setNeedsDisplay()
        }
        CATransaction.commit()
    }

    override func draw(in context: CGContext) {
        guard let look, look.level > 0.001 else {
            return
        }

        let colours = look.colours, box = LiveLight.bar, bar = Self.capsule(box)
        let line = [0, colours.line, 0].map { EdgeStyle.color(LiveLight.hot, alpha: $0) }

        context.setAlpha(look.level * colours.opacity)
        halo(context, bar, inside: look.outline)
        // the body down the bar, then the lighter line across it
        fill(context, bar, colours.body.map { EdgeStyle.color($0) }, from: CGPoint(x: 0, y: box.minY), to: CGPoint(x: 0, y: box.maxY))
        fill(context, bar, line, from: CGPoint(x: box.minX, y: 0), to: CGPoint(x: box.maxX, y: 0))
    }

    /// The bar's shadow alone: clipped to the notch and to everything outside the bar, so the bar casting it never
    /// shows. The blur is twice σ, as canvas's is; in a layer's context it is in points, as the layer's scale is in
    /// the context's base space (seen rendering the layer at 12x, where the halo stayed 1.5 points).
    private func halo(_ context: CGContext, _ bar: CGPath, inside outline: CGPath) {
        context.saveGState()
        context.addPath(outline)
        context.clip()
        context.addRect(Self.box)
        context.addPath(bar)
        context.clip(using: .evenOdd)
        context.setShadow(
            offset: .zero, blur: 2 * LiveLight.haloSigma,
            color: EdgeStyle.color(LiveLight.orange, alpha: LiveLight.haloAlpha)
        )
        context.addPath(bar)
        context.setFillColor(EdgeStyle.black)
        context.fillPath()
        context.restoreGState()
    }

    private func fill(_ context: CGContext, _ bar: CGPath, _ colours: [CGColor], from start: CGPoint, to end: CGPoint) {
        let stops = colours.indices.map { CGFloat($0) / CGFloat(colours.count - 1) }

        guard let gradient = CGGradient(colorsSpace: EdgeStyle.sRGB, colors: colours as CFArray, locations: stops) else {
            return
        }

        context.saveGState()
        context.addPath(bar)
        context.clip()
        context.drawLinearGradient(gradient, start: start, end: end, options: [])
        context.restoreGState()
    }

    private static func capsule(_ rect: CGRect) -> CGPath {
        let radius = min(rect.width, rect.height) / 2

        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }
}
