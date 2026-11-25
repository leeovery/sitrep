import AppKit
import SitRepEdge
import SitRepPanel
import SwiftUI

/// The asks panel in glass (DESIGN, "Answering from the panel", "Black and Glass"): the panel's glass, plain, its
/// hairline the separator's and its shadows a submenu's, as the black's; its words in the glass's label colours, as
/// the glass rows' are; its rows and outlines the black's shapes, filled in the glass's tints, Claude's pick in its
/// lilac (`GlassInk.pick`); its current page dot Claude's orange, and the answer held in the primary made opaque, its
/// words in the other. Laid out as the black's, in its own frame, its words over the glass beside it rather than in
/// it, as the panel's rows are, so the glass never tints them for what is under it. Drawn again only as what it shows
/// changes: never for the clock alone.
@available(macOS 26, *)
struct GlassAsksPanel: View, Equatable {
    let asks: AsksShown
    /// Whether it opens leftward, from the screen's right edge: its side shadow falls the other way.
    let pointsLeft: Bool
    /// How long ago its ask was asked, as worded at the frame.
    let asked: String
    /// The wall clock at the frame, ms, which the countdown starts from as an answer is first held, and runs down from
    /// on its own: no reason to draw it again.
    let now: Double

    nonisolated static func == (one: Self, other: Self) -> Bool {
        one.asks.unplaced == other.asks.unplaced && one.pointsLeft == other.pointsLeft && one.asked == other.asked
    }

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

            Text(line.text.string)
                .font(Font(EdgeStyle.asksTitle)).kerning(EdgeStyle.asksTitleKern).foregroundStyle(.primary)
                .placed(in: line.box)
        }
        Text(asked).font(Font(EdgeStyle.sub)).foregroundStyle(.tertiary)
            .placed(in: asks.layout.age)
    }

    /// An answer's row, as the black's (Paper's board H3): its words alone on up to two lines, Claude's pick in its
    /// lilac with "Recommended" after its words, any other in the glass's tints; each a step stronger under the
    /// pointer; the primary made opaque while it is the answer held, its words in the other and a check at its end.
    private func answer(_ index: Int) -> some View {
        let box = asks.layout.answers[index], shows = AsksPanelParts.answerRow(index, of: asks)
        let lines = AsksPanelParts.answerLines(index, of: asks)

        return ZStack(alignment: .topLeading) {
            ground(shows)
            ForEach(lines.indices, id: \.self) { line in
                answerLine(lines[line].line, isHeld: shows.isHeld).placed(in: lines[line].box)
            }
            if shows.isHeld {
                check(in: box.size)
            }
        }
        .frame(width: box.width, height: box.height, alignment: .topLeading)
        .offset(x: box.minX, y: box.minY)
    }

    /// An answer's row's ground: the primary held; Claude's pick filled and bordered in its lilac; any other in the
    /// primary's tints, its border a step over its fill; each a step stronger lifted.
    @ViewBuilder private func ground(_ shows: AsksPanelParts.AnswerRow) -> some View {
        let row = RoundedRectangle(cornerRadius: AsksLayout.answerRadius, style: .circular)
        let isLifted = shows.ground == .lifted

        switch (shows.ground, shows.isPick) {
        case (.held, _):
            row.fill(GlassInk.held)
        case (_, true):
            row.fill(GlassInk.pick.opacity(isLifted ? GlassTint.Pick.lifted : GlassTint.Pick.fill))
                .overlay(row.strokeBorder(
                    GlassInk.pick.opacity(isLifted ? GlassTint.Pick.liftedBorder : GlassTint.Pick.border)
                ))
        case (_, false):
            row.fill(.primary.opacity(isLifted ? GlassTint.lifted : GlassTint.press))
                .overlay(row.strokeBorder(.primary.opacity(isLifted ? GlassTint.press : GlassTint.hover)))
        }
    }

    /// One line of an answer's words, the primary, or the held row's ink, and its pick's tag after them in its lilac,
    /// or in the ink at half on the held row; a tag on a line of its own alone, set as the black sets it.
    private func answerLine(_ line: AsksPanelParts.AnswerLine, isHeld: Bool) -> Text {
        let ink = isHeld ? AnyShapeStyle(GlassInk.onHeld) : AnyShapeStyle(.primary)
        let words = Text.tight(line.words, EdgeStyle.asksLabel).foregroundStyle(ink)

        guard let tag = line.tag else {
            return words
        }

        let tagInk = isHeld ? AnyShapeStyle(GlassInk.onHeld.opacity(0.5)) : AnyShapeStyle(GlassInk.pickTag)
        let tagged = Text(tag).font(Font(EdgeStyle.asksNote)).foregroundStyle(tagInk)

        return line.words.isEmpty ? tagged : Text("\(words)\(tagged)")
    }

    /// The held answer's check, in the held row's ink, at its row's trailing end.
    private func check(in row: CGSize) -> some View {
        let check = AsksPanelParts.check(in: row)

        return Outline(path: Path(check.path))
            .stroke(GlassInk.onHeld, style: .rounded(AsksPanelParts.checkWidth))
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
            if let snooze = layout.snooze {
                footWords(AsksLayout.snoozeWords, in: snooze, lit: asks.hover == .snooze)
                snoozeChevron(in: snooze, lit: asks.hover == .snooze)
            }
            openPill(layout.open, lit: asks.hover == .open)
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

/// The asks panel's shadows on glass, cast by a black of its shape, as the black's, with the black and every shadow
/// inside its outline cut away, so the glass shows what is under it untouched. The black stands half a point inside the
/// outline, so the cut's soft edge leaves none of it as a dark rim round the glass.
@available(macOS 26, *)
private struct AsksGlassShadows: View {
    let size: CGSize
    let pointsLeft: Bool

    var body: some View {
        let casts = AsksShadow.casts(pointsLeft: pointsLeft)

        ZStack {
            ForEach(casts.indices, id: \.self) { index in
                let cast = casts[index]

                Self.outline.inset(by: 0.5).fill(.black)
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

/// The countdown on glass: the black's ring, its track in the quaternary, as the glass's spinner's is, and its arc in
/// the secondary, as the black's arc is soft, run down in the render server from what is left of the held answer's two
/// seconds.
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
