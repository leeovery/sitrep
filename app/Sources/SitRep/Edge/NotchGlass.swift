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
    var list = PanelList(head: Head(title: "", count: ""), content: Content(laying: []))
    var frame: NotchScene?
    /// The wall clock at the last frame, ms.
    var now = 0.0
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

/// The panel's content as the black's: its head and its list, moved with the panel, scrolled, clipped to its body
/// with its front corners rounded, each row landing or fading as the frame paints it.
@available(macOS 26, *)
private struct GlassPanel: View {
    let panel: Frame.Panel
    let scene: NotchScene
    let list: PanelList
    let washed: [String: Double]

    var body: some View {
        let box = panel.drawn(scene.mirror), content = list.content
        ZStack(alignment: .topLeading) {
            GlassHead(head: list.head)
                .frame(width: content.headFrame.width, height: HeadLayout.line, alignment: .top)
                .painted(panel.head, at: content.headFrame.origin)
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

    /// An item at its own height, which its box clips as it folds.
    @ViewBuilder private func item(_ item: Item, lit: Bool, pressed: Bool, width: Double) -> some View {
        if let session = item.session {
            GlassSessionRow(
                session: session, size: CGSize(width: width, height: item.height - Item.rowGap),
                lit: lit && session.jumps, pressed: pressed, now: scene.now, wash: wash(session.id)
            )
        } else {
            let rule = DividerLayout.rule(width: width)
            Rectangle().fill(.separator).frame(width: rule.width, height: rule.height)
                .offset(x: rule.minX, y: rule.minY)
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
            Text(head.title).font(.system(size: 13, weight: .semibold)).kerning(-0.13).foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text(head.count).font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        .lineLimit(1)
        .padding(.leading, HeadLayout.inset.left)
        .padding(.trailing, HeadLayout.inset.right)
    }
}

/// A session's row on glass: its mark, its title with its subject and its "+2", its project and session, its time,
/// laid out as the black's; under the pointer, a row that jumps lifts, and a click jumping from it presses it in with
/// an arc spinning in its time's place.
@available(macOS 26, *)
private struct GlassSessionRow: View {
    let session: Session
    let size: CGSize
    let lit: Bool
    let pressed: Bool
    /// The wall clock, ms.
    let now: Double
    /// How washed it is, from 1 as it comes to 0.
    let wash: Double

    var body: some View {
        let at = SessionRowLayout(size: size)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: SessionRowLayout.radius)
                .fill(.primary.opacity(pressed ? 0.12 : lit ? 0.08 : 0))
                .animation(.easeOut(duration: 0.11), value: pressed)
            RoundedRectangle(cornerRadius: SessionRowLayout.radius)
                .fill(GlassInk.orange.opacity(0.12))
                .strokeBorder(GlassInk.orange.opacity(0.26), lineWidth: 1)
                .opacity(wash)
            mark.position(at.mark)
            title(width: at.title.width).placed(in: at.title)
            Text(session.sub).font(.system(size: 12)).foregroundStyle(session.away ? .tertiary : .secondary)
                .placed(in: at.sub)
            if pressed {
                spinner.placed(in: at.age, alignment: .trailing)
            } else {
                Text(session.ageText(at: now))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .placed(in: at.age, alignment: .trailing)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(.easeOut(duration: 0.11), value: lit)
        .scaleEffect(pressed ? 0.985 : 1)
        .animation(.easeOut(duration: 0.14), value: pressed)
    }

    /// The arc turning once a second, as a working row's mark.
    private var spinner: some View {
        Spinner(track: .quaternaryLabelColor, arc: .labelColor, period: 1).frame(width: 11, height: 11)
    }

    /// Needs you an orange dot with its glow, away or not; your turn an open ring; working the arc turning.
    @ViewBuilder private var mark: some View {
        switch session.kind {
        case .needs:
            Circle().fill(GlassInk.orange).frame(width: 7, height: 7)
                .shadow(color: GlassInk.orange.opacity(0.75), radius: 2)
        case .turn:
            Circle().strokeBorder(.primary, lineWidth: 1.5).frame(width: 7, height: 7)
        case .working:
            spinner
        }
    }

    /// The title in a box this wide, cut short before a question's "+2": a working one shimmering along its lead, its
    /// subject still; an away one dim.
    private func title(width: Double) -> some View {
        HStack(spacing: SessionRowLayout.moreGap) {
            if session.kind == .working {
                HStack(spacing: 0) {
                    Shimmering(text: lead, width: width)
                    subject.foregroundStyle(.secondary)
                }
            } else {
                let style: HierarchicalShapeStyle = session.away ? .tertiary : .primary
                (lead.foregroundStyle(style) + subject.foregroundStyle(style)).truncationMode(.tail)
            }
            if let more = session.more {
                Text(more).font(titleFont).foregroundStyle(.secondary).fixedSize()
            }
        }
        .lineLimit(1)
    }

    private var lead: Text { Text(session.title).font(titleFont).kerning(-0.14) }

    private var titleFont: Font { .system(size: 14, weight: session.kind == .needs ? .semibold : .medium) }

    /// Its subject in mono, after the title.
    private var subject: Text {
        Text(session.code ?? "").font(.system(size: 13, weight: .medium, design: .monospaced))
    }
}

extension View {
    /// Where the content puts it, as the frame paints it: its opacity, and how far below its place it still is.
    fileprivate func painted(_ paint: Frame.Paint, at origin: CGPoint) -> some View {
        offset(x: origin.x, y: origin.y + paint.rise).opacity(paint.alpha)
    }
}
