import AppKit
import SitRepPanel

/// The panel's one view: the black shape, the light in the lip, and the content over them, as layers in the
/// stage's own coordinates (y down from the screen's top). A frame changes the shape's path, the light and the
/// content's clip and paint; nothing animates implicitly. Clicks on it, and Esc while it has the keys, go to the
/// controller.
@MainActor
final class PanelView: NSView {
    /// A click, in screen coordinates.
    var onClick: (CGPoint) -> Void = { _ in }
    var onEscape: () -> Void = {}

    private let shape = CAShapeLayer()
    private let light = LightLayer()
    private let content: PanelContent

    private static let escape: UInt16 = 53

    init(items: [Item], content layout: Content) {
        content = PanelContent(items: items, content: layout)
        super.init(frame: .zero)

        let root = CALayer()

        root.isGeometryFlipped = true
        shape.fillColor = PanelStyle.black
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

    override var acceptsFirstResponder: Bool { true }

    /// The first click on the panel acts, though it is not yet the key window.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        // the click makes the panel key, and this view takes the keys in it, for Esc
        window.makeFirstResponder(self)
        onClick(window.convertPoint(toScreen: event.locationInWindow))
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == Self.escape {
            onEscape()
        } else {
            super.keyDown(with: event)
        }
    }

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
        content.show(frame.panel, hover: hover)
        CATransaction.commit()
    }

    /// The light as the frame places it, in these colours.
    func showLight(_ placed: Frame.Light, outline: CGPath, colours: LiveLight) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        light.isHidden = placed.level <= 0.001
        if !light.isHidden {
            var toLight = CGAffineTransform(translationX: -placed.centre.x, y: -placed.centre.y)

            light.position = placed.centre
            light.look = LightLayer.Look(
                colours: colours, level: placed.level, outline: outline.copy(using: &toLight) ?? outline
            )
            light.setNeedsDisplay()
        }
        CATransaction.commit()
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
