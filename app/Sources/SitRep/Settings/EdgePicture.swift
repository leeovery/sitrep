import SitRepPanel
import SwiftUI

/// One picture, drawn in its 124 × 80 units scaled to its size: a dark desktop under a menu bar, the bezel down its
/// left, and what shows there. Drawn small, as the Show row's 67 × 44 draws it, what it shows keeps to what still
/// reads: Nothing's menu bar seen closer, from its right end, until the glyph's housing stands 5 tall.
struct EdgePicture: View {
    let show: EdgeSettings.Show

    static let units = CGSize(width: 124, height: 80)
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
