import AppKit
import SitRepEdge
import SitRepPanel
import SwiftUI

/// The notch in Liquid Glass, from macOS 26, Meniscus or Card alike: the notch and the panel in the very outline the
/// black is drawn in, rebuilt from the model each frame, as thick glass from the notch at rest to the panel out, so
/// the pour and the drain never change it at once; the panel's rows over it in the glass's label colours, needs you
/// Claude's orange; and the Live light in the notch as on the black, over the glass. Takes no clicks itself.
@available(macOS 26, *)
@MainActor
final class NotchGlassView: NSView, NotchDrawing {
    private let scene = NotchGlassScene()
    /// The light, through the edge's mirror, as the black's is.
    private let stage = CALayer()
    private let light = LightLayer()

    init() {
        super.init(frame: .zero)

        let host = NSHostingView(rootView: NotchGlass(scene: scene))
        let root = CALayer(), lit = StageHost(hosting: root)

        host.sizingOptions = []
        for view in [host, lit] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
        stage.addSublayer(light)
        root.addSublayer(stage)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rescaleToWindow()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rescaleToWindow()
    }

    func show(_ list: PanelList) {
        scene.list = list
    }

    func show(_ scene: NotchScene) {
        self.scene.now = scene.now
        self.scene.calendar = scene.calendar
        self.scene.frame = scene
        still {
            // a layer turns about its centre, so the window's mirror is its flip alone
            stage.bounds = bounds
            stage.position = CGPoint(x: bounds.midX, y: bounds.midY)
            stage.setAffineTransform(CGAffineTransform(scaleX: scene.mirror.a, y: 1))
        }
    }

    func showLight(_ placed: Frame.Light, outline: CGPath, colours: LiveLight) {
        light.show(placed, outline: outline, colours: colours)
    }

    /// Each row washed from its own time, never the last frame's; washes over by then are let go.
    func wash(_ rows: Set<String>, at time: Double) {
        scene.washed = Wash.live(scene.washed, at: time)
        rows.forEach { scene.washed[$0] = time }
    }

    /// When each row's wash began, by its key.
    var washed: [String: Double] { scene.washed }

    private func rescaleToWindow() {
        if let scale = window?.backingScaleFactor {
            rescale(stage, to: scale)
        }
    }
}

/// What the glass draws, as last told.
@available(macOS 26, *)
@MainActor
@Observable
final class NotchGlassScene {
    var list = PanelList(head: nil, content: Content(laying: []))
    var frame: NotchScene?
    /// The wall clock at the last frame, ms, and the calendar the rows' wake times are worded on.
    var now = 0.0
    var calendar = WakeTime.calendar
    /// When each new row's wash began, on the display's clock, by the row's key.
    var washed: [String: Double] = [:]
}

/// The glass and the panel's content on it, in the window's own coordinates.
@available(macOS 26, *)
private struct NotchGlass: View {
    let scene: NotchGlassScene

