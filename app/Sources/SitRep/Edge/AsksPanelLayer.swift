import AppKit
import SitRepEdge
import SitRepPanel

/// The asks panel in black (Paper's boards F and H3; DESIGN, "Answering from the panel"): the panel's black, 372 wide,
/// its corners 24, a hairline round it and a submenu's shadow, over the list's front; its top line, the session's name
/// and project and its page dots; the ask's title and its age; its answers' rows, Claude's pick first in lilac, none
/// for an ask Lee answers in Claude; and its foot, Ignore, Snooze ▾ and Open in Claude, or, while an answer of its ask
/// is held, the sending line, its ring counting down the two seconds and Undo. It appears at once, as a Mac submenu
/// does, and is drawn again only as what it shows changes; a frame moves it with its row.
@MainActor
final class AsksPanelLayer {
    let layer = CALayer()

    private var shown: AsksShown?
    /// What it was last drawn from beyond `shown`: the edge it opens from, and its ask's age as worded.
    private var drawnFor: (pointsLeft: Bool, asked: String)?
    private var scale: CGFloat = 1

    init() {
        layer.isHidden = true
    }

    /// The asks panel as the frame shows it, through the edge's mirror, its age and countdown as of `now` on the wall
    /// clock; hidden while it is closed. It shows, moves and closes at once, as a submenu does.
    func show(_ asks: AsksShown?, mirror: CGAffineTransform, now: Double) {
        still { place(asks, mirror: mirror, now: now) }
    }

    private func place(_ asks: AsksShown?, mirror: CGAffineTransform, now: Double) {
        guard let asks else {
            layer.isHidden = true
            shown = nil
            return
        }

        let pointsLeft = mirror.a < 0, asked = asks.ask.askedText(at: now)

        layer.isHidden = false
        layer.frame = asks.frame.applying(mirror)
        if asks.unplaced != shown?.unplaced || drawnFor?.pointsLeft != pointsLeft || drawnFor?.asked != asked {
            layer.sublayers = Self.parts(of: asks, pointsLeft: pointsLeft, now: now)
            rescale(layer, to: scale)
        }
        shown = asks
        drawnFor = (pointsLeft, asked)
    }

    func rescaled(to scale: CGFloat) {
        self.scale = scale
        rescale(layer, to: scale)
    }

    /// Everything it draws, from the back: its shadows, its black, and over it its words and rows.
    private static func parts(of asks: AsksShown, pointsLeft: Bool, now: Double) -> [CALayer] {
        let size = asks.layout.size

        return Self.shadows(size, pointsLeft: pointsLeft) + [body(size)] + top(asks) + ask(asks, at: now)
            + asks.layout.answers.indices.map { answer($0, of: asks) } + foot(asks, at: now)
    }

    /// Its two shadows (`AsksShadow`), each a black of its shape casting it, under the body.
    private static func shadows(_ size: CGSize, pointsLeft: Bool) -> [CALayer] {
        AsksShadow.casts(pointsLeft: pointsLeft).map { cast in
            let shadow = rounded(CGRect(origin: .zero, size: size), AsksLayout.radius, fill: EdgeStyle.black)

            shadow.shadowPath = CGPath(
                roundedRect: shadow.bounds, cornerWidth: AsksLayout.radius, cornerHeight: AsksLayout.radius,
                transform: nil
            )
            shadow.shadowColor = EdgeStyle.black
            shadow.shadowOpacity = Float(cast.opacity)
            shadow.shadowRadius = cast.radius
            shadow.shadowOffset = cast.offset
            return shadow
        }
    }

    private static func body(_ size: CGSize) -> CALayer {
        let body = rounded(CGRect(origin: .zero, size: size), AsksLayout.radius, fill: EdgeStyle.black)

        body.borderWidth = 1
        body.borderColor = EdgeStyle.asksBorder
        return body
    }

