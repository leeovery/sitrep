import SitRepPanel
import SwiftUI

/// Show, as three pictures of the screen's edge, drawn from Paper's "Settings": the notch and its light, the strip and
/// its rings, or only the menu bar's glyph. The chosen one is ringed in the accent and live, its light breathing; a
/// click on another chooses it. It is the menu's Show.
struct ShowPictures: View {
    @Binding var show: EdgeSettings.Show

    var body: some View {
        HStack(spacing: 14) {
            ForEach(EdgeSettings.Show.allCases, id: \.self) { choice in
                Button { show = choice } label: { picture(choice) }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(choice == show ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func picture(_ choice: EdgeSettings.Show) -> some View {
        let isChosen = choice == show

        return VStack(spacing: 8) {
            EdgePicture(show: choice, isLive: isChosen)
                .frame(width: 124, height: 80)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                }
                .padding(2)
                .overlay {
                    if isChosen {
                        RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 2.5)
                    }
                }
            Text(choice.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isChosen ? .primary : .secondary)
        }
    }
}

/// One picture: a dark desktop under a menu bar, the bezel down its left, and what shows there.
private struct EdgePicture: View {
    let show: EdgeSettings.Show
    let isLive: Bool
    @State private var isBright = true
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    private static let orange = Color(red: 0xE9 / 255, green: 0x64 / 255, blue: 0x3D / 255)
    private static let desktop = Gradient(stops: [
        .init(color: Color(red: 0x3A / 255, green: 0x3F / 255, blue: 0x48 / 255), location: 0),
        .init(color: Color(red: 0x26 / 255, green: 0x2A / 255, blue: 0x31 / 255), location: 0.55),
        .init(color: Color(red: 0x1B / 255, green: 0x1E / 255, blue: 0x23 / 255), location: 1),
    ])

    var body: some View {
        Canvas { context, _ in
            context.fill(Path(CGRect(x: 0, y: 0, width: 124, height: 80)), with: .linearGradient(
                Self.desktop, startPoint: .zero, endPoint: CGPoint(x: 68, y: 80)
            ))
            context.fill(Path(CGRect(x: 0, y: 0, width: 124, height: 7)), with: .color(.black.opacity(0.28)))
            context.fill(Path(roundedRect: CGRect(x: 94, y: 2.5, width: 5, height: 2), cornerRadius: 1), with: .color(.white.opacity(0.7)))
            context.fill(Path(roundedRect: CGRect(x: 103, y: 2.5, width: 14, height: 2), cornerRadius: 1), with: .color(.white.opacity(0.45)))
            context.fill(Path(CGRect(x: 0, y: 0, width: 3, height: 80)), with: .color(.black))

            switch show {
            case .notch: context.fill(Self.notch, with: .color(.black))
            case .strip: strip(context)
            case .nothing: context.fill(Path(ellipseIn: CGRect(x: 98.1, y: 0.7, width: 3, height: 3)), with: .color(Self.orange))
            }
        }
        .overlay {
            if show == .notch {
                Canvas { context, _ in light(context) }.opacity(isBright ? 1 : 0.86)
            }
        }
        .onAppear(perform: breathe)
        .onChange(of: isLive) { breathe() }
    }

    /// The notch flared into the bezel.
    private static let notch = {
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

    /// The notch's light, its halo clipped to the notch: breathing while it is the one chosen.
    private func light(_ context: GraphicsContext) {
        var light = context
        light.clip(to: Self.notch)
        var halo = light
        halo.addFilter(.blur(radius: 0.8))
        halo.fill(Path(roundedRect: CGRect(x: 5.24, y: 35.78, width: 1.52, height: 15.44), cornerRadius: 0.76), with: .color(Self.orange.opacity(0.8)))
        light.fill(Path(roundedRect: CGRect(x: 5.5, y: 36.3, width: 1, height: 14.4), cornerRadius: 0.5), with: .color(Self.orange))
    }

    /// The strip down the edge, its marks' rings: two that need Lee, one your turn, two working.
    private func strip(_ context: GraphicsContext) {
        context.fill(Path(CGRect(x: 0, y: 7, width: 10, height: 73)), with: .color(.black))
        let rings: [(y: Double, color: Color, width: Double)] = [
            (15, Self.orange, 1.2), (24, Self.orange, 1.2), (33, .white.opacity(0.9), 1.1),
            (42, Color(white: 0.54).opacity(0.8), 1.1), (51, Color(white: 0.54).opacity(0.8), 1.1),
        ]

        for ring in rings {
            context.stroke(Path(ellipseIn: CGRect(x: 2.4, y: ring.y - 2.6, width: 5.2, height: 5.2)), with: .color(ring.color), lineWidth: ring.width)
        }
    }

    /// The light's breath, 2.4 seconds, as the notch's: only in the chosen picture, and never under reduced motion.
    private func breathe() {
        guard isLive, !reducesMotion else {
            isBright = true
            return
        }

        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { isBright = false }
    }
}
