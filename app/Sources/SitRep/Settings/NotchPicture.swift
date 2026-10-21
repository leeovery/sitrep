import SwiftUI

/// The notch, black, flared from the bezel out to its crest, and its light; reaching, a tongue out of the crest toward
/// the pointer, the light brightening with it.
enum NotchPicture {
    /// Out on the meniscus's attract spring, in about 0.3 s; home on its relax spring, in about 0.6 s, overshooting.
    static let out = Spring(response: 0.20, dampingRatio: 0.75)
    static let home = Spring(response: 0.45, dampingRatio: 0.55)

    /// The crest's straight run at rest, down the notch's outer edge, which the tongue reaches out of.
    static let crestX: CGFloat = 9
    static let crest: ClosedRange<CGFloat> = 37.9 ... 49.1

    /// The least height each flank keeps between the crest's end and the cap, however far the tip is moved.
    static let leastFlank: CGFloat = 2

    /// The filmstrip's tongue part way, its 0.1 s frame, the tip about 3.3 past the crest: half the full reach.
    static let partWay: [CGPoint] = [
        CGPoint(x: 9.8, y: 40.3), CGPoint(x: 11.4, y: 42), CGPoint(x: 12, y: 42.9),
        CGPoint(x: 12.4, y: 43.5), CGPoint(x: 12.4, y: 44.1), CGPoint(x: 12, y: 44.7),
        CGPoint(x: 11.4, y: 45.6), CGPoint(x: 9.8, y: 47.1),
    ]
    /// The filmstrip's tongue at full reach, its 0.3 s frame.
    static let fullReach: [CGPoint] = [
        CGPoint(x: 10.2, y: 40.5), CGPoint(x: 13.9, y: 42.4), CGPoint(x: 15, y: 43.2),
        CGPoint(x: 15.7, y: 43.7), CGPoint(x: 15.7, y: 44.5), CGPoint(x: 15, y: 45),
        CGPoint(x: 13.9, y: 45.8), CGPoint(x: 10.2, y: 47.2),
    ]

    /// The tip's height as the filmstrip draws it at full reach.
    static let drawnTip = (fullReach[2].y + fullReach[5].y) / 2

    /// The tongue's stages by reach: home, flat on the crest; part way; full.
    private static let stages: [(reach: CGFloat, tongue: [CGPoint])] = [
        (0, partWay.map { CGPoint(x: crestX, y: $0.y) }), (0.5, partWay), (1, fullReach),
    ]

    /// The notch's outline at a reach from 0, its crest a straight run, to 1, the tongue at full reach, its tip about
    /// 6.5 units past the crest and toward `tip`.
    static func outline(reach: CGFloat, tip: CGFloat? = nil) -> Path {
        let tongue = tongue(reach: reach, tip: tip)
        var notch = Path()

        notch.move(to: CGPoint(x: -1, y: 18.7))
        notch.addLine(to: CGPoint(x: 3, y: 18.7))
        notch.addCurve(to: CGPoint(x: 6, y: 28.6), control1: CGPoint(x: 3, y: 24.1), control2: CGPoint(x: 4.5, y: 26.4))
        notch.addCurve(to: CGPoint(x: crestX, y: crest.lowerBound), control1: CGPoint(x: 7.5, y: 30.8), control2: CGPoint(x: 9, y: 32.9))
        notch.addCurve(to: tongue[2], control1: tongue[0], control2: tongue[1])
        notch.addCurve(to: tongue[5], control1: tongue[3], control2: tongue[4])
        notch.addCurve(to: CGPoint(x: crestX, y: crest.upperBound), control1: tongue[6], control2: tongue[7])
        notch.addCurve(to: CGPoint(x: 6, y: 58.4), control1: CGPoint(x: 9, y: 54.1), control2: CGPoint(x: 7.5, y: 56.2))
        notch.addCurve(to: CGPoint(x: 3, y: 68.3), control1: CGPoint(x: 4.5, y: 60.6), control2: CGPoint(x: 3, y: 62.9))
        notch.addLine(to: CGPoint(x: -1, y: 68.3))
        notch.closeSubpath()

        return notch
    }

