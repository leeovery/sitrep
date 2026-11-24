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
    /// clock; hidden while it is closed.
    func show(_ asks: AsksShown?, mirror: CGAffineTransform, now: Double) {
        guard let asks else {
            layer.isHidden = true
            shown = nil
            return
        }

        let pointsLeft = mirror.a < 0, asked = asks.ask.askedText(at: now)

        still {
            layer.isHidden = false
            layer.frame = asks.frame.applying(mirror)
            if !Self.drawsAlike(asks, shown) || drawnFor?.pointsLeft != pointsLeft || drawnFor?.asked != asked {
                layer.sublayers = Self.parts(of: asks, pointsLeft: pointsLeft, now: now)
                rescale(layer, to: scale)
            }
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

    /// Its two shadows, as a submenu's: 14 down blurred 36 at 65%, and toward the list, 4 across blurred 12 at 50%.
    /// Each a black of its shape casting it, under the body; Core Animation's radius halves the CSS blur.
    private static func shadows(_ size: CGSize, pointsLeft: Bool) -> [CALayer] {
        let toward = pointsLeft ? 4.0 : -4.0

        return [(CGSize(width: 0, height: 14), 18.0, 0xA6), (CGSize(width: toward, height: 0), 6.0, 0x80)]
            .map { offset, radius, alpha in
                let shadow = rounded(CGRect(origin: .zero, size: size), AsksLayout.radius, fill: EdgeStyle.black)

                shadow.shadowPath = CGPath(
                    roundedRect: shadow.bounds, cornerWidth: AsksLayout.radius, cornerHeight: AsksLayout.radius,
                    transform: nil
                )
                shadow.shadowColor = EdgeStyle.black
                shadow.shadowOpacity = Float(alpha) / 255
                shadow.shadowRadius = radius
                shadow.shadowOffset = offset
                return shadow
            }
    }

    private static func body(_ size: CGSize) -> CALayer {
        let body = rounded(CGRect(origin: .zero, size: size), AsksLayout.radius, fill: EdgeStyle.black)

        body.borderWidth = 1
        body.borderColor = EdgeStyle.asksBorder
        return body
    }

    /// The top line: the session's name, 8, its project faint, the name kept whole first; and page dots at its right
    /// where the session has more than one ask, the current one orange and wide.
    private static func top(_ asks: AsksShown) -> [CALayer] {
        let box = asks.layout.top, line = AsksLayout.textLine, gap = 8.0, y = box.midY - line / 2
        let dots = asks.pages > 1 ? Self.dots(asks.page, of: asks.pages, right: box.maxX, middle: box.midY) : []
        let room = box.width - (dots.isEmpty ? 0 : Self.dotsWidth(asks.pages) + gap)
        let name = TextLine.text(asks.session.name, EdgeStyle.asksName, EdgeStyle.ink)
        let nameWidth = min(TextLine.width(name), room)
        let project = TextLine.text(asks.session.project, EdgeStyle.sub, EdgeStyle.ink3)
        let projectX = box.minX + nameWidth + gap

        return [
            TextLine(name, in: CGRect(x: box.minX, y: y, width: nameWidth, height: line)),
            TextLine(project, in: CGRect(x: projectX, y: y, width: max(0, box.minX + room - projectX), height: line)),
        ] + dots
    }

    private static let dotGap = 4.0, dotSide = 5.0, currentDot = 14.0

    private static func dotsWidth(_ pages: Int) -> Double {
        currentDot + Double(pages - 1) * (dotSide + dotGap)
    }

    private static func dots(_ page: Int, of pages: Int, right: Double, middle: Double) -> [CALayer] {
        var x = right - dotsWidth(pages)

        return (0 ..< pages).map { index in
            let width = index == page ? currentDot : dotSide
            let dot = rounded(
                CGRect(x: x, y: middle - dotSide / 2, width: width, height: dotSide), 3,
                fill: index == page ? EdgeStyle.orange : EdgeStyle.dot
            )

            x += width + dotGap
            return dot
        }
    }

    /// The ask's title, wrapped to its lines, and under it how long ago it was asked.
    private static func ask(_ asks: AsksShown, at now: Double) -> [CALayer] {
        let layout = asks.layout, box = layout.title
        let title = TextLine.text(asks.ask.title, EdgeStyle.asksTitle, EdgeStyle.ink, kern: EdgeStyle.asksTitleKern)
        let lines = TextLine.wrapped(title, width: box.width, most: layout.titleLines).enumerated().map { index, line in
            TextLine(line, in: CGRect(
                x: box.minX, y: box.minY + Double(index) * AsksLayout.titleLine, width: box.width,
                height: AsksLayout.titleLine
            ))
        }

        let asked = TextLine.text(asks.ask.askedText(at: now), EdgeStyle.sub, EdgeStyle.ink3)

        return lines + [TextLine(asked, in: layout.age)]
    }

    /// An answer's row: filled and bordered, lifted under the pointer, white while it is the answer held; outlined,
    /// for the one row that answers in Claude. Its keycap holds its number, or ↗, or held, a check in its place; then
    /// its label, and "recommended" at its end for Claude's pick.
    private static func answer(_ index: Int, of asks: AsksShown) -> CALayer {
        let box = asks.layout.answers[index], isHeld = asks.sending.map { $0.row == index } ?? false
        let isLifted = asks.hover == .answer(index) || asks.hover == .inClaude
        let row = rounded(box, AsksLayout.answerRadius, fill: nil)
        let label = asks.ask.isInClaude ? "Answer in Claude" : asks.ask.answers[index]
        let note = asks.ask.recommended == label && !asks.ask.isInClaude ? "recommended" : nil

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
        labelled(row, label, note: note, isHeld: isHeld)
        return row
    }

    /// A row's label after its keycap, and its note at its end, the label cut short before it.
    private static func labelled(_ row: CALayer, _ label: String, note: String?, isHeld: Bool) {
        let width = row.bounds.width, line = AsksLayout.labelLine, y = (row.bounds.height - line) / 2
        let words = TextLine.text(
            label, EdgeStyle.asksLabel, isHeld ? EdgeStyle.onWhite : EdgeStyle.ink,
            kern: EdgeStyle.tightKern(EdgeStyle.asksLabel)
        )
        var end = width - AsksLayout.rowSide

        if let note {
            let colour = isHeld ? EdgeStyle.onWhite.copy(alpha: 0.5) ?? EdgeStyle.onWhite : EdgeStyle.ink3
            let noted = TextLine.text(note, EdgeStyle.asksNote, colour)
            let noteWidth = TextLine.width(noted)
            let drop = TextLine.drop(of: EdgeStyle.asksNote, to: EdgeStyle.asksLabel, lineHeight: line)

            row.addSublayer(TextLine(
                noted, in: CGRect(x: end - noteWidth, y: y + drop, width: noteWidth, height: line)
            ))
            end -= noteWidth + AsksLayout.recommendedGap
        }
        row.addSublayer(TextLine(words, in: CGRect(
            x: AsksLayout.labelX, y: y, width: max(0, end - AsksLayout.labelX), height: line
        )))
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

    /// The held answer's check, 11 across, in its keycap's place.
    private static func check() -> CALayer {
        let path = CGMutablePath(), side = 11.0, cap = AsksLayout.keycap

        path.addLines(between: [CGPoint(x: 2, y: 5.8), CGPoint(x: 4.4, y: 8.2), CGPoint(x: 9, y: 3)])
        return stroked(
            path, in: CGRect(x: cap.midX - side / 2, y: cap.midY - side / 2, width: side, height: side),
            colour: EdgeStyle.onWhite, width: 1.6
        )
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

    /// A foot button's words, soft, white under the pointer, inside its padding on its middle.
    private static func footWords(_ words: String, in box: CGRect, lit: Bool) -> CALayer {
        let line = AsksLayout.textLine

        return TextLine(
            TextLine.text(words, EdgeStyle.asksFoot, lit ? EdgeStyle.ink : EdgeStyle.ink2),
            in: CGRect(x: box.minX + AsksLayout.buttonPad, y: box.midY - line / 2, width: box.width, height: line)
        )
    }

    /// Snooze's chevron, pointing down, after its words.
    private static func snoozeChevron(in box: CGRect, lit: Bool) -> CALayer {
        let size = AsksLayout.snoozeChevron, scale = size.width / 10
        let path = CGMutablePath()

        path.addLines(between: [CGPoint(x: 1.2, y: 1.2), CGPoint(x: 5, y: 4.8), CGPoint(x: 8.8, y: 1.2)].map {
            CGPoint(x: $0.x * scale, y: $0.y * scale)
        })
        return stroked(
            path,
            in: CGRect(
                x: box.maxX - AsksLayout.buttonPad - size.width, y: box.midY - size.height / 2, width: size.width,
                height: size.height
            ),
            colour: lit ? EdgeStyle.ink : EdgeStyle.ink2, width: 1.5
        )
    }

    /// Open in Claude, outlined, its ↗ soft after it; filled under the pointer.
    private static func openPill(_ box: CGRect, lit: Bool) -> CALayer {
        let pill = Self.pill(box, lit: lit), line = AsksLayout.textLine, y = (box.height - line) / 2
        let words = TextLine.text(AsksLayout.openWords, EdgeStyle.asksFoot, EdgeStyle.ink)
        let mark = TextLine.text(AsksLayout.openMark, EdgeStyle.asksFoot, EdgeStyle.ink2)
        let markX = AsksLayout.openPad + TextLine.width(words) + AsksLayout.wordsGap

        pill.addSublayer(TextLine(words, in: CGRect(x: AsksLayout.openPad, y: y, width: box.width, height: line)))
        pill.addSublayer(TextLine(mark, in: CGRect(x: markX, y: y, width: TextLine.width(mark) + 1, height: line)))
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
        let layout = asks.layout
        let lead = sending.words == nil ? "Ignoring" : "Sending "
        let said = TextLine.text(lead, EdgeStyle.asksFootPlain, EdgeStyle.ink2)

        sending.words.map { said.append(TextLine.text($0, EdgeStyle.asksFoot, EdgeStyle.ink)) }

        let undo = pill(layout.undo, lit: asks.hover == .undo), line = AsksLayout.textLine
        let y = (layout.undo.height - line) / 2

        undo.addSublayer(TextLine(
            TextLine.text(AsksLayout.undoWords, EdgeStyle.asksFoot, EdgeStyle.ink),
            in: CGRect(x: AsksLayout.undoPad, y: y, width: layout.undo.width, height: line)
        ))
        return countdown(sending, in: layout.countdown, at: now) + [TextLine(said, in: layout.sending), undo]
    }

    /// The countdown: a track, and over it an arc from 12 o'clock running down from full to nothing as the answer's two
    /// seconds run out, in the render server from what is left at `now`.
    private static func countdown(_ sending: Sending, in box: CGRect, at now: Double) -> [CALayer] {
        let centre = CGPoint(x: box.width / 2, y: box.height / 2), radius = 4.75
        let circle = CGMutablePath()

        circle.addArc(center: centre, radius: radius, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: false)

        let track = stroked(circle, in: box, colour: EdgeStyle.track, width: 1.5)
        let arc = stroked(circle, in: box, colour: EdgeStyle.ink2, width: 1.5)
        let left = sending.left(at: now)
        let run = CABasicAnimation(keyPath: "strokeEnd")

        arc.strokeEnd = left
        run.fromValue = left
        run.toValue = 0
        run.duration = left * (sending.goesAt - sending.heldAt) / 1000
        run.fillMode = .forwards
        run.isRemovedOnCompletion = false
        if run.duration > 0 {
            arc.add(run, forKey: "countdown")
        }
        return [track, arc]
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

    /// How the asks panel's words are set, for the run to lay it out: its title's lines, and its foot's words' widths.
    nonisolated static let measure = AsksMeasure(
        titleLines: { title in
            MainActor.assumeIsolated {
                let text = TextLine.text(title, EdgeStyle.asksTitle, EdgeStyle.ink, kern: EdgeStyle.asksTitleKern)
                let width = AsksLayout.inner - 2 * AsksLayout.textSide

                return max(1, TextLine.wrapped(text, width: width, most: AsksLayout.titleMost).count)
            }
        },
        footWidth: { words in
            MainActor.assumeIsolated { TextLine.width(TextLine.text(words, EdgeStyle.asksFoot, EdgeStyle.ink)) }
        }
    )
}
