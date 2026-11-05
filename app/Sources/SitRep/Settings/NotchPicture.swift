import SwiftUI

/// The notch at rest, black, flared from the bezel out to its crest, and its light.
enum NotchPicture {
    /// The notch's outline: out of the bezel, flaring to its crest, a straight run down x 9, and back.
    private static let outline = {
        var notch = Path()

        notch.move(to: CGPoint(x: -1, y: 18.7))
        notch.addLine(to: CGPoint(x: 3, y: 18.7))
        notch.addCurve(to: CGPoint(x: 6, y: 28.6), control1: CGPoint(x: 3, y: 24.1), control2: CGPoint(x: 4.5, y: 26.4))
        notch.addCurve(to: CGPoint(x: 9, y: 37.9), control1: CGPoint(x: 7.5, y: 30.8), control2: CGPoint(x: 9, y: 32.9))
        notch.addLine(to: CGPoint(x: 9, y: 49.1))
        notch.addCurve(to: CGPoint(x: 6, y: 58.4), control1: CGPoint(x: 9, y: 54.1), control2: CGPoint(x: 7.5, y: 56.2))
        notch.addCurve(to: CGPoint(x: 3, y: 68.3), control1: CGPoint(x: 4.5, y: 60.6), control2: CGPoint(x: 3, y: 62.9))
        notch.addLine(to: CGPoint(x: -1, y: 68.3))
        notch.closeSubpath()

        return notch
    }()

    /// The notch and its light, clipped to it: the glow, `#E9643DCC` blurred 0.8, and the orange core over it.
    static func draw(_ context: GraphicsContext) {
        let glow = CGRect(x: 5.24, y: 35.78, width: 1.52, height: 15.44)
        let core = CGRect(x: 5.5, y: 36.3, width: 1, height: 14.4)
        var lit = context

        context.fill(outline, with: .color(.black))
        lit.clip(to: outline)

        var halo = lit

        halo.addFilter(.blur(radius: 0.8))
        halo.fill(Path(roundedRect: glow, cornerRadius: glow.width / 2), with: .color(PictureStyle.orange.opacity(0.8)))
        lit.fill(Path(roundedRect: core, cornerRadius: core.width / 2), with: .color(PictureStyle.orange))
    }
}
