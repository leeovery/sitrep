import AppKit
import SitRepPanel
import SwiftUI

/// The mark of a session on its own work, from Paper's board D: a ring of round-capped dashes, centred in an 11-point
/// lane, that never turns. Its sizes on the card and in the window's sidebar, and round a strip mark's letters in its
/// 24-point ring's place, where it reads as the card's grown: about as many dashes, eight going round evenly, their
/// gaps as short beside them. The card's own dashes there would be nineteen dots, read as a dotted ring, not dashed.
struct DottedRing: Equatable {
    let radius: CGFloat
    let line: CGFloat
    /// Each dash and the gap after it.
    let dash: [CGFloat]

    static let card = DottedRing(radius: 4.5, line: 1.5, dash: [1.6, 2.12])
    static let sidebar = DottedRing(radius: 4.25, line: 1.5, dash: [1.5, 2.0])
    static let strip = evenly(radius: (StripFrame.Mark.size - 1.5) / 2, line: 1.5, dashes: 8, gap: 1.6)
    static let lane: CGFloat = 11

    /// A ring of so many dashes going round evenly, each gap showing this much between their round caps.
    static func evenly(radius: CGFloat, line: CGFloat, dashes: Int, gap: CGFloat) -> DottedRing {
        let period = 2 * .pi * radius / CGFloat(dashes)

        return DottedRing(radius: radius, line: line, dash: [period - gap - line, gap + line])
    }

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

    /// Its dashes, each a path of its own, laid along the circle by Core Graphics as the layer's are, to stroke
    /// undashed: SwiftUI's own dashing, drawn in a hosting view, measures a circle a little short, so the gap at its
    /// end closes up, eight dashes reading as seven (measured on macOS 26).
    var dashes: CGPath {
        circle.copy(dashingWithPhase: 0, lengths: dash)
    }

    /// The circle in its square.
    private var circle: CGPath {
        CGPath(
            ellipseIn: CGRect(x: side / 2 - radius, y: side / 2 - radius, width: 2 * radius, height: 2 * radius),
            transform: nil
        )
    }
}

/// The dotted ring as a view, in its square, stroked in a style.
struct DottedRingView<Ink: ShapeStyle>: View {
    let ring: DottedRing
    let ink: Ink

    var body: some View {
        Outline(path: Path(ring.dashes))
            .stroke(ink, style: StrokeStyle(lineWidth: ring.line, lineCap: .round))
            .frame(width: ring.side, height: ring.side)
    }
}