    /// The top line: the session's name and its project faint; and its page dots, the current one orange.
    private static func top(_ asks: AsksShown) -> [CALayer] {
        let top = AsksPanelParts.top(asks)
        let dots = top.dots.map { dot in
            rounded(dot.box, AsksPanelParts.dotRadius, fill: dot.isCurrent ? EdgeStyle.orange : EdgeStyle.dot)
        }

        return [
            TextLine(TextLine.text(asks.session.name, EdgeStyle.asksName, EdgeStyle.ink), in: top.name),
            TextLine(TextLine.text(asks.session.project, EdgeStyle.sub, EdgeStyle.ink3), in: top.project),
        ] + dots
    }

    /// The ask's title, wrapped to its lines, and under it how long ago it was asked.
    private static func ask(_ asks: AsksShown, at now: Double) -> [CALayer] {
        let lines = AsksPanelParts.titleLines(asks, colour: EdgeStyle.ink).map { TextLine($0.text, in: $0.box) }
        let asked = TextLine.text(asks.ask.askedText(at: now), EdgeStyle.sub, EdgeStyle.ink3)

        return lines + [TextLine(asked, in: asks.layout.age)]
    }

    /// An answer's row (Paper's board H3): its words alone, on up to two lines, Claude's pick filled and bordered in
    /// lilac with "Recommended" after its words, any other in the panel's greys; each lighter under the pointer; white
    /// while it is the answer held, its words in ink and a check at its trailing end.
    private static func answer(_ index: Int, of asks: AsksShown) -> CALayer {
        let shows = AsksPanelParts.answerRow(index, of: asks)
        let row = rounded(asks.layout.answers[index], AsksLayout.answerRadius, fill: nil)
        let ground = Self.ground(shows)

        row.borderWidth = 1
        row.backgroundColor = ground.fill
        row.borderColor = ground.border
        for (line, box) in AsksPanelParts.answerLines(index, of: asks) {
            row.addSublayer(Self.line(line, in: box, isHeld: shows.isHeld))
        }
        if shows.isHeld {
            row.addSublayer(check(in: row.bounds.size))
        }
        return row
    }

    /// An answer's row's fill and border.
    private static func ground(_ shows: AsksPanelParts.AnswerRow) -> (fill: CGColor, border: CGColor) {
        switch (shows.ground, shows.isPick) {
        case (.held, _): (EdgeStyle.ink, EdgeStyle.ink)
        case (.lifted, true): (EdgeStyle.pickLifted, EdgeStyle.pickLiftedBorder)
        case (.lifted, false): (EdgeStyle.answerLifted, EdgeStyle.answerLiftedBorder)
        case (.filled, true): (EdgeStyle.pick, EdgeStyle.pickBorder)
        case (.filled, false): (EdgeStyle.answer, EdgeStyle.answerBorder)
        }
    }

    /// One line of an answer's words, white, or ink on the held row, and its pick's tag after them in lilac, or in ink
    /// at half on the held row.
    private static func line(_ line: AsksPanelParts.AnswerLine, in box: CGRect, isHeld: Bool) -> TextLine {
        let text = AsksPanelParts.answerText(line.words, colour: isHeld ? EdgeStyle.onWhite : EdgeStyle.ink)
        let tagColour = isHeld ? EdgeStyle.onWhite.copy(alpha: 0.5) ?? EdgeStyle.onWhite : EdgeStyle.pickTag

        guard let tag = line.tag else {
            return TextLine(text, in: box)
        }

        text.append(TextLine.text(tag, EdgeStyle.asksNote, tagColour))
        return TextLine(text, in: box)
    }

    /// The held answer's check, in ink, at its row's trailing end.
    private static func check(in row: CGSize) -> CALayer {
        let check = AsksPanelParts.check(in: row)

        return stroked(check.path, in: check.box, colour: EdgeStyle.onWhite, width: AsksPanelParts.checkWidth)
    }

