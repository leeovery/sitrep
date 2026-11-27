import AppKit
import SitRepPanel

/// The mark of a session on its own work, from Paper's board D: a ring of round-capped dashes, centred in an 11-point
/// lane, that never turns. Its sizes on the card.
struct DottedRing: Equatable {
    let radius: CGFloat
    let line: CGFloat
    /// Each dash and the gap after it.
    let dash: [CGFloat]

    static let card = DottedRing(radius: 4.5, line: 1.5, dash: [1.6, 2.12])
    static let lane: CGFloat = 11

    /// The square it is centred in: the lane, or a ring too big for it, as wide as the ring.
    var side: CGFloat {
        max(Self.lane, 2 * radius + line)
    }

    /// As a layer in its square, centred on a point, stroked in a colour, with no animation of its own.
    @MainActor
    func layer(centredOn centre: CGPoint, colour: CGColor) -> CAShapeLayer {
        let ring = CAShapeLayer()

        ring.frame = CGRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side)
        ring.path = circle
        ring.fillColor = nil
        ring.strokeColor = colour
        ring.lineWidth = line
        ring.lineCap = .round
        ring.lineDashPattern = dash.map { NSNumber(value: Double($0)) }

        return ring
    }

    /// The circle in its square.
    private var circle: CGPath {
        CGPath(
            ellipseIn: CGRect(x: side / 2 - radius, y: side / 2 - radius, width: 2 * radius, height: 2 * radius),
            transform: nil
        )
    }
}
