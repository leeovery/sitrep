import SitRepPanel
import SwiftUI

/// What stays on screen, as three pictures of the screen's edge, drawn from Paper's "Settings in the window": the
/// notch and its light, the strip and its rings, or only the menu bar's glyph, lit. The one chosen is ringed in the
/// accent; a click on another chooses it. It is the menu's Show. Nothing moves at rest, only under the pointer.
struct ShowPictures: View {
    @Binding var show: EdgeSettings.Show
    /// Whether the window is on screen; off it, each picture is at rest.
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

/// A picture and its label, as one button: 225 wide at most, narrower in a narrow window, the picture keeping its
/// shape. Chosen, a gap of the page's black and a ring in the accent round it; else a hairline inside it, lifted
/// while the pointer is over the tile, its label too.
private struct ShowTile: View {
    let choice: EdgeSettings.Show
    let isChosen: Bool
    let isOnScreen: Bool
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
                HoverPicture(show: choice, isOnScreen: isOnScreen)
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
        .onHover { isOver = $0 }
        .onChange(of: isOnScreen) {
            if !isOnScreen {
                isOver = false
            }
        }
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

/// A picture moving under the pointer (`HoverMotion`): the notch's tongue out toward the pointer's height on the
/// attract spring and home on the relax spring; the strip's rings turning by the display's frame, which runs only from
/// the pointer's coming until the arcs have faded after it goes. At rest at once as its window leaves the screen or the
/// page goes, as the pointer's leaving may never be heard then.
private struct HoverPicture: View {
    let show: EdgeSettings.Show
    let isOnScreen: Bool

    @Environment(\.reducesWindowMotion) private var reducesMotion
    @State private var motion: HoverMotion

    init(show: EdgeSettings.Show, isOnScreen: Bool) {
        self.show = show
        self.isOnScreen = isOnScreen
        _motion = State(initialValue: HoverMotion(show: show))
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(paused: motion.turn == nil)) { frame in
                EdgePicture(show: show, pose: motion.pose(at: frame.date))
            }
            .onContinuousHover { phase in
                change { $0.pointer(at: Self.height(phase, in: geometry.size), time: Date(), reducesMotion: reducesMotion) }
            }
        }
        .task(id: motion.turn) { await settle() }
        .onChange(of: reducesMotion) { change { $0.motion(reduced: reducesMotion, at: Date()) } }
        .onChange(of: isOnScreen) {
            if !isOnScreen {
                change { $0.rest() }
            }
        }
        .onDisappear { change { $0.rest() } }
    }

    /// The pointer's height over the picture, in units; nil once it has gone.
    private static func height(_ phase: HoverPhase, in size: CGSize) -> CGFloat? {
        guard case let .active(at) = phase else {
            return nil
        }

        return at.y / size.height * EdgePicture.units.height
    }

    private func change(_ change: (inout HoverMotion) -> HoverMotion.Ease) {
        var next = motion

        switch change(&next) {
        case .follow: motion = next
        case .out: withAnimation(.spring(NotchPicture.out)) { motion = next }
        case .home: withAnimation(.spring(NotchPicture.home)) { motion = next }
        case .snap: withTransaction(\.disablesAnimations, true) { motion = next }
        }
    }

    /// Back at rest once the arcs have faded, the frames stopped.
    private func settle() async {
        guard let turn = motion.turn, let faded = turn.faded,
              (try? await Task.sleep(for: .seconds(max(faded.timeIntervalSinceNow, 0)))) != nil, !Task.isCancelled
        else {
            return
        }

        motion.faded(turn)
    }
}

/// Where a picture stands in its motion. At rest, as drawn: the notch's tongue home, and the strip's rings in their rest
/// look, the working rings' arcs where they rest.
struct PicturePose: Equatable {
    /// How far the notch's tongue reaches out of its crest toward the pointer: 0 at rest, 1 at full reach, past either
    /// as a spring overshoots.
    var reach: CGFloat = 0
    /// The pointer's height, in units, which the tongue's tip reaches toward.
    var tip = NotchPicture.drawnTip
    /// How far the strip's rings are from their rest look to turning: 0 at rest, 1 turning.
    var turning: Double = 0
    /// Where each of the strip's rings' turning arcs starts, top to bottom, in degrees clockwise from 12 o'clock.
    var arcs: [Double] = StripPicture.rings.map { _ in 0 }

    static let rest = PicturePose()
}

/// One picture, drawn in its 124 × 80 units scaled to its size: a dark desktop under a menu bar, the bezel down its
/// left, and what shows there, as it stands at `pose`, its reach and tip following a spring.
struct EdgePicture: View, Animatable {
    let show: EdgeSettings.Show
    var pose = PicturePose.rest

    static let units = CGSize(width: 124, height: 80)

    nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(pose.reach, pose.tip) }
        set { (pose.reach, pose.tip) = (newValue.first, newValue.second) }
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
