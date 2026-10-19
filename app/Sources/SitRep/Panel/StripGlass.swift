import AppKit
import SitRepPanel
import SwiftUI

/// The strip in Liquid Glass, from macOS 26: the strip and its tabs one glass, in the very outline the black is drawn
/// in, the top end's curve, the flares and the dents and all, rebuilt from the model each frame; the marks and the
/// words over it in the glass's own vibrant label colours, so they read over any wallpaper, light or dark. The rings
/// keep their state colours, needs you Claude's orange. The view is SwiftUI's, hosted, and takes no clicks itself.
@available(macOS 26, *)
@MainActor
final class StripGlassView: NSView, StripDrawing {
    private let scene = StripGlassScene()

    init() {
        super.init(frame: .zero)

        let host = NSHostingView(rootView: StripGlass(scene: scene))
        host.sizingOptions = []
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        addSubview(host)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    func place(menu: Double, height: Double) {
        scene.menu = menu
        scene.height = height
    }

    func show(_ frame: StripFrame, hoverRow: String?) {
        scene.frame = frame
        scene.hoverRow = hoverRow
    }
}

/// What the glass draws, as last told.
@available(macOS 26, *)
@MainActor
@Observable
final class StripGlassScene {
    var frame: StripFrame?
    var menu = 0.0
    var height = 0.0
    var hoverRow: String?
}

/// The glass and everything on it, in the stage's coordinates, moved up by the menu bar the window starts under.
@available(macOS 26, *)
struct StripGlass: View {
    let scene: StripGlassScene

