import AppKit
import SitRepEdge
import SitRepPanel

/// The asks panel in black (Paper's boards F and H3; DESIGN, "Answering from the panel"): the panel's black, 372 wide,
/// its corners 24, a hairline round it and a submenu's shadow, over the list's front; its top line, the session's name
/// and project and its page dots; the ask's title and its age; its answers' rows, Claude's pick first in lilac, none
/// for an ask Lee answers in Claude, numbered in keycaps while the panel holds the keys; and its foot, Ignore, Snooze ▾
/// and Open in Claude, or, while an answer of its ask is held, the sending line, its ring counting down the two seconds
/// and Undo. It appears at once, as a Mac submenu does, and is drawn again only as what it shows changes; a frame moves
/// it with its row. As its asks slide (DESIGN, "Paging"), the ask's own page, its title, age and answers, slides
/// across with the ask beside it, clipped to its shape; its frame, its top line and its foot stay, its dots and its
/// height following the slide, its foot at its bottom.
@MainActor
final class AsksPanelLayer {
    let layer = CALayer()

    private var shown: AsksShown?
    /// What it was last drawn from beyond `shown`: the edge it opens from, and its ask's age as worded.
    private var drawnFor: (pointsLeft: Bool, asked: String)?
    private var scale: CGFloat = 1
    /// What of the parts last drawn moves as its asks slide.
    private var sliding: Sliding?

    /// What moves as its asks slide: its shadows, its black and its hairline, as tall as it is; its page dots; its
    /// asks' pages across, clipped to its shape, the ask shown's and the one beside it; and its foot at its bottom,
    /// over a band of its black the pages pass under, the foot of the ask beside cross-fading with it where the two
    /// differ, as a sending line does from a foot.
    private struct Sliding {
        let shadows: [CALayer]
        let grounds: [CALayer]
        let dots: CALayer
        let clip: CALayer
        let page: CALayer
        let beside: CALayer?
        let band: CALayer
        let foot: CALayer
        let besideFoot: CALayer?
    }

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
            let parts = Self.parts(of: asks, pointsLeft: pointsLeft, now: now)

