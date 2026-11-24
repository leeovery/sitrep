import AppKit
import SitRepEdge
import SitRepPanel
import SwiftUI

/// The asks panel in glass (DESIGN, "Answering from the panel", "Black and Glass"): the panel's glass, plain, its
/// hairline the separator's and its shadows a submenu's, as the black's; its words in the glass's label colours, as
/// the glass rows' are; its rows, keycaps and outlines the black's shapes, filled in the glass's tints; its current
/// page dot Claude's orange, and the answer held white with ink. Laid out as the black's, in its own frame, its words
/// over the glass beside it rather than in it, as the panel's rows are, so the glass never tints them for what is under
/// it.
@available(macOS 26, *)
struct GlassAsksPanel: View {
    let asks: AsksShown
    /// Whether it opens leftward, from the screen's right edge: its side shadow falls the other way.
    let pointsLeft: Bool
    /// The wall clock, ms: its age's, and the countdown's.
    let now: Double

    var body: some View {
        let size = asks.layout.size, shape = AsksGlassShadows.outline

        ZStack(alignment: .topLeading) {
            AsksGlassShadows(size: size, pointsLeft: pointsLeft)
            Color.clear.glassEffect(.regular, in: shape)
            shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            top
            ask
            ForEach(asks.layout.answers.indices, id: \.self) { answer($0) }
            foot
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// The session's name and its project, and its page dots, the current one orange.
    @ViewBuilder private var top: some View {
        let top = AsksPanelParts.top(asks)

        Text(asks.session.name).font(Font(EdgeStyle.asksName)).foregroundStyle(.primary).placed(in: top.name)
        Text(asks.session.project).font(Font(EdgeStyle.sub)).foregroundStyle(.tertiary).placed(in: top.project)
        ForEach(top.dots.indices, id: \.self) { index in
            let dot = top.dots[index]

            RoundedRectangle(cornerRadius: AsksPanelParts.dotRadius, style: .circular)
                .fill(dot.isCurrent ? AnyShapeStyle(GlassInk.orange) : AnyShapeStyle(.primary.opacity(GlassTint.dot)))
                .frame(width: dot.box.width, height: dot.box.height)
                .offset(x: dot.box.minX, y: dot.box.minY)
        }
    }

    /// The ask's title on the lines the layout left room for, and how long ago it was asked.
    @ViewBuilder private var ask: some View {
        let lines = AsksPanelParts.titleLines(asks, colour: EdgeStyle.ink)

        ForEach(lines.indices, id: \.self) { index in
            let line = lines[index]

            Text(Self.trailingSpaceless(line.text.string))
                .font(Font(EdgeStyle.asksTitle)).kerning(EdgeStyle.asksTitleKern).foregroundStyle(.primary)
                .placed(in: line.box)
        }
        Text(asks.ask.askedText(at: now)).font(Font(EdgeStyle.sub)).foregroundStyle(.tertiary)
            .placed(in: asks.layout.age)
    }

    /// A line as Core Text broke it, which leaves the space it broke at on its end, where SwiftUI would count it.
    private static func trailingSpaceless(_ line: String) -> String {
        String(line.reversed().drop { $0.isWhitespace }.reversed())
    }

    /// An answer's row: filled and bordered, lifted under the pointer, white while it is the answer held; outlined, for
    /// the one row that answers in Claude. Its keycap holds its number, or ↗, or held, a check in its place; then its
    /// label, and "recommended" at its end for Claude's pick.
    private func answer(_ index: Int) -> some View {
        let box = asks.layout.answers[index], isHeld = asks.sending.map { $0.row == index } ?? false
        let isLifted = asks.hover == .answer(index) || asks.hover == .inClaude
        let label = AsksPanelParts.label(index, of: asks.ask)
        let at = AsksPanelParts.label(in: box.size, note: label.note)
        let ink = Color(cgColor: EdgeStyle.onWhite)

        return ZStack(alignment: .topLeading) {
            ground(isHeld: isHeld, isLifted: isLifted)
            if isHeld {
                check(ink)
            } else {
                keycap(asks.ask.isInClaude ? "↗" : "\(index + 1)")
            }
            if let note = label.note, let noteBox = at.note {
                Text(note).font(Font(EdgeStyle.asksNote))
                    .foregroundStyle(isHeld ? AnyShapeStyle(ink.opacity(0.5)) : AnyShapeStyle(.tertiary))
                    .placed(in: noteBox)
            }
            Text.tight(label.words, EdgeStyle.asksLabel)
                .foregroundStyle(isHeld ? AnyShapeStyle(ink) : AnyShapeStyle(.primary))
                .placed(in: at.label)
        }
        .frame(width: box.width, height: box.height, alignment: .topLeading)
        .offset(x: box.minX, y: box.minY)
    }

    /// An answer's row's ground: white held; a step stronger lifted; outlined, answering in Claude; else filled, its
    /// border a step over its fill.
    @ViewBuilder private func ground(isHeld: Bool, isLifted: Bool) -> some View {
        let row = RoundedRectangle(cornerRadius: AsksLayout.answerRadius, style: .circular)

        switch (isHeld, isLifted, asks.ask.isInClaude) {
        case (true, _, _):
            row.fill(Color(cgColor: EdgeStyle.ink))
        case (false, true, _):
            row.fill(.primary.opacity(GlassTint.lifted)).overlay(row.strokeBorder(.primary.opacity(GlassTint.press)))
        case (false, false, true):
            row.strokeBorder(.primary.opacity(GlassTint.outline))
        case (false, false, false):
            row.fill(.primary.opacity(GlassTint.press)).overlay(row.strokeBorder(.primary.opacity(GlassTint.hover)))
        }
    }

    /// A keycap, a step over its row, its number or ↗ soft on it.
    private func keycap(_ mark: String) -> some View {
        let cap = AsksLayout.keycap, shape = RoundedRectangle(cornerRadius: AsksLayout.keycapRadius, style: .circular)

        return Text(mark).font(Font(EdgeStyle.asksKeycap)).foregroundStyle(.secondary)
            .frame(width: cap.width, height: cap.height)
            .background(.primary.opacity(GlassTint.hover), in: shape)
            .offset(x: cap.minX, y: cap.minY)
    }

    /// The held answer's check, in ink, in its keycap's place.
    private func check(_ ink: Color) -> some View {
        let check = AsksPanelParts.check()

        return Outline(path: Path(check.path))
            .stroke(ink, style: .rounded(AsksPanelParts.checkWidth))
            .frame(width: check.box.width, height: check.box.height)
            .offset(x: check.box.minX, y: check.box.minY)
    }

    /// The foot: Ignore, Snooze ▾ and, for an ask answered here, Open in Claude; while its ask's answer is held, the
    /// sending line in its place.
    @ViewBuilder private var foot: some View {
        let layout = asks.layout

        if let sending = asks.sending {
            sendingLine(sending)
        } else {
            footWords(AsksLayout.ignoreWords, in: layout.ignore, lit: asks.hover == .ignore)
            footWords(AsksLayout.snoozeWords, in: layout.snooze, lit: asks.hover == .snooze)
            snoozeChevron(in: layout.snooze, lit: asks.hover == .snooze)
            if let open = layout.open {
                openPill(open, lit: asks.hover == .open)
            }
        }
    }

    /// A foot button's words, soft, the primary under the pointer.
    private func footWords(_ words: String, in box: CGRect, lit: Bool) -> some View {
        Text(words).font(Font(EdgeStyle.asksFoot)).foregroundStyle(lit ? .primary : .secondary)
            .placed(in: AsksPanelParts.footWords(in: box))
    }

    private func snoozeChevron(in box: CGRect, lit: Bool) -> some View {
        let chevron = AsksPanelParts.snoozeChevron(in: box)

        return Outline(path: Path(chevron.path))
            .stroke(lit ? .primary : .secondary, style: .rounded(AsksPanelParts.strokeWidth))
            .frame(width: chevron.box.width, height: chevron.box.height)
            .offset(x: chevron.box.minX, y: chevron.box.minY)
    }

    /// Open in Claude, outlined, its ↗ soft after it; filled under the pointer.
    private func openPill(_ box: CGRect, lit: Bool) -> some View {
        let at = AsksPanelParts.openWords(in: box.size)

        return pill(box, lit: lit) {
            Text(AsksLayout.openWords).font(Font(EdgeStyle.asksFoot)).foregroundStyle(.primary).placed(in: at.words)
            Text(AsksLayout.openMark).font(Font(EdgeStyle.asksFoot)).foregroundStyle(.secondary).placed(in: at.mark)
        }
    }

    /// An outlined pill, filled under the pointer, what it holds in its own frame.
    private func pill(_ box: CGRect, lit: Bool, @ViewBuilder holding: () -> some View) -> some View {
        let shape = RoundedRectangle(cornerRadius: AsksLayout.pillRadius, style: .circular)

        return ZStack(alignment: .topLeading) {
            shape.fill(.primary.opacity(lit ? GlassTint.press : 0))
            shape.strokeBorder(.primary.opacity(GlassTint.outline), lineWidth: 1)
            holding()
        }
        .frame(width: box.width, height: box.height, alignment: .topLeading)
        .offset(x: box.minX, y: box.minY)
    }

    /// The sending line: the ring counting down the two seconds, "Sending" and the answer's words, or "Ignoring", and
    /// Undo.
    @ViewBuilder private func sendingLine(_ sending: Sending) -> some View {
        let layout = asks.layout, ring = layout.countdown
        let lead = Text(AsksPanelParts.sendingLead(sending)).font(Font(EdgeStyle.asksFootPlain))
            .foregroundStyle(.secondary)
        let words = Text(sending.words ?? "").font(Font(EdgeStyle.asksFoot)).foregroundStyle(.primary)

        GlassCountdown(sending: sending, now: now)
            .frame(width: ring.width, height: ring.height)
            .offset(x: ring.minX, y: ring.minY)
        Text("\(lead)\(words)").placed(in: layout.sending)
        pill(layout.undo, lit: asks.hover == .undo) {
            Text(AsksLayout.undoWords).font(Font(EdgeStyle.asksFoot)).foregroundStyle(.primary)
                .placed(in: AsksPanelParts.undoWords(in: layout.undo.size))
        }
    }
}

extension StrokeStyle {
    /// A stroke this wide, round at its caps and joins, as the black's strokes are.
    fileprivate static func rounded(_ width: Double) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }
}

/// The asks panel's shadows on glass, cast by a black of its shape, as the black's, with the black and every shadow
/// inside its outline cut away, so the glass shows what is under it untouched.
@available(macOS 26, *)
private struct AsksGlassShadows: View {
    let size: CGSize
    let pointsLeft: Bool

