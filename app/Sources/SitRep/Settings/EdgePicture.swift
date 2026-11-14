import SitRepPanel
import SwiftUI

/// One picture, drawn in its 124 × 80 units scaled to its size: a dark desktop under a menu bar, the bezel down its
/// left, and what shows there. Drawn small, as the Show row's 67 × 44 draws it, what it shows keeps to what still
/// reads: the strip's rings no finer than half a point, and Nothing's menu bar seen closer, from its right end, until
/// the glyph's housing stands 5 tall.
struct EdgePicture: View {
    let show: EdgeSettings.Show

    static let units = CGSize(width: 124, height: 80)
    /// The finest a ring's line is drawn, in points: a pixel at 2×.
    private static let finest: CGFloat = 0.5
    /// The least the glyph's housing stands, in points, for its line to stay a pixel at 2×.
    private static let leastGlyph: CGFloat = 5

    var body: some View {
        Canvas { context, size in
            let scale = CGSize(width: size.width / Self.units.width, height: size.height / Self.units.height)
            // a unit's points, at the least, as the picture is drawn
            let unit = min(scale.width, scale.height)

            context.scaleBy(x: scale.width, y: scale.height)
            switch show {
            case .notch:
                Self.desktop(context, extras: true)
                NotchPicture.draw(context)
            case .strip:
                Self.desktop(context, extras: true)
                StripPicture.draw(context, line: max(StripPicture.line, Self.finest / unit))
            case .nothing:
                let closer = max(1, Self.leastGlyph / (Self.glyphHeight * unit))

                context.translateBy(x: Self.units.width, y: 0)
                context.scaleBy(x: closer, y: closer)
                context.translateBy(x: -Self.units.width, y: 0)
                Self.desktop(context, extras: false)
                Self.glyph(context)
            }
        }
    }

    private static let ground = Gradient(stops: [
        .init(color: Color(hex: 0x3A3F48), location: 0),
        .init(color: Color(hex: 0x262A31), location: 0.55),
        .init(color: Color(hex: 0x1B1E23), location: 1),
    ])
    private static let ink = Color(hex: 0xF5F5F7)

    /// The ground, the menu bar's band, its clock's dash, and the extras' dash where the glyph does not stand in it;
    /// the bezel down the left.
    private static func desktop(_ context: GraphicsContext, extras: Bool) {
        context.fill(Path(CGRect(origin: .zero, size: units)), with: .linearGradient(
            ground, startPoint: .zero, endPoint: CGPoint(x: units.width * 0.55, y: units.height)
        ))
        context.fill(Path(CGRect(x: 0, y: 0, width: units.width, height: 7)), with: .color(.black.opacity(0.28)))
        if extras {
            context.fill(Path(roundedRect: CGRect(x: 94, y: 2.5, width: 5, height: 2), cornerRadius: 1), with: .color(ink.opacity(0.7)))
        }
        context.fill(Path(roundedRect: CGRect(x: 103, y: 2.5, width: 14, height: 2), cornerRadius: 1), with: .color(ink.opacity(0.45)))
        context.fill(Path(CGRect(x: 0, y: 0, width: 3, height: units.height)), with: .color(.black))
    }

    private static let glyphHeight: CGFloat = 3.9

    /// The menu bar's glyph, lit, as the menu bar draws it (`MenuImages.glyph`), scaled so its housing stands where
    /// the drawing's does: 3.9 units tall from 1.55 down, centred at 97.25.
    private static func glyph(_ context: GraphicsContext) {
        let housing = MenuImages.glyphHousing
        let scale = glyphHeight / housing.height
        let side = MenuImages.glyphSide * scale
        let origin = CGPoint(x: 97.25 - housing.midX * scale, y: 1.55 - housing.minY * scale)

        context.draw(litGlyph, in: CGRect(origin: origin, size: CGSize(width: side, height: side)))
    }

    private static let litGlyph = Image(nsImage: MenuImages.glyph(.lit, ink: NSColor(ink.opacity(0.9))))
}

/// The strip as it stands at Length Grows, a 36-point strip drawn 9 wide: a black column out of the bezel, its ends
/// curving back into the edge in the strip's own S, centred 0.42 of the way down; its rings in the panel's order,
/// Needs you's over the hairline, an ask lit orange with its glow and a turn lit blue with its glow, then two working
/// under it (14 November 2026).
enum StripPicture {
    enum Ring {
        case needs, turn, working
    }

