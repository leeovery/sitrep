import AppKit

/// An arc turning round its track, as a working mark's: the ring's quarter from `start`, turned by Core Animation in
/// the render server, once a period. Added once and left, the turn costs the app nothing, and nothing set on the
/// layers round it restarts it.
@MainActor
final class Arc {
    let layer = CALayer()
    let track = CAShapeLayer()
    let arc = CAShapeLayer()
    private let line: Double
    private let start: Double
    private var period: Double?

    init(line: Double = 1.5, from start: Double = -.pi / 2) {
        self.line = line
        self.start = start
        for shape in [track, arc] {
            shape.fillColor = nil
            shape.lineWidth = line
            shape.lineCap = .round
            layer.addSublayer(shape)
        }
    }

    /// Its place and size, the ring as wide as the box, in the caller's transaction.
    func fit(_ box: CGRect) {
        let bounds = CGRect(origin: .zero, size: box.size), r = (min(box.width, box.height) - line) / 2
        let centre = CGPoint(x: bounds.midX, y: bounds.midY), quarter = CGMutablePath()
        quarter.addArc(center: centre, radius: r, startAngle: start, endAngle: start + .pi / 2, clockwise: false)
        layer.frame = box
        track.frame = bounds
        arc.frame = bounds
        track.path = CGPath(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r), transform: nil)
        arc.path = quarter
    }

    /// Turning once in this many seconds, from a phase of its own: added only when it isn't already turning so.
    func turn(every seconds: Double) {
        guard seconds != period || layer.animation(forKey: Self.key) == nil else {
            return
        }

        period = seconds
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = 0
        turn.toValue = 2 * Double.pi
        turn.duration = seconds
        turn.repeatCount = .infinity
        turn.timeOffset = Double.random(in: 0 ..< seconds)
        layer.add(turn, forKey: Self.key)
    }

    private static let key = "spin"
}

/// Layer changes made at once, with no animation of their own.
@MainActor
func still(_ change: () -> Void) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    change()
    CATransaction.commit()
}