    var body: some View {
        if let frame = scene.frame {
            ZStack(alignment: .topLeading) {
                StripGlassBody(frame: frame, height: scene.height)
                Rectangle()
                    .fill(.separator)
                    .frame(width: 16, height: 1)
                    .position(x: frame.hairline.x, y: frame.hairline.y)
                    .opacity(frame.hairline.alpha)
                ForEach(frame.marks, id: \.key) { mark in
                    GlassMark(mark: mark).position(mark.centre)
                }
                ForEach(frame.tabs, id: \.id) { tab in
                    GlassTab(tab: tab, hoverRow: tab.isLive ? scene.hoverRow : nil)
                }
            }
            .frame(width: Strip.depth, height: scene.height, alignment: .topLeading)
            .offset(y: -scene.menu)
            // the window is shorter than the stage by the menu bar: the stage hangs from its top, not centred in it
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

/// The glass itself: the strip and its tabs one glass, in the black's outline. Liquid Glass looks thin or thick by its
/// shape's size alone, and the strip with a tab out is wide enough to be thick, while the strip alone is narrow enough
/// to be thin: so every piece is thick, the strip from rest, and nothing about it changes as a tab pours or draws back.
@available(macOS 26, *)
private struct StripGlassBody: View {
    let frame: StripFrame
    let height: Double

    var body: some View {
        let tabs = frame.tabs.filter { $0.alpha >= Self.whole }
        ZStack(alignment: .topLeading) {
            ForEach(Self.fading(frame), id: \.id) { piece in
                glass(piece.outline).opacity(piece.alpha)
            }
            glass(Self.outline([frame.strip] + tabs.map(\.outline)))
        }
    }

    /// Thick glass in an outline in the stage's coordinates.
    private func glass(_ outline: CGPath) -> some View {
        Color.clear
            .frame(width: Strip.depth, height: height)
            .glassEffect(.regular, in: Outline(path: GlassThickness.thick(outline, width: Strip.depth)))
    }

    /// Outlines as one: drawn the same way round, they make one shape where they meet.
    private static func outline(_ outlines: [CGPath]) -> CGPath {
        let path = CGMutablePath()
        outlines.forEach { path.addPath($0) }
        return path
    }

    /// Under reduced motion, what fades: a tab coming or going, and the old black cross-fading from where a tab was;
    /// each its own glass, seen through to the extent the black would be.
    private static func fading(_ frame: StripFrame) -> [(id: Int, outline: CGPath, alpha: Double)] {
        let tabs = frame.tabs.filter { $0.alpha < Self.whole }.map { (id: $0.id, outline: $0.outline, alpha: $0.alpha) }
        let old = frame.fading.map { [(id: -1, outline: $0.outline, alpha: $0.alpha)] } ?? []
        return old + tabs
    }

    private static let whole = 0.999
}

// MARK: The marks

/// A mark on glass: its letters in the glass's label colours, the ring in its state's colour, needs you orange with
/// its glow, your turn the label colour so it reads on light glass as on dark; working, the arc turning round a faint
/// track.
@available(macOS 26, *)
private struct GlassMark: View {
    let mark: StripFrame.Mark

    private static let size = StripFrame.Mark.size, line = 1.5

    var body: some View {
        ZStack {
            Circle().fill(fill)
            if mark.look == .working || mark.isJumping {
                Spinner(
                    track: mark.isJumping ? nil : AnyShapeStyle(.quaternary), arc: arc,
                    period: mark.isJumping ? 0.9 : 1.2, line: Self.line
                )
                .id(mark.isJumping)
            }
            if let ring {
                Circle()
                    .strokeBorder(ring, lineWidth: Self.line + 1.1 * mark.flash)
                    .shadow(color: GlassInk.orange.opacity(glow), radius: (9 + 3 * mark.wash + 7 * mark.flash) / 2)
            }
            Text(mark.text)
                .font(.system(size: 9.5, weight: .semibold))
                .kerning(0.095)
                .foregroundStyle(letters)
        }
        .frame(width: Self.size, height: Self.size)
        .scaleEffect(mark.scale)
        .opacity(mark.alpha)
        .animation(.easeOut(duration: 0.24), value: mark.look)
        .animation(.easeOut(duration: 0.11), value: mark.isLifted)
    }

    private var isNeeds: Bool { mark.look == .needs || mark.look == .away }

    private var fill: AnyShapeStyle {
        if mark.wash > 0 {
            return AnyShapeStyle(GlassInk.orange.opacity(0.2 * mark.wash))
        }
        if mark.isJumping {
            return AnyShapeStyle(.primary.opacity(0.14))
        }
        return mark.isLifted ? AnyShapeStyle(.primary.opacity(0.08)) : AnyShapeStyle(.clear)
    }

    private var ring: AnyShapeStyle? {
        if mark.isJumping {
            return AnyShapeStyle(.quaternary)
        }
        switch mark.look {
        case .needs, .away: return AnyShapeStyle(Glass.flashing(mark.flash))
        case .turn: return AnyShapeStyle(.primary)
        case .working: return nil
        case .count: return AnyShapeStyle(.tertiary)
        }
    }

    private var glow: Double {
        isNeeds && !mark.isJumping ? 0.45 + 0.2 * mark.wash + 0.3 * mark.flash : 0
    }

    private var arc: AnyShapeStyle {
        guard mark.isJumping else {
            return AnyShapeStyle(.secondary)
        }

        return mark.look == .needs ? AnyShapeStyle(GlassInk.orange) : mark.look == .turn
            ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
    }

    private var letters: AnyShapeStyle {
        switch mark.look {
        case .needs, .turn: AnyShapeStyle(.primary)
        case .away: AnyShapeStyle(.tertiary)
        case .working, .count: AnyShapeStyle(.secondary)
        }
    }
}

// MARK: The tabs' words

/// A tab's words on its glass, clipped to its body as it pours, each of them coming in or going out.
@available(macOS 26, *)
private struct GlassTab: View {
    let tab: StripFrame.Tab
    let hoverRow: String?

    var body: some View {
        let box = tab.box
        ZStack(alignment: .topLeading) {
            ForEach(tab.words, id: \.id) { words in
                Group {
                    switch words.content {
                    case let .row(session): GlassRow(session: session, size: words.frame.size, pressed: words.isPressed)
                    case let .rows(sessions):
                        GlassRows(sessions: sessions, width: words.frame.width, lit: words.pressedRow ?? hoverRow,
                                  pressed: words.pressedRow != nil)
                    }
                }
                .frame(width: words.frame.width, height: words.frame.height, alignment: .topLeading)
                .clipped()
                .offset(x: words.frame.minX, y: words.frame.minY + words.dy)
                .opacity(words.alpha)
            }
        }
        .frame(width: box.width, height: box.height, alignment: .topLeading)
        .clipShape(FrontRounded(
            rect: tab.clip.offsetBy(dx: -box.minX, dy: -box.minY), top: tab.radius, bottom: tab.radius
        ))
        .opacity(tab.alpha)
        .position(x: box.midX, y: box.midY)
    }
}

/// A session's row: its title, the line under it and its age, laid out as the black's are.
@available(macOS 26, *)
private struct GlassRow: View {
    let session: StripSession
    let size: CGSize
    let pressed: Bool

    var body: some View {
        let at = StripRowLayout(session, in: size, now: StripWordsLayer.now)
        ZStack(alignment: .topLeading) {
            title(in: at.title)
            Text(session.line2)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .placed(in: at.sub)
            if pressed {
                Spinner(track: AnyShapeStyle(.quaternary), arc: AnyShapeStyle(.primary), period: 1, line: 1.5)
                    .placed(in: at.spinner)
            } else {
                Text(Session.ageText(StripWordsLayer.now - session.since))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .placed(in: at.age, alignment: .trailing)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .scaleEffect(pressed ? 0.985 : 1, anchor: .leading)
        .animation(.easeOut(duration: 0.14), value: pressed)
    }

    @ViewBuilder private func title(in box: CGRect) -> some View {
        let text = Glass.title(session)
        if session.kind == .working {
            Shimmering(text: text, width: box.width).placed(in: box)
        } else {
            text.foregroundStyle(session.away ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)).placed(in: box)
        }
    }
}

/// The count's rows: each the session's title and its project and work, lifting under the pointer.
@available(macOS 26, *)
private struct GlassRows: View {
    let sessions: [StripSession]
    let width: Double
    let lit: String?
    let pressed: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { i, session in
                let at = StripRowsLayout(i, width: width)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.primary.opacity(lit == session.id ? (pressed ? 0.14 : 0.08) : 0))
                    Glass.rowTitle(session).placed(in: at.title)
                    Text(session.sub).font(.system(size: 11)).foregroundStyle(.secondary).placed(in: at.sub)
                }
                .frame(width: at.box.width, height: at.box.height, alignment: .topLeading)
                .scaleEffect(lit == session.id && pressed ? 0.985 : 1)
                .offset(x: at.box.minX, y: at.box.minY)
                .animation(.easeOut(duration: 0.11), value: lit)
            }
        }
    }
}

// MARK: The words, on glass

@available(macOS 26, *)
private enum Glass {

    /// A new mark's ring, flashing from the orange toward its brightest.
    static func flashing(_ flash: Double) -> Color {
        Color(cgColor: PanelStyle.color(LiveLight.orange.mix(LiveLight.RGB(r: 255, g: 160, b: 120), flash)))
    }

    /// A row's title, its command in code type and its "+2", as the black's are set.
    static func title(_ s: StripSession) -> Text {
        var text = Text(s.title)
            .font(.system(size: 14, weight: s.kind == .needs ? .semibold : .medium))
            .kerning(-0.14)
        if let code = s.code {
            text = text + Text(code).font(.system(size: 13, weight: .medium, design: .monospaced))
        }
        if let more = s.more {
            text = text + Text("  +\(more)").font(.system(size: 14, weight: .medium)).foregroundStyle(.tertiary)
        }
        return text
    }

    /// One of the count's rows' titles: your turn in the primary label colour, the rest in the secondary.
    static func rowTitle(_ s: StripSession) -> some View {
        var text = Text(s.title).font(.system(size: 13, weight: .medium))
        if let code = s.code {
            text = text + Text(code).font(.system(size: 13, weight: .medium, design: .monospaced))
        }
        return text.foregroundStyle(s.kind == .turn ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
    }
}