    /// The rings, top to bottom, by their middles' height, spaced as the strip spaces its marks, a quarter of 30
    /// apart, and of 21.5 each side of the hairline; the working rings' arcs standing at 12 o'clock and at 45°, the
    /// others whole.
    static let rings: [(y: CGFloat, ring: Ring, arc: Double?)] = [
        (20.7, .needs, nil), (28.2, .turn, nil), (38.95, .working, 0), (46.45, .working, 45),
    ]

    /// The hairline's middle, under Needs you's rings.
    static let hairline: CGFloat = 28.2 + 21.5 / 4

    private static let centre: CGFloat = 7.5
    private static let radius: CGFloat = 2.75

    /// `S_PTS` from strip.html scaled by 0.25, the bottom end mirrored.
    private static let column = {
        var column = Path()

        column.move(to: CGPoint(x: -1, y: 10.2))
        column.addLine(to: CGPoint(x: 3, y: 10.2))
        column.addCurve(to: CGPoint(x: 6, y: 12.95), control1: CGPoint(x: 3, y: 11.7), control2: CGPoint(x: 4, y: 12.45))
        column.addCurve(to: CGPoint(x: 12, y: 17.2), control1: CGPoint(x: 9.5, y: 13.7), control2: CGPoint(x: 12, y: 14.7))
        column.addLine(to: CGPoint(x: 12, y: 49.95))
        column.addCurve(to: CGPoint(x: 6, y: 54.2), control1: CGPoint(x: 12, y: 52.45), control2: CGPoint(x: 9.5, y: 53.45))
        column.addCurve(to: CGPoint(x: 3, y: 56.95), control1: CGPoint(x: 4, y: 54.7), control2: CGPoint(x: 3, y: 55.45))
        column.addLine(to: CGPoint(x: -1, y: 56.95))
        column.closeSubpath()

        return column
    }()

    /// A ring's line, in units, as drawn; the hairline under Needs you is half as thick.
    static let line: CGFloat = 0.5

    /// The strip, its rings and the hairline under Needs you, a ring's line `line` units thick.
    static func draw(_ context: GraphicsContext, line: CGFloat = line) {
        context.fill(column, with: .color(.black))
        let rule = CGRect(x: 5.5, y: hairline - line / 4, width: 4, height: line / 2)

        context.fill(Path(rule), with: .color(Color(hex: 0x3A3A40)))
        for (y, ring, arc) in rings {
            draw(ring, at: CGPoint(x: centre, y: y), arc: arc, line: line, in: context)
        }
    }

    /// A ring whole in its colour, an ask's and a turn's with its glow; or a working one's track and its quarter arc
    /// from `arc`.
    private static func draw(_ ring: Ring, at middle: CGPoint, arc: Double?, line: CGFloat, in context: GraphicsContext) {
        let circle = Path(ellipseIn: CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2))

        guard let arc else {
            if ring != .working {
                glow(circle, ink(ring), line: line, in: context)
            }
            context.stroke(circle, with: .color(ink(ring)), lineWidth: line)
            return
        }

        var quarter = Path()

        quarter.addRelativeArc(center: middle, radius: radius, startAngle: .degrees(arc - 90), delta: .degrees(90))
        context.stroke(circle, with: .color(PictureStyle.track), lineWidth: line)
        context.stroke(quarter, with: .color(ink(ring)), style: StrokeStyle(lineWidth: line, lineCap: .round))
    }

    /// Needs you's glow: the same circle in its colour at 1.8 times the ring's line, at 0.75, blurred 1.4 times it.
    private static func glow(_ circle: Path, _ colour: Color, line: CGFloat, in context: GraphicsContext) {
        var glow = context

        glow.opacity *= 0.75
        glow.addFilter(.blur(radius: line * 1.4))
        glow.stroke(circle, with: .color(colour), lineWidth: line * 1.8)
    }

    private static func ink(_ ring: Ring) -> Color {
        switch ring {
        case .needs: PictureStyle.orange
        case .turn: PictureStyle.blue
        case .working: PictureStyle.arc
        }
    }
}