    var body: some View {
        let casts = AsksShadow.casts(pointsLeft: pointsLeft)

        ZStack {
            ForEach(casts.indices, id: \.self) { index in
                let cast = casts[index]

                Self.outline.fill(.black)
                    .shadow(
                        color: .black.opacity(cast.opacity), radius: cast.radius, x: cast.offset.width,
                        y: cast.offset.height
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .mask { Outline(path: outside).fill(style: FillStyle(eoFill: true)) }
    }

    /// The asks panel's outline, its corners circular, as the black's and as a click finds it (`AsksShown.contains`).
    static let outline = RoundedRectangle(cornerRadius: AsksLayout.radius, style: .circular)

    /// Everything a shadow reaches but the asks panel's outline.
    private var outside: Path {
        let bounds = CGRect(origin: .zero, size: size)
        var path = Path(bounds.insetBy(dx: -Self.reach, dy: -Self.reach))

        path.addPath(Self.outline.path(in: bounds))
        return path
    }

    /// Past the farthest shadow: 14 down and blurred 18 each way.
    private static let reach = 60.0
}

/// A Needs you row's arrow on glass (DESIGN, "The row's arrow"): unlit, its chevron in the secondary on the row's lift;
/// lit, a step stronger than the lift, its chevron in the primary; pointing away from the screen's edge.
@available(macOS 26, *)
struct GlassRowArrow: View {
    let arrow: SessionRow.Arrow

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: RowArrow.radius, style: .circular)
                .fill(.primary.opacity(arrow.isLit ? GlassTint.press : 0))
            Outline(path: Path(RowArrow.chevron(pointsLeft: arrow.pointsLeft)))
                .stroke(arrow.isLit ? .primary : .secondary, style: .rounded(AsksPanelParts.strokeWidth))
        }
        .frame(width: RowArrow.size.width, height: RowArrow.size.height)
    }
}

/// The countdown on glass: the black's ring, its track in the quaternary and its arc in the secondary, as the glass's
/// spinner's, run down in the render server from what is left of the held answer's two seconds.
struct GlassCountdown: NSViewRepresentable {
    let sending: Sending
    /// The wall clock, ms.
    let now: Double

