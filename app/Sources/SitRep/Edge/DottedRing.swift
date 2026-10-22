import AppKit
import SwiftUI

/// The mark of a session on its own work, from Paper's board D: a ring of round-capped dashes, centred in an 11-point
/// lane, that never turns. Its sizes on the card and in the window's sidebar.
struct DottedRing: Equatable {
    let radius: CGFloat
    let line: CGFloat
    /// Each dash and the gap after it.
    let dash: [CGFloat]

    static let card = DottedRing(radius: 4.5, line: 1.5, dash: [1.6, 2.12])
    static let sidebar = DottedRing(radius: 4.25, line: 1.5, dash: [1.5, 2.0])
    static let lane: CGFloat = 11

    /// As a layer in its lane, centred on a point, stroked in a colour, with no animation of its own.
    @MainActor
    func layer(centredOn centre: CGPoint, colour: CGColor) -> CAShapeLayer {
        let ring = CAShapeLayer()
        let lane = Self.lane

        ring.frame = CGRect(x: centre.x - lane / 2, y: centre.y - lane / 2, width: lane, height: lane)
        ring.path = CGPath(
            ellipseIn: CGRect(x: lane / 2 - radius, y: lane / 2 - radius, width: 2 * radius, height: 2 * radius),
            transform: nil
        )
        ring.fillColor = nil
        ring.strokeColor = colour
        ring.lineWidth = line
        ring.lineCap = .round
        ring.lineDashPattern = dash.map { NSNumber(value: Double($0)) }

        return ring
    }
}

/// The dotted ring as a view, in its lane, stroked in a style.
struct DottedRingView<Ink: ShapeStyle>: View {
    let ring: DottedRing
    let ink: Ink

    var body: some View {
        Circle()
            .stroke(ink, style: StrokeStyle(lineWidth: ring.line, lineCap: .round, dash: ring.dash))
            .frame(width: 2 * ring.radius, height: 2 * ring.radius)
            .frame(width: DottedRing.lane, height: DottedRing.lane)
    }
}
