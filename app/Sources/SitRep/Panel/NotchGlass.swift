import AppKit
import SitRepPanel
import SwiftUI

/// The notch in Liquid Glass, from macOS 26, Meniscus or Card alike: the lip and the panel in the very outline the
/// black is drawn in, rebuilt from the model each frame, as thick glass from the lip at rest to the panel out, so the
/// pour and the drain never change it at once; the panel's rows over it in the glass's label colours, needs you
/// Claude's orange; and the Live light in the lip as on the black, over the glass. Takes no clicks itself.
@available(macOS 26, *)
@MainActor
final class NotchGlassView: NSView, NotchDrawing {
    private let scene: NotchGlassScene
    private let light = LightLayer()

    init(items: [Item], content: Content) {
        scene = NotchGlassScene(items: items, content: content)
        super.init(frame: .zero)

        let host = NSHostingView(rootView: NotchGlass(scene: scene))
        let lit = NSView(frame: bounds), root = CALayer()

        host.sizingOptions = []
        for view in [host, lit] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
        root.isGeometryFlipped = true
        root.addSublayer(light)
        lit.layer = root
        lit.wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rescale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rescale()
    }

    func show(_ frame: Frame, hover: Int?) {
        scene.frame = frame
        scene.hover = hover
    }

    func showLight(_ placed: Frame.Light, outline: CGPath, colours: LiveLight) {
        light.show(placed, outline: outline, colours: colours)
    }

    /// The light drawn at the screen's pixel density, so it stays crisp on Retina.
    private func rescale() {
        guard let scale = window?.backingScaleFactor else {
            return
        }

        light.contentsScale = scale
        light.setNeedsDisplay()
    }
}

/// What the glass draws, as last told.
@available(macOS 26, *)
@MainActor
@Observable
final class NotchGlassScene {
    let items: [Item]
    let content: Content
    var frame: Frame?
    var hover: Int?

    init(items: [Item], content: Content) {
        self.items = items
        self.content = content
    }
}

/// The glass and the panel's content on it, in the stage's own coordinates, as the window's are.
@available(macOS 26, *)
private struct NotchGlass: View {
    let scene: NotchGlassScene

    var body: some View {
        if let frame = scene.frame {
            ZStack(alignment: .topLeading) {
                if let fading = frame.fading {
                    glass(fading.outline).opacity(fading.alpha)
                }
                glass(frame.outline).opacity(frame.outlineAlpha)
                if let panel = frame.panel {
                    GlassPanel(panel: panel, items: scene.items, content: scene.content, hover: scene.hover)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    /// Thick glass in an outline: the lip at rest is narrow enough to be thin, and would switch as the panel pours.
    private func glass(_ outline: CGPath) -> some View {
        Color.clear.glassEffect(.regular, in: Outline(path: GlassThickness.thick(outline, width: ScreenEdge.depth)))
    }
}

/// The panel's content as the black's: its head and its list, moved with the panel, clipped to its body with its
/// front corners rounded, each row landing or fading as the frame paints it.
@available(macOS 26, *)
private struct GlassPanel: View {
    let panel: Frame.Panel
    let items: [Item]
    let content: Content
    let hover: Int?

    var body: some View {
        let box = panel.frame
        ZStack(alignment: .topLeading) {
            GlassHead(head: Head(items))
                .frame(width: content.headFrame.width, height: HeadLayout.line, alignment: .top)
                .painted(panel.head, at: content.headFrame.origin)
            ForEach(items.indices, id: \.self) { i in
                let itemBox = content.itemFrame(i)
                item(i, width: itemBox.width, height: itemBox.height)
                    .frame(width: itemBox.width, height: itemBox.height, alignment: .topLeading)
                    .painted(panel.items[i], at: itemBox.origin)
            }
        }
        .frame(width: box.width, height: box.height, alignment: .topLeading)
        .clipShape(FrontRounded(
            rect: panel.clip.offsetBy(dx: -box.minX, dy: -box.minY), top: panel.topRadius, bottom: panel.bottomRadius
        ))
        .offset(x: box.minX, y: box.minY)
    }

    @ViewBuilder private func item(_ i: Int, width: Double, height: Double) -> some View {
        if let session = items[i].session {
            GlassSessionRow(
                session: session, size: CGSize(width: width, height: height - Item.rowGap),
                lit: hover == i && session.jumps
            )
        } else {
            let rule = DividerLayout.rule(width: width)
            Rectangle().fill(.separator).frame(width: rule.width, height: rule.height)
                .offset(x: rule.minX, y: rule.minY)
        }
    }
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

/// A session's row on glass: its mark, its title and its project and work, its age, laid out as the black's; under
/// the pointer, a row that jumps lifts.
@available(macOS 26, *)
private struct GlassSessionRow: View {
    let session: Session
    let size: CGSize
    let lit: Bool

    var body: some View {
        let at = SessionRowLayout(size: size)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: SessionRowLayout.radius).fill(.primary.opacity(lit ? 0.08 : 0))
            mark.position(at.mark)
            title(in: at.title)
            Text(session.sub).font(.system(size: 12)).foregroundStyle(.secondary).placed(in: at.sub)
            Text(session.ageText)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.tertiary)
                .placed(in: at.age, alignment: .trailing)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(.easeOut(duration: 0.11), value: lit)
    }

    /// Needs you an orange dot with its glow, your turn a ring, working the arc turning, quiet a faint dot and away
    /// a faint ring.
    @ViewBuilder private var mark: some View {
        switch session.kind {
        case .needs:
            Circle().fill(GlassInk.orange).frame(width: 7, height: 7)
                .shadow(color: GlassInk.orange.opacity(0.75), radius: 2)
        case .turn:
            Circle().strokeBorder(.primary, lineWidth: 1.5).frame(width: 7, height: 7)
        case .working:
            Spinner(track: .quaternaryLabelColor, arc: .labelColor, period: 1)
                .frame(width: 11, height: 11)
        case .quiet:
            Circle().fill(.tertiary).frame(width: 5, height: 5)
        case .off:
            Circle().strokeBorder(.tertiary, lineWidth: 1).frame(width: 5, height: 5)
        }
    }

    @ViewBuilder private func title(in box: CGRect) -> some View {
        let text = titleText
        switch session.kind {
        case .working: Shimmering(text: text, width: box.width).placed(in: box)
        case .quiet: text.foregroundStyle(.secondary).placed(in: box)
        case .off: text.foregroundStyle(.tertiary).placed(in: box)
        case .needs, .turn: text.foregroundStyle(.primary).placed(in: box)
        }
    }

    /// The title, its command in code type, as the black's is set.
    private var titleText: Text {
        let title = Text(session.title)
            .font(.system(size: 14, weight: session.kind == .needs ? .semibold : .medium))
            .kerning(-0.14)
        guard let code = session.code else {
            return title
        }

        return title + Text(code).font(.system(size: 13, weight: .medium, design: .monospaced))
    }
}

extension View {
    /// Where the content puts it, as the frame paints it: its opacity, and how far below its place it still is.
    fileprivate func painted(_ paint: Frame.Paint, at origin: CGPoint) -> some View {
        offset(x: origin.x, y: origin.y + paint.rise).opacity(paint.alpha)
    }
}
