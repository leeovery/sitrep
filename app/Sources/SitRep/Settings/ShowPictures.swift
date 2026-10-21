import SitRepPanel
import SwiftUI

/// What stays on screen, as three pictures of the screen's edge, drawn from Paper's "Settings in the window": the
/// notch and its light, the strip and its rings, or only the menu bar's glyph, lit. The one chosen is ringed in the
/// accent; a click on another chooses it. It is the menu's Show. Nothing moves at rest, only under the pointer.
struct ShowPictures: View {
    @Binding var show: EdgeSettings.Show

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(EdgeSettings.Show.allCases, id: \.self) { choice in
                ShowTile(choice: choice, isChosen: choice == show) { show = choice }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

/// A picture and its label, as one button: 225 wide at most, narrower in a narrow window, the picture keeping its
/// shape. Chosen, a gap of the page's black and a ring in the accent round it; else a hairline inside it, lifted
/// under the pointer.
private struct ShowTile: View {
    let choice: EdgeSettings.Show
    let isChosen: Bool
    let choose: () -> Void

    @State private var isOver = false

    private static let width: CGFloat = 225
    private static let shape = CGSize(width: 225, height: 145)
    private static let radius: CGFloat = 12
    /// The ring's middle, past the picture's edge: a gap of 2, then a ring 2.5 wide.
    private static let ring: CGFloat = 2 + 2.5 / 2

    var body: some View {
        let picture = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)

        Button(action: choose) {
            VStack(spacing: 10) {
                HoverPicture(show: choice, isOver: $isOver)
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
                    .foregroundStyle(isChosen ? .primary : .secondary)
                    .frame(height: 18)
            }
            .frame(maxWidth: Self.width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// A picture moving under the pointer, where `PictureHover` says it may: the notch's tongue out toward the pointer's
/// height on the attract spring and home on the relax spring; the strip's rings turning by the display's frame, which
/// runs only from the pointer's coming until the arcs have faded after it goes.
private struct HoverPicture: View {
    let show: EdgeSettings.Show
    @Binding var isOver: Bool

    @Environment(\.reducesWindowMotion) private var reducesMotion
    @State private var reach: CGFloat = 0
    @State private var tip: CGFloat?
    @State private var turn: StripTurn?

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(paused: turn == nil)) { frame in
                EdgePicture(show: show, pose: pose(at: frame.date))
            }
            .onContinuousHover { hover($0, height: geometry.size.height) }
        }
        .task(id: turn) { await rest() }
        .onChange(of: reducesMotion) {
            if reducesMotion {
                reach = 0
                turn = nil
            }
        }
    }

    private var moves: Bool { PictureHover.moves(show, reducesMotion: reducesMotion) }

    private func pose(at time: Date) -> PicturePose {
        var pose = turn?.pose(at: time) ?? .rest

        pose.reach = reach
        pose.tip = tip
        return pose
    }

    private func hover(_ phase: HoverPhase, height: CGFloat) {
        switch phase {
        case let .active(at):
            if show == .notch, moves {
                tip = at.y / height * EdgePicture.units.height
            }
            if !isOver {
                isOver = true
                enter()
            }
        case .ended:
            isOver = false
            withAnimation(.spring(NotchPicture.home)) { reach = 0 }
            turn = turn?.left(at: Date())
        }
    }

    private func enter() {
        guard moves else {
            return
        }

        switch show {
        case .notch: withAnimation(.spring(NotchPicture.out)) { reach = 1 }
        case .strip: turn = turn?.entered(at: Date()) ?? StripTurn(since: Date())
        case .nothing: break
        }
    }

    /// Back at rest once the arcs have faded, the frames stopped.
    private func rest() async {
        guard let faded = turn?.faded, (try? await Task.sleep(for: .seconds(max(faded.timeIntervalSinceNow, 0)))) != nil
        else {
            return
        }

        turn = nil
    }
}

/// Where a picture stands in its motion. At rest, as drawn: the notch's tongue home, and the strip's rings in their rest
/// look, the working rings' arcs where they rest.
struct PicturePose: Equatable {
    /// How far the notch's tongue reaches out of its crest toward the pointer: 0 at rest, 1 at full reach, past either
    /// as a spring overshoots.
    var reach: CGFloat = 0
    /// The pointer's height, in units, which the tongue's tip reaches toward; nil for the tip where it is drawn.
    var tip: CGFloat?
    /// How far the strip's rings are from their rest look to turning: 0 at rest, 1 turning.
    var turning: Double = 0
    /// Where each of the strip's rings' turning arcs starts, top to bottom, in degrees clockwise from 12 o'clock.
    var arcs: [Double] = StripPicture.rings.map { _ in 0 }

    static let rest = PicturePose()
}

/// One picture, drawn in its 124 × 80 units scaled to its size: a dark desktop under a menu bar, the bezel down its
/// left, and what shows there, as it stands at `pose`, its reach following a spring.
struct EdgePicture: View, Animatable {
    let show: EdgeSettings.Show
    var pose = PicturePose.rest

    static let units = CGSize(width: 124, height: 80)

    nonisolated var animatableData: CGFloat {
        get { pose.reach }
        set { pose.reach = newValue }
    }

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / Self.units.width, y: size.height / Self.units.height)
            Self.desktop(context, extras: show != .nothing)
            switch show {
            case .notch: NotchPicture.draw(context, reach: pose.reach, tip: pose.tip)
            case .strip: StripPicture.draw(context, turning: pose.turning, arcs: pose.arcs)
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

    /// The menu bar's glyph, lit: its housing, and its bar in orange.
    private static func glyph(_ context: GraphicsContext) {
        context.stroke(
            Path(roundedRect: CGRect(x: 96.1, y: 1.55, width: 2.3, height: 3.9), cornerRadius: 1.15),
            with: .color(ink.opacity(0.9)), lineWidth: 0.4
        )
        context.fill(Path(roundedRect: CGRect(x: 96.75, y: 2.2, width: 1, height: 2.6), cornerRadius: 0.5), with: .color(WindowStyle.orange))
    }
}

/// The notch, black, flared from the bezel out to its crest, and its light; reaching, a tongue out of the crest, the
/// light brightening with it.
enum NotchPicture {
    /// The notch's outline at a reach from 0, its crest a straight run, to 1, the tongue at full reach, its tip about
    /// 6.5 units past the crest, its tip toward `tip`.
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

    /// The notch and its light at a reach: the light's glow and core grow from those at rest to the brighter, wider
    /// ones at full reach.
    static func draw(_ context: GraphicsContext, reach: CGFloat, tip: CGFloat?) {
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
        lit.fill(core, with: .color(lift.opacity(reach)))
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

/// The strip as it stands at Length Grows, a 36-point strip drawn 9 wide: a black column out of the bezel, its ends
/// curving back into the edge in the strip's own S, centred 0.42 of the way down; its rings in the panel's order,
/// needs you lit orange with its glow, the hairline under it, your turn in white, then two working.
enum StripPicture {
    enum Ring {
        case needs, turn, working
    }

    /// The rings, top to bottom, by their middles' height.
    static let rings: [(y: CGFloat, ring: Ring)] = [(20.7, .needs), (31.45, .turn), (38.95, .working), (46.45, .working)]
    /// At rest the working rings' arcs stand at 12 o'clock and at 45°; the others are whole.
    static let restingArcs: [Double?] = [nil, nil, 0, 45]

    private static let centre: CGFloat = 7.5
    private static let radius: CGFloat = 2.75
    private static let turnInk = Color(hex: 0xF5F5F7)

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

    /// The strip with its rings `turning` of the way from their rest look to turning, their turning arcs from `arcs`.
    static func draw(_ context: GraphicsContext, turning: Double, arcs: [Double]) {
        context.fill(column, with: .color(.black))
        context.fill(Path(CGRect(x: 5.5, y: 25.95, width: 4, height: 0.25)), with: .color(Color(hex: 0x3A3A40)))
        for (((y, ring), resting), arc) in zip(zip(rings, restingArcs), arcs) {
            draw(ring, at: CGPoint(x: centre, y: y), resting: resting, turning: turning, arc: arc, in: context)
        }
    }

    /// A ring at rest whole in its colour, or a working one's track and its arc where it rests; turning, its track with
    /// a quarter arc of its colour from `arc`; part way, the one look faded into the other.
    private static func draw(
        _ ring: Ring, at middle: CGPoint, resting: Double?, turning: Double, arc: Double, in context: GraphicsContext
    ) {
        let circle = Path(ellipseIn: CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2))
        var rest = context
        var turn = context

        rest.opacity = 1 - turning
        turn.opacity = turning
        if let resting {
            context.stroke(circle, with: .color(track(ring)), lineWidth: 0.5)
            draw(ring, quarter(from: resting, round: middle), in: rest)
        } else {
            turn.stroke(circle, with: .color(track(ring)), lineWidth: 0.5)
            if ring == .needs {
                glow(circle, opacity: 0.75, blur: 0.7, in: rest)
            }
            rest.stroke(circle, with: .color(ink(ring)), lineWidth: 0.5)
        }
        draw(ring, quarter(from: arc, round: middle), in: turn)
    }

    /// A quarter arc of a ring's colour, needs you's with its glow.
    private static func draw(_ ring: Ring, _ quarter: Path, in context: GraphicsContext) {
        if ring == .needs {
            glow(quarter, opacity: 0.7, blur: 0.6, in: context)
        }
        context.stroke(quarter, with: .color(ink(ring)), style: StrokeStyle(lineWidth: ring == .working ? 0.5 : 0.6, lineCap: .round))
    }

    private static func quarter(from start: Double, round middle: CGPoint) -> Path {
        var quarter = Path()

        quarter.addRelativeArc(center: middle, radius: radius, startAngle: .degrees(start - 90), delta: .degrees(90))
        return quarter
    }

    private static func glow(_ path: Path, opacity: Double, blur: CGFloat, in context: GraphicsContext) {
        var glow = context

        glow.opacity *= opacity
        glow.addFilter(.blur(radius: blur))
        glow.stroke(path, with: .color(WindowStyle.orange), lineWidth: 0.9)
    }

    private static func ink(_ ring: Ring) -> Color {
        switch ring {
        case .needs: WindowStyle.orange
        case .turn: turnInk
        case .working: WindowStyle.arc
        }
    }

    /// The track a turning ring dims to, its own colour faint; a working ring's is its track at rest.
    private static func track(_ ring: Ring) -> Color {
        switch ring {
        case .needs: WindowStyle.orange.opacity(0.35)
        case .turn: turnInk.opacity(0.25)
        case .working: WindowStyle.track
        }
    }
}
