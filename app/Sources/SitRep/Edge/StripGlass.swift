import AppKit
import SitRepEdge
import SitRepPanel
import SwiftUI

/// The strip in Liquid Glass, from macOS 26: the strip and its tabs one glass, in the very outline the black is drawn
/// in, the top end's curve, the flares and the dents and all, rebuilt from the model each frame, through the edge's
/// mirror; the marks and the words over it in the glass's own vibrant label colours, so they read over any wallpaper,
/// light or dark. The rings keep their state colours, needs you Claude's orange. Takes no clicks itself.
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

    func show(_ scene: StripScene) {
        self.scene.shown = scene
        self.scene.height = scene.menu + bounds.height
    }
}

/// What the glass draws, as last told.
@available(macOS 26, *)
@MainActor
@Observable
final class StripGlassScene {
    var shown: StripScene?
    /// The stage's height: the window's and the menu bar's above it.
    var height = 0.0
}

/// The glass and everything on it, in the window's coordinates, the stage hung from the menu bar the window starts
/// under.
@available(macOS 26, *)
private struct StripGlass: View {
    let scene: StripGlassScene

    var body: some View {
        if let shown = scene.shown {
            let frame = shown.frame
            ZStack(alignment: .topLeading) {
                StripGlassBody(scene: shown, height: scene.height)
                Rectangle()
                    .fill(.separator)
                    .frame(width: 16, height: 1)
                    .position(CGPoint(x: frame.hairline.x, y: frame.hairline.y).applying(shown.mirror))
                    .opacity(frame.hairline.alpha)
                ForEach(frame.marks, id: \.key) { mark in
                    GlassMark(mark: mark).position(shown.centre(mark))
                }
                ForEach(frame.tabs, id: \.id) { tab in
                    GlassTab(tab: tab, scene: shown)
                }
            }
            .frame(width: Strip.depth, height: scene.height, alignment: .topLeading)
            .offset(y: -shown.menu)
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
    let scene: StripScene
    let height: Double

    var body: some View {
        let frame = scene.frame, tabs = frame.tabs.filter { $0.alpha >= Self.whole }
        ZStack(alignment: .topLeading) {
            ForEach(Self.fading(frame), id: \.id) { piece in
                glass(piece.outline).opacity(piece.alpha)
            }
            glass(Self.outline([frame.strip] + tabs.map(\.outline)))
        }
    }

    /// Thick glass in an outline in the stage's coordinates, through the mirror.
    private func glass(_ outline: CGPath) -> some View {
        var mirror = scene.mirror
        let drawn = outline.copy(using: &mirror) ?? outline

        return Color.clear
            .frame(width: Strip.depth, height: height)
            .glassEffect(.regular, in: Outline(path: GlassThickness.thick(drawn, width: Strip.depth)))
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
/// track. Drawn as each frame has it, lift, wash and flash all, with no animation of its own for a frame's update to
/// restart; only a change of look eases, each part on the prototype's timing: the ring, its glow and the letters over
/// 240ms, the pressed fill over 110, and the arc in over 60 as a click's jump starts and out over 240
/// (`StripMarkLayer`).
@available(macOS 26, *)
private struct GlassMark: View {
    let mark: StripFrame.Mark

    private static let size = StripFrame.Mark.size, line = 1.5

    /// What the mark looks like, short of its place, its lift and its arrival: a change of it eases.
    private struct Look: Equatable {
        let look: StripFrame.Mark.Look
        let isJumping: Bool
    }

    var body: some View {
        let showsArc = mark.look == .working || mark.isJumping

        ZStack {
            Circle().fill(fill)
                .animation(.linear(duration: StripMarkLayer.pressEase), value: mark.isJumping)
            ZStack {
                if showsArc {
                    Spinner(
                        track: mark.isJumping ? nil : .quaternaryLabelColor, arc: arc,
                        period: mark.isJumping ? 0.9 : 1.2
                    )
                    .transition(.opacity)
                }
            }
            .animation(.linear(duration: StripMarkLayer.arcFade(jumping: mark.isJumping)), value: showsArc)
            ZStack {
                if let ring {
                    Circle()
                        .strokeBorder(ring, lineWidth: Self.line + 1.1 * mark.flash)
                        .shadow(color: GlassInk.orange.opacity(glow), radius: (9 + 3 * mark.wash + 7 * mark.flash) / 2)
                        .transition(.opacity)
                }
                Text(mark.text)
                    .font(.system(size: 9.5, weight: .semibold))
                    .kerning(0.095)
                    .foregroundStyle(letters)
            }
            .animation(
                .linear(duration: StripMarkLayer.lookEase), value: Look(look: mark.look, isJumping: mark.isJumping)
            )
        }
        .frame(width: Self.size, height: Self.size)
        .scaleEffect(mark.scale)
        .opacity(mark.alpha)
    }

    private var isNeeds: Bool { [.needs, .away, .needsCount].contains(mark.look) }

    private var fill: AnyShapeStyle {
        if mark.wash > 0 {
            return AnyShapeStyle(GlassInk.orange.opacity(0.2 * mark.wash))
        }
        if mark.isJumping {
            return AnyShapeStyle(.primary.opacity(0.14))
        }
        return AnyShapeStyle(.primary.opacity(0.08 * mark.lift))
    }

    private var ring: AnyShapeStyle? {
        if mark.isJumping {
            return AnyShapeStyle(.quaternary)
        }
        switch mark.look {
        case .needs, .away, .needsCount:
            let flashed = LiveLight.orange.mix(StripMarkLayer.flashed, mark.flash)

            return AnyShapeStyle(Color(cgColor: EdgeStyle.color(flashed)))
        case .turn: return AnyShapeStyle(.primary)
        case .working: return nil
        case .count: return AnyShapeStyle(.tertiary)
        }
    }

    private var glow: Double {
        isNeeds && !mark.isJumping ? 0.45 + 0.2 * mark.wash + 0.3 * mark.flash : 0
    }

    private var arc: NSColor {
        guard mark.isJumping else {
            return .secondaryLabelColor
        }

        return mark.look == .needs ? GlassInk.orangeArc : mark.look == .turn ? .labelColor : .secondaryLabelColor
    }

    private var letters: AnyShapeStyle {
        switch mark.look {
        case .needs, .turn, .needsCount: AnyShapeStyle(.primary)
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
    let scene: StripScene

    var body: some View {
        let box = scene.box(tab), hover = tab.isLive ? scene.hoverRow : nil
        ZStack(alignment: .topLeading) {
            ForEach(tab.words, id: \.id) { words in
                let frame = scene.frame(words, in: tab)
                Group {
                    switch words.content {
                    case let .row(session):
                        GlassRow(session: session, size: frame.size, pressed: words.isPressed, scene: scene)
                    case let .rows(sessions):
                        GlassRows(
                            sessions: sessions, width: frame.width, lit: words.pressedRow ?? hover,
                            pressed: words.pressedRow != nil
                        )
                        .offset(y: -words.scroll)
                    case .idle: GlassIdle(size: frame.size, note: scene.note)
                    }
                }
                .frame(width: frame.width, height: frame.height, alignment: .topLeading)
                .clipped()
                .offset(x: frame.minX, y: frame.minY + words.dy)
                .opacity(words.alpha)
            }
        }
        .frame(width: box.width, height: box.height, alignment: .topLeading)
        .clipShape(Outline(path: Path(scene.clip(tab))))
        .opacity(tab.alpha)
        .position(x: box.midX, y: box.midY)
    }
}

/// A session's row: its title, the line under it and its time, laid out as the black's are.
@available(macOS 26, *)
private struct GlassRow: View {
    let session: Session
    let size: CGSize
    let pressed: Bool
    let scene: StripScene

    var body: some View {
        let at = StripRowLayout(session, note: scene.note, in: size, now: scene.now)
        ZStack(alignment: .topLeading) {
            title(in: at.title)
            Text(session.sub)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .placed(in: at.sub)
            if pressed {
                Spinner(track: .quaternaryLabelColor, arc: .labelColor, period: 1)
                    .placed(in: at.spinner)
            } else {
                Text(scene.note.age(session, at: scene.now))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .placed(in: at.ageBox, alignment: .trailing)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .scaleEffect(pressed ? 0.985 : 1, anchor: UnitPoint(x: scene.stripSide, y: 0.5))
        .animation(.easeOut(duration: 0.14), value: pressed)
    }

    @ViewBuilder private func title(in box: CGRect) -> some View {
        let text = GlassWords.title(session)
        if session.kind == .working, !scene.reducesMotion {
            Shimmering(text: text, width: box.width).placed(in: box)
        } else {
            text.foregroundStyle(session.away ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)).placed(in: box)
        }
    }
}

/// A count's rows: each the session's title and core's second line, lifting under the pointer but for an away ask's.
@available(macOS 26, *)
private struct GlassRows: View {
    let sessions: [Session]
    let width: Double
    let lit: String?
    let pressed: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { i, session in
                let at = StripRowsLayout(i, width: width), isLit = lit == session.id && !session.away
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: StripRowsLayout.radius)
                        .fill(.primary.opacity(isLit ? (pressed ? 0.14 : 0.08) : 0))
                    GlassWords.rowTitle(session).placed(in: at.title)
                    Text(session.sub).font(.system(size: 11)).foregroundStyle(.secondary).placed(in: at.sub)
                }
                .frame(width: at.box.width, height: at.box.height, alignment: .topLeading)
                .scaleEffect(isLit && pressed ? 0.985 : 1)
                .offset(x: at.box.minX, y: at.box.minY)
                .animation(.easeOut(duration: 0.11), value: lit)
            }
        }
    }
}

/// The notch at rest's tab on glass: nothing running, or what the board waits on, in the secondary label colour, and
/// nothing to click.
@available(macOS 26, *)
private struct GlassIdle: View {
    let size: CGSize
    let note: StripNote

    var body: some View {
        let at = StripRowLayout.idle(in: size)
        ZStack(alignment: .topLeading) {
            Text(note.idle)
                .font(.system(size: 14, weight: .medium))
                .kerning(-0.14)
                .foregroundStyle(.secondary)
                .placed(in: at.title)
            Text(note.idleLine2)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .placed(in: at.sub)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// A tab's titles on glass, set as the black's are.
@available(macOS 26, *)
private enum GlassWords {
    /// A row's title, its subject in code type and its "+2".
    static func title(_ s: Session) -> Text {
        let size = 14.0
        let text = Text(s.title)
            .font(.system(size: size, weight: s.kind == .needs ? .semibold : .medium))
            .kerning(-0.14)

        return text + subject(s) + more(s, size: size)
    }

    /// One of the count's rows' titles: your turn and needs you in the primary label colour, the rest dimmer.
    static func rowTitle(_ s: Session) -> some View {
        let size = 13.0
        let text = Text(s.title).font(.system(size: size, weight: s.kind == .needs ? .semibold : .medium))
        let ink: AnyShapeStyle = s.away ? AnyShapeStyle(.tertiary)
            : s.kind == .working ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)

        return (text + subject(s) + more(s, size: size)).foregroundStyle(ink)
    }

    private static func subject(_ s: Session) -> Text {
        Text(s.code ?? "").font(.system(size: 13, weight: .medium, design: .monospaced))
    }

    private static func more(_ s: Session, size: Double) -> Text {
        guard let more = s.more else {
            return Text("")
        }

        return Text("  \(more)").font(.system(size: size, weight: .medium)).foregroundStyle(.tertiary)
    }
}