    /// The tongue, the points between the crest's ends: each of its three curves' two controls and its end, down the
    /// upper flank, round the tip's cap and back up the lower flank. At a reach, from stage to stage, and past home or
    /// full as a spring overshoots; its tip at `tip`, the stage's own where nil.
    static func tongue(reach: CGFloat, tip: CGFloat? = nil) -> [CGPoint] {
        let (from, to) = reach < stages[1].reach ? (stages[0], stages[1]) : (stages[1], stages[2])
        let amount = (reach - from.reach) / (to.reach - from.reach)
        let tongue = zip(from.tongue, to.tongue).map { a, b in
            CGPoint(x: a.x + (b.x - a.x) * amount, y: a.y + (b.y - a.y) * amount)
        }

        return tip.map { placed(tongue, tip: $0) } ?? tongue
    }

    /// The tongue with its tip at a height, held inside the crest so each flank keeps `leastFlank`: the cap moved whole,
    /// each flank stretched between the crest's end and the cap, so it stays as concave as drawn.
    private static func placed(_ tongue: [CGPoint], tip: CGFloat) -> [CGPoint] {
        let (capTop, capBottom) = (tongue[2].y, tongue[5].y)
        let drawn = (capTop + capBottom) / 2
        let held = (crest.lowerBound + leastFlank + drawn - capTop) ... (crest.upperBound - leastFlank - (capBottom - drawn))
        let shift = min(max(tip, held.lowerBound), held.upperBound) - drawn
        let upper = (capTop + shift - crest.lowerBound) / (capTop - crest.lowerBound)
        let lower = (crest.upperBound - capBottom - shift) / (crest.upperBound - capBottom)

        return tongue.enumerated().map { index, point in
            switch index {
            case 0 ..< 2: CGPoint(x: point.x, y: crest.lowerBound + (point.y - crest.lowerBound) * upper)
            case 2 ..< 6: CGPoint(x: point.x, y: point.y + shift)
            default: CGPoint(x: point.x, y: crest.upperBound - (crest.upperBound - point.y) * lower)
            }
        }
    }

    /// The notch and its light at a reach: the light's glow and core grow from those at rest to the brighter, wider
    /// ones at full reach.
    static func draw(_ context: GraphicsContext, reach: CGFloat, tip: CGFloat) {
        let outline = outline(reach: reach, tip: tip)
        let glow = mix(CGRect(x: 5.24, y: 35.78, width: 1.52, height: 15.44), CGRect(x: 4.9, y: 35.4, width: 2.2, height: 16.2), reach)
        let bar = mix(CGRect(x: 5.5, y: 36.3, width: 1, height: 14.4), CGRect(x: 5.45, y: 36.3, width: 1.1, height: 14.4), reach)
        let core = Path(roundedRect: bar, cornerRadius: bar.width / 2)
        var lit = context

        context.fill(outline, with: .color(.black))
        lit.clip(to: outline)

        var halo = lit

        halo.addFilter(.blur(radius: 0.8 + 0.45 * reach))
        halo.fill(Path(roundedRect: glow, cornerRadius: glow.width / 2), with: .color(WindowStyle.orange.opacity(0.8 + 0.2 * reach)))
        lit.fill(core, with: .color(WindowStyle.orange))
        lit.fill(core, with: .color(lift.opacity(max(reach, 0))))
    }

    /// The core's brighter orange at full reach.
    private static let lift = Color(hex: 0xF07A52)

    private static func mix(_ from: CGRect, _ to: CGRect, _ amount: CGFloat) -> CGRect {
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * amount }

        return CGRect(
            x: mix(from.minX, to.minX), y: mix(from.minY, to.minY), width: mix(from.width, to.width),
            height: mix(from.height, to.height)
        )
    }
}