            layer.sublayers = parts.layers
            sliding = parts.sliding
            rescale(layer, to: scale)
        }
        sliding.map { Self.slide($0, as: asks) }
        shown = asks
        drawnFor = (pointsLeft, asked)
    }

    /// What moves as its asks slide, moved as far as they have: its ground as tall as it is, its ask's page and the
    /// one beside it across, its foot at its bottom, faded as far as a foot beside it has come in, and its dots.
    private static func slide(_ sliding: Sliding, as asks: AsksShown) {
        let bounds = CGRect(origin: .zero, size: asks.frame.size), height = bounds.height
        let band = asks.layout.height - asks.layout.foot.minY + AsksLayout.between

        for ground in sliding.grounds + [sliding.clip] {
            ground.frame = bounds
        }
        for shadow in sliding.shadows {
            shadow.shadowPath = outline(bounds)
        }
        sliding.page.frame.origin.x = asks.pageX
        sliding.beside?.frame.origin.x = asks.besideX
        sliding.band.frame = CGRect(x: 0, y: height - band, width: bounds.width, height: band)
        sliding.foot.frame.origin.y = height - asks.layout.height
        sliding.foot.opacity = sliding.besideFoot == nil ? 1 : Float(1 - asks.share)
        sliding.besideFoot?.frame.origin.y = height - (asks.beside?.layout.height ?? 0)
        sliding.besideFoot?.opacity = Float(asks.share)
        sliding.dots.sublayers = dots(asks)
    }

    func rescaled(to scale: CGFloat) {
        self.scale = scale
        rescale(layer, to: scale)
    }

    /// Everything it draws, from the back: its shadows, its black, its top line and its dots, its asks' pages and its
    /// foot over them, and its hairline over all, so a page sliding past its edge never covers it; and what of them
    /// moves as its asks slide. The ask beside has a foot of its own only where it differs, one of the two sending.
    private static func parts(
        of asks: AsksShown, pointsLeft: Bool, now: Double
    ) -> (layers: [CALayer], sliding: Sliding) {
        let shadows = Self.shadows(pointsLeft: pointsLeft), body = Self.body(), rim = Self.rim()
        let dots = CALayer(), clip = CALayer()
        let beside = asks.shownBeside, band = rounded(.zero, 0, fill: EdgeStyle.black)
        let differs = asks.sending != nil || beside?.sending != nil
        let sliding = Sliding(
            shadows: shadows, grounds: shadows + [body, rim], dots: dots, clip: clip, page: page(asks, at: now),
            beside: beside.map { page($0, at: now) }, band: band, foot: footLayer(asks, at: now),
            besideFoot: differs ? beside.map { footLayer($0, at: now) } : nil
        )

        clip.cornerRadius = AsksLayout.radius
        clip.masksToBounds = true
        clip.sublayers = [sliding.page] + [sliding.beside, band, sliding.besideFoot, sliding.foot].compactMap { $0 }
        return (shadows + [body] + top(asks) + [dots, clip, rim], sliding)
    }

    /// An ask's page, as wide as it and as tall as its ask: its title and age, and its answers' rows.
    private static func page(_ asks: AsksShown, at now: Double) -> CALayer {
        let page = CALayer()

        page.frame = CGRect(origin: .zero, size: asks.layout.size)
        page.sublayers = ask(asks, at: now) + asks.layout.answers.indices.map { answer($0, of: asks) }
        return page
    }

    /// An ask's foot, in a layer as big as its ask, for its foot to stand at its bottom however tall it is.
    private static func footLayer(_ asks: AsksShown, at now: Double) -> CALayer {
        let foot = CALayer()

        foot.frame = CGRect(origin: .zero, size: asks.layout.size)
        foot.sublayers = Self.foot(asks, at: now)
        return foot
    }

    /// Its outline in its own frame, its corners rounded.
    private static func outline(_ bounds: CGRect) -> CGPath {
        CGPath(roundedRect: bounds, cornerWidth: AsksLayout.radius, cornerHeight: AsksLayout.radius, transform: nil)
    }

    /// Its two shadows (`AsksShadow`), each a black of its shape casting it, under the body.
    private static func shadows(pointsLeft: Bool) -> [CALayer] {
        AsksShadow.casts(pointsLeft: pointsLeft).map { cast in
            let shadow = rounded(.zero, AsksLayout.radius, fill: EdgeStyle.black)

            shadow.shadowColor = EdgeStyle.black
            shadow.shadowOpacity = Float(cast.opacity)
            shadow.shadowRadius = cast.radius
            shadow.shadowOffset = cast.offset
            return shadow
        }
    }

    private static func body() -> CALayer {
        rounded(.zero, AsksLayout.radius, fill: EdgeStyle.black)
    }

    /// Its hairline, white at 15%.
    private static func rim() -> CALayer {
        let rim = rounded(.zero, AsksLayout.radius, fill: nil)

        rim.borderWidth = 1
        rim.borderColor = EdgeStyle.asksBorder
        return rim
    }

    /// The top line's words: the session's name and its project faint.
    private static func top(_ asks: AsksShown) -> [CALayer] {
        let top = AsksPanelParts.top(asks)

        return [
            TextLine(TextLine.text(asks.session.name, EdgeStyle.asksName, EdgeStyle.ink), in: top.name),
            TextLine(TextLine.text(asks.session.project, EdgeStyle.sub, EdgeStyle.ink3), in: top.project),
        ]
    }

    /// Its page dots as far as its asks have slid, the current one orange, and as the wide one passes to the next,
    /// each as orange as it is current.
    private static func dots(_ asks: AsksShown) -> [CALayer] {
        AsksPanelParts.dots(asks).map { dot in
            rounded(dot.box, AsksPanelParts.dotRadius, fill: blend(EdgeStyle.dot, EdgeStyle.orange, dot.current))
        }
    }

    /// A colour this share of the way to another, in the first's colour space.
    private static func blend(_ from: CGColor, _ to: CGColor, _ share: Double) -> CGColor {
        guard let space = from.colorSpace, let ends = from.components, let others = to.converted(
            to: space, intent: .defaultIntent, options: nil
        )?.components, ends.count == others.count else {
            return share < 0.5 ? from : to
        }

        return CGColor(colorSpace: space, components: zip(ends, others).map { $0 + ($1 - $0) * share }) ?? to
    }

    /// The ask's title, wrapped to its lines, and under it how long ago it was asked.
    private static func ask(_ asks: AsksShown, at now: Double) -> [CALayer] {
        let lines = AsksPanelParts.titleLines(asks, colour: EdgeStyle.ink).map { TextLine($0.text, in: $0.box) }
        let asked = TextLine.text(asks.ask.askedText(at: now), EdgeStyle.sub, EdgeStyle.ink3)

        return lines + [TextLine(asked, in: asks.layout.age)]
    }

    /// An answer's row (Paper's board H3): its words alone, on up to two lines, Claude's pick filled and bordered in
    /// lilac with "Recommended" after its words, any other in the panel's greys; each lighter under the pointer; its
    /// number in a keycap at its right end while the panel holds the keys; white while it is the answer held, its words
    /// in ink and a check in its keycap's room.
    private static func answer(_ index: Int, of asks: AsksShown) -> CALayer {
        let shows = AsksPanelParts.answerRow(index, of: asks), lines = asks.layout.answerLines[index]
        let row = rounded(asks.layout.answers[index], AsksLayout.answerRadius, fill: nil)
        let ground = Self.ground(shows)

        row.borderWidth = 1
        row.backgroundColor = ground.fill
        row.borderColor = ground.border
        for (line, box) in AsksPanelParts.answerLines(index, of: asks) {
            row.addSublayer(Self.line(line, in: box, isHeld: shows.isHeld))
        }
        if shows.isHeld {
            row.addSublayer(check(in: row.bounds.size, lines: lines))
        } else if let number = shows.number {
            row.addSublayer(keycap(number, in: AsksLayout.keycap(in: row.bounds.size, lines: lines)))
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

    /// The held answer's check, in ink, in its keycap's room.
    private static func check(in row: CGSize, lines: Int) -> CALayer {
        let check = AsksPanelParts.check(in: row, lines: lines)

        return stroked(check.path, in: check.box, colour: EdgeStyle.onWhite, width: AsksPanelParts.checkWidth)
    }

    /// An answer's keycap, its number soft on it.
    private static func keycap(_ number: Int, in box: CGRect) -> CALayer {
        let cap = rounded(box, AsksLayout.keycapRadius, fill: EdgeStyle.keycap)
        let digit = AsksPanelParts.keycapNumber(number)

        cap.addSublayer(TextLine(digit.text, in: digit.box))
        return cap
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