    var body: some View {
        if let shown = scene.frame {
            let frame = shown.frame
            ZStack(alignment: .topLeading) {
                if let fading = frame.fading {
                    glass(fading.outline, shown.mirror, NotchGlassMark(openness: Frame.openness(fading.outline)))
                        .opacity(fading.alpha)
                }
                glass(frame.outline, shown.mirror, NotchGlassMark(openness: frame.openness))
                    .opacity(frame.outlineAlpha)
                    .shadow(
                        color: .black.opacity(0.4 * frame.lift), radius: EdgeStyle.liftBlur * frame.lift,
                        y: 4 * frame.lift
                    )
                if let panel = frame.panel {
                    GlassPanel(panel: panel, scene: shown, list: scene.list, washed: scene.washed)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    /// Thick glass in an outline, as marked: the notch at rest is narrow enough to be thin, and would switch as the
    /// panel pours. The rim is stroked twice its width on the outline and clipped to it, so it lies inside the edge.
    private func glass(_ outline: CGPath, _ mirror: CGAffineTransform, _ mark: NotchGlassMark) -> some View {
        var mirror = mirror
        let drawn = Path(outline.copy(using: &mirror) ?? outline)
        let glass = Glass.regular.tint(mark.tint > 0 ? .black.opacity(mark.tint) : nil)

        return Color.clear
            .glassEffect(glass, in: Outline(path: GlassThickness.thick(drawn.cgPath, width: ScreenEdge.depth)))
            .overlay(alignment: .topLeading) {
                if mark.rim > 0 {
                    Outline(path: drawn)
                        .stroke(.white.opacity(mark.rim), lineWidth: 2 * NotchGlassMark.rimWidth)
                        .clipShape(Outline(path: drawn))
                }
            }
    }
}

/// How the glass marks the notch, which the black marks by its own dark: the glass tinted dark, with a light rim
/// inside its edge, in full at the notch and easing off as the panel comes out, to the plain glass of the panel open.
/// Each outline is marked by its own openness, so under reduced motion the outline fading out keeps its mark.
struct NotchGlassMark {
    /// The black's opacity in the glass's tint.
    let tint: Double
    /// The rim's opacity.
    let rim: Double

    static let notchTint = 0.5
    static let notchRim = 0.22
    static let rimWidth = 1.0

    init(openness: Double) {
        let notch = 1 - openness

        tint = Self.notchTint * notch
        rim = Self.notchRim * notch
    }
}

/// The panel's content as the black's: its head, where it has one, and its list, the sections under their eyebrows,
/// moved with the panel, scrolled, clipped to its body with its front corners rounded, each item landing or fading as
/// the frame paints it.
@available(macOS 26, *)
private struct GlassPanel: View {
    let panel: Frame.Panel
    let scene: NotchScene
    let list: PanelList
    let washed: [String: Double]

    var body: some View {
        let box = panel.drawn(scene.mirror), content = list.content
        ZStack(alignment: .topLeading) {
            if let head = list.head {
                GlassHead(head: head)
                    .frame(width: content.headFrame.width, height: HeadLayout.line, alignment: .top)
                    .painted(panel.head, at: content.headFrame.origin)
            }
            ForEach(placed(content)) { placed in
                let i = placed.index, itemBox = content.itemFrame(i), shows = content.entries[i].item
                item(shows, lit: scene.hover == i, pressed: shows.key == panel.pressed, width: itemBox.width)
                    .frame(width: itemBox.width, height: itemBox.height, alignment: .topLeading)
                    .clipped()
                    .painted(placed.paint, at: itemBox.origin)
            }
        }
        .offset(y: -scene.scroll)
        .frame(width: box.width, height: box.height, alignment: .topLeading)
        .clipShape(Outline(path: Path(panel.clipPath(scene.mirror))))
        .offset(x: box.minX, y: box.minY)
    }

    /// Each item with its paint, known by its key, as the black keeps its rows: a row keeps its own lift, press, arc
    /// and sweep as the rows around it fold.
    private func placed(_ content: Content) -> [Placed] {
        zip(content.entries.indices, panel.items).map { Placed(id: content.entries[$0].item.key, index: $0, paint: $1) }
    }

    /// An item at its own height, which its box clips as it folds, what it draws where its margins leave it. The card
    /// lists no divider, the menu's alone, so one draws nothing.
    @ViewBuilder private func item(_ item: Item, lit: Bool, pressed: Bool, width: Double) -> some View {
        let box = item.box(width: width)

        switch item {
        case let .session(session), let .line(session):
            GlassSessionRow(
                session: session, size: box.size, hovered: lit, pressed: pressed, now: scene.now, wash: wash(item.key),
                calendar: scene.calendar
            )
            .offset(y: box.minY)
        case let .eyebrow(eyebrow):
            GlassEyebrow(eyebrow: eyebrow, size: box.size).offset(y: box.minY)
        case .divider:
            EmptyView()
        }
    }

    /// A new row's wash at this frame, as the black's: held 300ms, then easing out by 2 seconds.
    private func wash(_ key: String) -> Double {
        washed[key].map { Wash.amount(since: scene.time - $0) } ?? 0
    }
}

/// An item at its place in the list, with its paint, known by its key.
private struct Placed: Identifiable {
    let id: String
    let index: Int
    let paint: Frame.Paint
}

/// The head: how many need Lee at the left, how many sessions at the right, on one baseline.
@available(macOS 26, *)
private struct GlassHead: View {
    let head: Head

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text.tight(head.title, EdgeStyle.headTitle).foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text(head.count).font(Font(EdgeStyle.headCount)).foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .padding(.leading, HeadLayout.inset.left)
        .padding(.trailing, HeadLayout.inset.right)
    }
}

/// A session's row on glass, on one line, laid out as the black's (board J): its mark, its title (`Session.headline`),
/// a session's count after its name, its project in the tertiary at the right of its words, never cut, and its time.
/// Under the pointer, a row that jumps lifts, and a click jumping from it presses it in with an arc spinning in its
/// time's place. A row needing Lee is its name, in medium, an away one's dimmed; a your-turn row its ring and its
/// words, in regular; a Working row its verb, then what follows it 6 on, shimmering while it works and still on its own
/// work, its subject plain or a wake's countdown; one in Snoozed is quieted, as the black's: its dot unlit, its name in
/// the secondary, and when it wakes in its time's place.
@available(macOS 26, *)
struct GlassSessionRow: View {
    let session: Session
    let size: CGSize
    /// Under the pointer.
    let hovered: Bool
    let pressed: Bool
    /// The wall clock, ms.
    let now: Double
    /// How washed it is, from 1 as it comes to 0.
    let wash: Double
    /// The calendar its wake time is worded on.
    var calendar = WakeTime.calendar

    var body: some View {
        let at = layout, radius = SessionRowLayout.radius
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: radius)
                .fill(.primary.opacity(pressed ? 0.12 : hovered ? 0.08 : 0))
                .animation(.easeOut(duration: 0.11), value: pressed)
            RoundedRectangle(cornerRadius: radius)
                .fill(GlassInk.orange.opacity(0.12))
                .strokeBorder(GlassInk.orange.opacity(0.26), lineWidth: 1)
                .opacity(wash)
            mark.position(at.mark)
            title(width: at.title.width).placed(in: at.title)
            Text(session.project).font(Font(EdgeStyle.sub)).foregroundStyle(.tertiary)
                .placed(in: at.project.offsetBy(dx: 0, dy: TextLine.drop(of: EdgeStyle.sub, to: EdgeStyle.line, lineHeight: at.project.height)))
            if pressed {
                spinner.placed(in: at.age, alignment: .trailing)
            } else {
                Text(time)
                    .font(Font(EdgeStyle.age))
                    .foregroundStyle(session.isSnoozed ? .secondary : .tertiary)
                    .placed(in: at.age, alignment: .trailing)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(.easeOut(duration: 0.11), value: hovered)
        .scaleEffect(pressed ? 0.985 : 1)
        .animation(.easeOut(duration: 0.14), value: pressed)
    }

    /// Its count: dimmer in Snoozed.
    private var soft: HierarchicalShapeStyle { session.isSnoozed ? .tertiary : .secondary }

    /// Its title and its count, dimmed by the one factor while no window holds it, but in Snoozed, quieted already.
    private var awayDim: Double { Away.dimming(session.away && !session.isSnoozed) }

    /// What its time's place says: its age, or in Snoozed when it wakes, or that it waits until it moves.
    private var time: String { session.timeText(at: now, in: calendar) }

    /// Laid out as the black lays its row out: its project's lane as wide as its project is set; in Snoozed, its
    /// time's lane as wide as when it wakes is set.
    private var layout: SessionRowLayout {
        let wakes = session.isSnoozed ? TextLine.width(TextLine.text(time, EdgeStyle.age, EdgeStyle.ink2)) : 0
        let project = TextLine.width(TextLine.text(session.project, EdgeStyle.sub, EdgeStyle.ink3))

        return SessionRowLayout(size: size, project: project, time: wakes)
    }

    /// The arc turning once a second, as a working row's mark.
    private var spinner: some View {
        Spinner(track: .quaternaryLabelColor, arc: .labelColor, period: 1).frame(width: 11, height: 11)
    }

    /// As on the black: in Needs you an ask's orange or Lee's turn's blue, a dot with its glow, and away a hollow ring,
    /// unlit (`Away`); working the arc turning; on its own work the dotted ring, still; in Snoozed the dot dimmed,
    /// unlit.
    @ViewBuilder private var mark: some View {
        let colour = GlassInk.colour(of: session.isTurn ? .turn : .ask)

        switch session.kind {
        case .needs where session.away, .turn where session.away:
            AwayRing(ink: colour)
        case .needs, .turn:
            Circle().fill(colour).frame(width: 7, height: 7)
                .shadow(color: colour.opacity(0.75), radius: 2)
        case .working:
            spinner
        case .onItsWork:
            DottedRingView(ring: .card, ink: .secondary)
        case .snoozed, .snoozedTurn:
            Circle().fill(colour.opacity(Away.dim)).frame(width: 7, height: 7)
        }
    }

    /// Its title in a box this wide, cut short before a session's count, which sits 6 after it on its baseline: a
    /// Working one its verb, then 6 after it what follows it, which is cut short first, the verb shimmering while it
    /// works and still on its own work; an away one dim, its count with it.
    private func title(width: Double) -> some View {
        let line = session.headline

        return HStack(alignment: .firstTextBaseline, spacing: SessionRowLayout.countGap) {
            switch session.kind {
            case .working, .onItsWork:
                HStack(alignment: .firstTextBaseline, spacing: LineTitle.gap) {
                    if session.kind == .working {
                        Shimmering(text: verb(line), width: width).layoutPriority(1)
                    } else {
                        verb(line).foregroundStyle(.secondary).layoutPriority(1)
                    }
                    after(line).foregroundStyle(.secondary).truncationMode(.tail)
                }
            case .needs, .turn, .snoozed, .snoozedTurn:
                Text.tight(line.title, titleFont)
                    .foregroundStyle(session.isSnoozed ? .secondary : .primary).truncationMode(.tail)
            }
            if let more = line.more {
                Text(more).font(Font(EdgeStyle.count)).foregroundStyle(soft)
                    .fixedSize()
            }
        }
        .lineLimit(1)
        .opacity(awayDim)
    }

    /// Its title's type, 13, as the black's: needing Lee, its name in medium; else in regular.
    private var titleFont: NSFont {
        session.needsLee ? EdgeStyle.lineMedium : EdgeStyle.line
    }

    /// A Working row's verb, 13 medium, less the space core's line ends it with where something follows.
    private func verb(_ line: Session.Line) -> Text {
        let lead = line.title.hasSuffix(" ") ? String(line.title.dropLast()) : line.title

        return Text.tight(lead, EdgeStyle.lineMedium)
    }

    /// What follows a Working row's verb: its command in mono 12, or its subject or a wake's countdown in tabular
    /// figures, 13 regular, as the black's.
    @ViewBuilder private func after(_ line: Session.Line) -> some View {
        if let code = line.code {
            Text(code).font(Font(EdgeStyle.lineCode))
        } else if let subject = line.subject(at: now) {
            Text.tight(subject, line.until == nil ? EdgeStyle.line : EdgeStyle.lineCountdown)
        }
    }
}

extension View {
    /// Where the content puts it, as the frame paints it: its opacity, and how far below its place it still is.
    fileprivate func painted(_ paint: Frame.Paint, at origin: CGPoint) -> some View {
        offset(x: origin.x, y: origin.y + paint.rise).opacity(paint.alpha)
    }
}