    func makeNSView(context _: Context) -> CountdownView { CountdownView() }

    func updateNSView(_ view: CountdownView, context _: Context) {
        view.show(sending, at: now)
    }
}

/// The countdown's view: the ring in its layer, counting each held answer once, from when it is first shown.
/// Decoration: a click passes through it.
@MainActor
final class CountdownView: NSView {
    private let ring = CountdownRing(in: CGRect(x: 0, y: 0, width: AsksLayout.ring, height: AsksLayout.ring))
    private var counting: Sending?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(ring.track)
        layer?.addSublayer(ring.arc)
        paint()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    override func hitTest(_: NSPoint) -> NSView? { nil }

    /// Internal only for the tests, which read it.
    var arc: CAShapeLayer { ring.arc }

    func show(_ sending: Sending, at now: Double) {
        guard sending != counting else {
            return
        }

        counting = sending
        still { ring.count(sending, at: now) }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        paint()
    }

    /// Back in a window, its count runs on from the wall clock if the window took it.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil, let counting, !ring.isCounting {
            still { ring.count(counting, at: Displays.wallNow) }
        }
    }

    private func paint() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            still {
                ring.track.strokeColor = NSColor.quaternaryLabelColor.cgColor
                ring.arc.strokeColor = NSColor.secondaryLabelColor.cgColor
            }
        }
    }
}
