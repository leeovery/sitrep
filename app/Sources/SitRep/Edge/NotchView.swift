import AppKit
import SitRepEdge
import SitRepPanel

/// The notch in black: the black shape, the light in the notch, the content over them, and the asks panel over all, as
/// layers in the stage's own coordinates (y down from the screen's top), mirrored on the right edge; under reduced
/// motion, the shape it cross-fades from. A frame changes the shape's path, the light and the content's clip and
/// paint; nothing animates implicitly.
@MainActor
final class NotchView: StageHost {
    /// The shape and the light, through the edge's mirror.
    private let stage = CALayer()
    private let shape = CAShapeLayer()
    private let fading = CAShapeLayer()
    private let light = LightLayer()
    private let content = PanelContent()
    private let asks = AsksPanelLayer()

    init() {
        let root = CALayer()

        super.init(hosting: root)
        fading.fillColor = EdgeStyle.black
        fading.isHidden = true
        shape.fillColor = EdgeStyle.black
        shape.shadowColor = EdgeStyle.black
        stage.addSublayer(fading)
        stage.addSublayer(shape)
        stage.addSublayer(light)
        root.addSublayer(stage)
        root.addSublayer(content.layer)
        root.addSublayer(asks.layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rescaleToWindow()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rescaleToWindow()
    }

    /// What the panel lists from now on.
    func show(_ list: PanelList) {
        content.show(list)
    }

    /// The shape and the content as the frame has them.
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
        asks.show(scene.asks, mirror: scene.mirror, now: scene.now)
    }

    /// Lifted by a drag, the black casts the prototype's shadow: 4 down, blurred 12, at 0.4, at full lift.
    private func lift(_ lift: Double) {
        shape.shadowOpacity = Float(0.4 * lift)
        shape.shadowRadius = EdgeStyle.liftBlur * lift
        shape.shadowOffset = CGSize(width: 0, height: 4 * lift)
        shape.shadowPath = lift > 0 ? shape.path : nil
    }

    /// The light as the frame places it, in these colours, round the notch's outline, through the mirror of the last
    /// scene.
    func showLight(_ placed: Frame.Light, outline: CGPath, colours: LiveLight) {
        light.show(placed, outline: outline, colours: colours)
    }

    /// These rows, by their keys, came new onto the board while the panel is out: each is washed orange from this time
    /// on the display's clock, ms.
    func wash(_ rows: Set<String>, at time: Double) {
        content.wash(rows, at: time)
    }

    /// Where a box on the stage is drawn in the view, through the stage's layer as the last scene flipped it: what the
    /// black and the light are drawn in. For the tests.
    func onView(_ box: CGRect) -> CGRect {
        stage.convert(box, to: layer)
    }

    private func rescaleToWindow() {
        guard let scale = window?.backingScaleFactor else {
            return
        }

        rescale(stage, to: scale)
        content.rescaled(to: scale)
        asks.rescaled(to: scale)
    }
}
