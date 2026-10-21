import SitRepPanel
import SwiftUI

/// What stays on screen, as three pictures of the screen's edge, drawn from Paper's "Settings in the window": the
/// notch and its light, the strip and its rings, or only the menu bar's glyph, lit. The one chosen is ringed in the
/// accent; a click on another chooses it. It is the menu's Show. The three share the page's column, 16 apart, each
/// keeping the drawing's shape. Nothing in them moves, under the pointer or not.
struct ShowPictures: View {
    @Binding var show: EdgeSettings.Show
    /// Whether the window is on screen; off it, no tile is under the pointer.
    let isOnScreen: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(EdgeSettings.Show.allCases, id: \.self) { choice in
                ShowTile(choice: choice, isChosen: choice == show, isOnScreen: isOnScreen) { show = choice }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

/// A tile not chosen under the pointer: its hairline, `#FFFFFF26`, lifted to `#FFFFFF4D`, at once.
enum PictureHover {
    static func hairline(isOver: Bool) -> Double {
        Double(isOver ? 0x4D : 0x26) / 255
    }
}

/// A picture and its label, as one button, as wide as its share of the column, the picture keeping its shape. Chosen,
/// a gap of the page's black and a ring in the accent round it; else a hairline inside it, lifted at once while the
/// pointer is over the tile.
private struct ShowTile: View {
    let choice: EdgeSettings.Show
    let isChosen: Bool
    let isOnScreen: Bool
    let choose: () -> Void

    @State private var isOver = false

    private static let shape = CGSize(width: 225, height: 145)
    private static let radius: CGFloat = 12
    /// The ring's middle, past the picture's edge: a gap of 2, then a ring 2.5 wide.
    private static let ring: CGFloat = 2 + 2.5 / 2

    var body: some View {
        let picture = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)

        Button(action: choose) {
            VStack(spacing: 10) {
                EdgePicture(show: choice)
                    .aspectRatio(Self.shape, contentMode: .fit)
                    .clipShape(picture)
                    .overlay {
                        if isChosen {
                            RoundedRectangle(cornerRadius: Self.radius + Self.ring, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 2.5)
                                .padding(-Self.ring)
                        } else {
                            picture.strokeBorder(.white.opacity(PictureHover.hairline(isOver: isOver)), lineWidth: 0.5)
                        }
                    }
                Text(choice.title)
                    .font(.system(size: 13, weight: isChosen ? .semibold : .medium))
                    .foregroundStyle(isChosen ? WindowStyle.text : WindowStyle.soft)
                    .frame(height: 18)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isOver = $0 }
        .onChange(of: isOnScreen) {
            // the pointer's leaving may never be heard as the window leaves the screen
            if !isOnScreen {
                isOver = false
            }
        }
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// One picture, drawn in its 124 × 80 units scaled to its size: a dark desktop under a menu bar, the bezel down its
/// left, and what shows there.
struct EdgePicture: View {
    let show: EdgeSettings.Show

    static let units = CGSize(width: 124, height: 80)

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / Self.units.width, y: size.height / Self.units.height)
            Self.desktop(context, extras: show != .nothing)
            switch show {
            case .notch: NotchPicture.draw(context)
            case .strip: StripPicture.draw(context)
            case .nothing: Self.glyph(context)
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

    /// The menu bar's glyph, lit, as the menu bar draws it (`MenuImages.glyph`), scaled so its housing stands where
    /// the drawing's does: 3.9 units tall from 1.55 down, centred at 97.25.
    private static func glyph(_ context: GraphicsContext) {
        let housing = MenuImages.glyphHousing
        let scale = 3.9 / housing.height
        let side = MenuImages.glyphSide * scale
        let origin = CGPoint(x: 97.25 - housing.midX * scale, y: 1.55 - housing.minY * scale)

        context.draw(litGlyph, in: CGRect(origin: origin, size: CGSize(width: side, height: side)))
    }

    private static let litGlyph = Image(nsImage: MenuImages.glyph(.lit, ink: NSColor(ink.opacity(0.9))))
}

/// The strip as it stands at Length Grows, a 36-point strip drawn 9 wide: a black column out of the bezel, its ends
/// curving back into the edge in the strip's own S, centred 0.42 of the way down; its rings in the panel's order,
/// needs you lit orange with its glow, the hairline under it, your turn in white, then two working.
enum StripPicture {
    enum Ring {
        case needs, turn, working
    }

    /// The rings, top to bottom, by their middles' height.
    private static let rings: [(y: CGFloat, ring: Ring)] = [(20.7, .needs), (31.45, .turn), (38.95, .working), (46.45, .working)]
    /// The working rings' arcs stand at 12 o'clock and at 45°; the others are whole.
    private static let restingArcs: [Double?] = [nil, nil, 0, 45]

    private static let centre: CGFloat = 7.5
    private static let radius: CGFloat = 2.75

    /// `S_PTS` from strip.html scaled by 0.25, the bottom end mirrored.
    static let column = {
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

    /// The strip, its rings and the hairline under needs you.
    static func draw(_ context: GraphicsContext) {
        context.fill(column, with: .color(.black))
        context.fill(Path(CGRect(x: 5.5, y: 25.95, width: 4, height: 0.25)), with: .color(Color(hex: 0x3A3A40)))
        for ((y, ring), resting) in zip(rings, restingArcs) {
            draw(ring, at: CGPoint(x: centre, y: y), arc: resting, in: context)
        }
    }

    /// A ring whole in its colour, needs you's with its glow; or a working one's track and its quarter arc from `arc`.
    private static func draw(_ ring: Ring, at middle: CGPoint, arc: Double?, in context: GraphicsContext) {
        let circle = Path(ellipseIn: CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2))

        guard let arc else {
            if ring == .needs {
                glow(circle, in: context)
            }
            context.stroke(circle, with: .color(ink(ring)), lineWidth: 0.5)
            return
        }

        var quarter = Path()

        quarter.addRelativeArc(center: middle, radius: radius, startAngle: .degrees(arc - 90), delta: .degrees(90))
        context.stroke(circle, with: .color(WindowStyle.track), lineWidth: 0.5)
        context.stroke(quarter, with: .color(ink(ring)), style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
    }

    /// Needs you's glow: the same circle at 0.9, at 0.75, blurred 0.7.
    private static func glow(_ circle: Path, in context: GraphicsContext) {
        var glow = context

        glow.opacity *= 0.75
        glow.addFilter(.blur(radius: 0.7))
        glow.stroke(circle, with: .color(WindowStyle.orange), lineWidth: 0.9)
    }

    private static func ink(_ ring: Ring) -> Color {
        switch ring {
        case .needs: WindowStyle.orange
        case .turn: Color(hex: 0xF5F5F7)
        case .working: WindowStyle.arc
        }
    }
}