    /// The foot: Ignore, Snooze ▾ and, for an ask answered here, Open in Claude; while its ask's answer is held, the
    /// sending line in its place.
    private static func foot(_ asks: AsksShown, at now: Double) -> [CALayer] {
        if let sending = asks.sending {
            return sendingLine(sending, asks, at: now)
        }

        let layout = asks.layout
        let ignore = footWords(AsksLayout.ignoreWords, in: layout.ignore, lit: asks.hover == .ignore)
        let snooze = layout.snooze.map { box in
            [
                footWords(AsksLayout.snoozeWords, in: box, lit: asks.hover == .snooze),
                snoozeChevron(in: box, lit: asks.hover == .snooze),
            ]
        } ?? []

        return [ignore] + snooze + [openPill(layout.open, lit: asks.hover == .open)]
    }

    /// A foot button's words, soft, white under the pointer.
    private static func footWords(_ words: String, in box: CGRect, lit: Bool) -> CALayer {
        TextLine(
            TextLine.text(words, EdgeStyle.asksFoot, lit ? EdgeStyle.ink : EdgeStyle.ink2),
            in: AsksPanelParts.footWords(in: box)
        )
    }

    private static func snoozeChevron(in box: CGRect, lit: Bool) -> CALayer {
        let chevron = AsksPanelParts.snoozeChevron(in: box)

        return stroked(
            chevron.path, in: chevron.box, colour: lit ? EdgeStyle.ink : EdgeStyle.ink2,
            width: AsksPanelParts.strokeWidth
        )
    }

    /// Open in Claude, outlined, its ↗ soft after it; filled under the pointer.
    private static func openPill(_ box: CGRect, lit: Bool) -> CALayer {
        let pill = Self.pill(box, lit: lit), at = AsksPanelParts.openWords(in: box.size)

        pill.addSublayer(TextLine(TextLine.text(AsksLayout.openWords, EdgeStyle.asksFoot, EdgeStyle.ink), in: at.words))
        pill.addSublayer(TextLine(TextLine.text(AsksLayout.openMark, EdgeStyle.asksFoot, EdgeStyle.ink2), in: at.mark))
        return pill
    }

    private static func pill(_ box: CGRect, lit: Bool) -> CALayer {
        let pill = rounded(box, AsksLayout.pillRadius, fill: lit ? EdgeStyle.answer : nil)

        pill.borderWidth = 1
        pill.borderColor = EdgeStyle.outline
        return pill
    }

    /// The sending line: the ring counting down from what is left of the two seconds at `now`, "Sending" and the
    /// answer's words, or "Ignoring", and Undo.
    private static func sendingLine(_ sending: Sending, _ asks: AsksShown, at now: Double) -> [CALayer] {
        let layout = asks.layout, ring = CountdownRing(in: layout.countdown)
        let said = TextLine.text(AsksPanelParts.sendingLead(sending), EdgeStyle.asksFootPlain, EdgeStyle.ink2)
        let undo = pill(layout.undo, lit: asks.hover == .undo)

        sending.words.map { said.append(TextLine.text($0, EdgeStyle.asksFoot, EdgeStyle.ink)) }
        undo.addSublayer(TextLine(
            TextLine.text(AsksLayout.undoWords, EdgeStyle.asksFoot, EdgeStyle.ink),
            in: AsksPanelParts.undoWords(in: layout.undo.size)
        ))
        ring.track.strokeColor = EdgeStyle.track
        ring.arc.strokeColor = EdgeStyle.ink2
        ring.count(sending, at: now)
        return [ring.track, ring.arc, TextLine(said, in: layout.sending), undo]
    }

    private static func rounded(_ box: CGRect, _ radius: Double, fill: CGColor?) -> CALayer {
        let layer = CALayer()

        layer.frame = box
        layer.cornerRadius = radius
        layer.backgroundColor = fill
        return layer
    }

    /// A path stroked in a box, round at its caps and joins, filled with nothing.
    private static func stroked(_ path: CGPath, in box: CGRect, colour: CGColor, width: Double) -> CAShapeLayer {
        let shape = CAShapeLayer()

        shape.frame = box
        shape.path = path
        shape.fillColor = nil
        shape.strokeColor = colour
        shape.lineWidth = width
        shape.lineCap = .round
        shape.lineJoin = .round
        return shape
    }
}
