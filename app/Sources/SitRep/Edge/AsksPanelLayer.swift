import AppKit
import SitRepEdge
import SitRepPanel

/// The asks panel in black (Paper's board F; DESIGN, "Answering from the panel"): the panel's black, 372 wide, its
/// corners 24, a hairline round it and a submenu's shadow, over the list's front; its top line, the session's name and
/// project and its page dots; the ask's title and its age; its answers' rows, numbered, or the one that answers in
/// Claude; and its foot, Ignore, Snooze ▾ and Open in Claude, or, while an answer of its ask is held, the sending
/// line, its ring counting down the two seconds and Undo. It appears at once, as a Mac submenu does, and is drawn again
/// only as what it shows changes; a frame moves it with its row.
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
        if !Self.drawsAlike(asks, shown) || drawnFor?.pointsLeft != pointsLeft || drawnFor?.asked != asked {
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

    /// Whether two showings draw the same, wherever they stand.
    private static func drawsAlike(_ one: AsksShown, _ other: AsksShown?) -> Bool {
        guard let other else {
            return false
        }

        return one.row == other.row && one.session == other.session && one.ask == other.ask && one.page == other.page
            && one.pages == other.pages && one.layout == other.layout && one.sending == other.sending
            && one.hover == other.hover
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

    /// An answer's row: filled and bordered, lifted under the pointer, white while it is the answer held; outlined,
    /// for the one row that answers in Claude. Its keycap holds its number, or ↗, or held, a check in its place; then
    /// its label, and "recommended" at its end for Claude's pick.
    private static func answer(_ index: Int, of asks: AsksShown) -> CALayer {
        let box = asks.layout.answers[index], isHeld = asks.sending.map { $0.row == index } ?? false
        let isLifted = asks.hover == .answer(index) || asks.hover == .inClaude
        let row = rounded(box, AsksLayout.answerRadius, fill: nil)

        row.borderWidth = 1
        switch (isHeld, isLifted, asks.ask.isInClaude) {
        case (true, _, _):
            row.backgroundColor = EdgeStyle.ink
            row.borderColor = EdgeStyle.ink
        case (false, true, _):
            row.backgroundColor = EdgeStyle.answerLifted
            row.borderColor = EdgeStyle.answerLiftedBorder
        case (false, false, true):
            row.borderColor = EdgeStyle.outline
        case (false, false, false):
            row.backgroundColor = EdgeStyle.answer
            row.borderColor = EdgeStyle.answerBorder
        }
        row.addSublayer(isHeld ? check() : keycap(asks.ask.isInClaude ? "↗" : "\(index + 1)"))
        labelled(row, AsksPanelParts.label(index, of: asks.ask), isHeld: isHeld)
        return row
    }

    /// A row's label after its keycap, and its note at its end, the label cut short before it.
    private static func labelled(_ row: CALayer, _ label: (words: String, note: String?), isHeld: Bool) {
        let at = AsksPanelParts.label(in: row.bounds.size, note: label.note)
        let words = TextLine.text(
            label.words, EdgeStyle.asksLabel, isHeld ? EdgeStyle.onWhite : EdgeStyle.ink,
            kern: EdgeStyle.tightKern(EdgeStyle.asksLabel)
        )

        if let note = label.note, let box = at.note {
            let colour = isHeld ? EdgeStyle.onWhite.copy(alpha: 0.5) ?? EdgeStyle.onWhite : EdgeStyle.ink3

            row.addSublayer(TextLine(TextLine.text(note, EdgeStyle.asksNote, colour), in: box))
        }
        row.addSublayer(TextLine(words, in: at.label))
    }

    private static func keycap(_ mark: String) -> CALayer {
        let cap = rounded(AsksLayout.keycap, AsksLayout.keycapRadius, fill: EdgeStyle.keycap)
        let words = TextLine.text(mark, EdgeStyle.asksKeycap, EdgeStyle.ink2)
        let width = TextLine.width(words), line = AsksLayout.textLine

        cap.addSublayer(TextLine(words, in: CGRect(
            x: (cap.bounds.width - width) / 2, y: (cap.bounds.height - line) / 2, width: width, height: line
        )))
        return cap
    }

    /// The held answer's check, in its keycap's place.
    private static func check() -> CALayer {
        let check = AsksPanelParts.check()

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
        let snooze = footWords(AsksLayout.snoozeWords, in: layout.snooze, lit: asks.hover == .snooze)
        let open = layout.open.map { openPill($0, lit: asks.hover == .open) }

        return [ignore, snooze, snoozeChevron(in: layout.snooze, lit: asks.hover == .snooze)] + [open].compactMap { $0 }
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
