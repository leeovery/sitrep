import AppKit
import SitRepEdge
import SitRepPanel

/// The notch in black: the black shape, the light in the notch, and the content over them, as layers in the stage's
/// own coordinates (y down from the screen's top), mirrored on the right edge; under reduced motion, the shape it
/// cross-fades from. A frame changes the shape's path, the light and the content's clip and paint; nothing animates
/// implicitly.
@MainActor
final class NotchView: NSView, NotchDrawing {
    /// The shape and the light, through the edge's mirror.
    private let stage = CALayer()
    private let shape = CAShapeLayer()
    private let fading = CAShapeLayer()
    private let light = LightLayer()
    private let content = PanelContent()

    init() {
        super.init(frame: .zero)

        let root = CALayer()

        root.isGeometryFlipped = true
        fading.fillColor = EdgeStyle.black
        fading.isHidden = true
        shape.fillColor = EdgeStyle.black
        shape.shadowColor = EdgeStyle.black
        stage.addSublayer(fading)
        stage.addSublayer(shape)
        stage.addSublayer(light)
        root.addSublayer(stage)
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
        rescaleToWindow()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rescaleToWindow()
    }

    func show(_ list: PanelList) {
        content.show(list)
    }

    func show(_ scene: NotchScene) {
        let frame = scene.frame

        still {
            // a layer turns about its centre, so the window's mirror is its flip alone
            stage.bounds = bounds
            stage.position = CGPoint(x: bounds.midX, y: bounds.midY)
            stage.setAffineTransform(CGAffineTransform(scaleX: scene.mirror.a, y: 1))
            shape.path = frame.outline
            shape.opacity = Float(frame.outlineAlpha)
            lift(frame.lift)
            fading.isHidden = frame.fading == nil
            fading.path = frame.fading?.outline
            fading.opacity = Float(frame.fading?.alpha ?? 0)
            content.show(scene)
        }
    }

    /// Lifted by a drag, the black casts the prototype's shadow: 4 down, blurred 12, at 0.4, at full lift.
    private func lift(_ lift: Double) {
        shape.shadowOpacity = Float(0.4 * lift)
        shape.shadowRadius = EdgeStyle.liftBlur * lift
        shape.shadowOffset = CGSize(width: 0, height: 4 * lift)
        shape.shadowPath = lift > 0 ? shape.path : nil
    }

    func showLight(_ placed: Frame.Light, outline: CGPath, colours: LiveLight) {
        light.show(placed, outline: outline, colours: colours)
    }

    func wash(_ rows: Set<String>, at time: Double) {
        content.wash(rows, at: time)
    }

    private func rescaleToWindow() {
        guard let scale = window?.backingScaleFactor else {
            return
        }

        rescale(stage, to: scale)
        content.rescaled(to: scale)
    }
}
