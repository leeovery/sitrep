import AppKit
import SitRepPanel

/// The notch in black: the black shape, the light in the lip, and the content over them, as layers in the stage's own
/// coordinates (y down from the screen's top); under reduced motion, the shape it cross-fades from. A frame changes
/// the shape's path, the light and the content's clip and paint; nothing animates implicitly.
@MainActor
final class PanelView: NSView, NotchDrawing {
    private let shape = CAShapeLayer()
    private let fading = CAShapeLayer()
    private let light = LightLayer()
    private let content: PanelContent

    init(items: [Item], content layout: Content) {
        content = PanelContent(items: items, content: layout)
        super.init(frame: .zero)

        let root = CALayer()

        root.isGeometryFlipped = true
        fading.fillColor = PanelStyle.black
        fading.isHidden = true
        shape.fillColor = PanelStyle.black
        root.addSublayer(fading)
        root.addSublayer(shape)
        root.addSublayer(light)
        root.addSublayer(content.layer)
        layer = root
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rescale(layer)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rescale(layer)
    }

    /// The shape and the content as the frame has them, the row under the pointer lit.
    func show(_ frame: Frame, hover: Int?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.path = frame.outline
        shape.opacity = Float(frame.outlineAlpha)
        fading.isHidden = frame.fading == nil
        fading.path = frame.fading?.outline
        fading.opacity = Float(frame.fading?.alpha ?? 0)
        content.show(frame.panel, hover: hover)
        CATransaction.commit()
    }

    func showLight(_ placed: Frame.Light, outline: CGPath, colours: LiveLight) {
        light.show(placed, outline: outline, colours: colours)
    }

    /// Every layer drawn at the screen's pixel density, so the text and the light stay crisp on Retina.
    private func rescale(_ layer: CALayer?) {
        guard let layer, let scale = window?.backingScaleFactor else {
            return
        }

        layer.contentsScale = scale
        layer.mask.map(rescale)
        layer.sublayers?.forEach(rescale)
        if layer is TextLine || layer === light {
            layer.setNeedsDisplay()
        }
    }
}
