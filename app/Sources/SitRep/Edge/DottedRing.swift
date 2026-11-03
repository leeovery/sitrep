import AppKit
import SitRepPanel
import SwiftUI

/// The mark of a session on its own work, from Paper's board D: a ring of round-capped dashes, centred in an 11-point
/// lane, that never turns. Its sizes on the card and in the window's sidebar, and round a strip mark's letters in its
/// 24-point ring's place, its dashes the card's, nineteen of them going round evenly.
struct DottedRing: Equatable {
    let radius: CGFloat
    let line: CGFloat
    /// Each dash and the gap after it.
    let dash: [CGFloat]

    static let card = DottedRing(radius: 4.5, line: 1.5, dash: [1.6, 2.12])
    static let sidebar = DottedRing(radius: 4.25, line: 1.5, dash: [1.5, 2.0])
    static let strip = DottedRing(radius: (StripFrame.Mark.size - 1.5) / 2, line: 1.5, dash: [1.6, 2.12])
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
        ring.path = CGPath(
            ellipseIn: CGRect(x: side / 2 - radius, y: side / 2 - radius, width: 2 * radius, height: 2 * radius),
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

/// The dotted ring as a view, in its square, stroked in a style.
struct DottedRingView<Ink: ShapeStyle>: View {
    let ring: DottedRing
    let ink: Ink

    var body: some View {
        Circle()
            .stroke(ink, style: StrokeStyle(lineWidth: ring.line, lineCap: .round, dash: ring.dash))
            .frame(width: 2 * ring.radius, height: 2 * ring.radius)
            .frame(width: ring.side, height: ring.side)
    }
}
