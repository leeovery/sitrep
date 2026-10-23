import AppKit
import SitRepPanel

/// One session's row in black, as the prototype draws it: its mark, its title (`Session.headline`), its subject in
/// mono after it, and its time at the right; the line under them; the lift under the pointer, and a new row's wash. A
/// row needing Lee is its session, as Paper's board F draws it: its name, and a quiet "+2" for its lines after the
/// first, over its project, or for an away one why a click does nothing. A working row's arc turns and its lead
/// shimmers, its subject still, in the render server. A row on its own work is still: its dotted ring, and its title,
/// a wake's countdown in it set again as it reads differently. A your-turn row on the card is on one line, as board D
/// draws it: its ring, its words in regular, its project faint at the right of them, never cut, and its time. A row in
/// Snoozed is a row needing Lee quieted, as Paper's board G draws it: its dot grey and unlit, its name soft, its "+2"
/// and its project faint, and in its time's place when its soonest ask wakes, soft, the lane grown to fit it. Under
/// the pointer any row's time gives way to its button, which opens its session in the SitRep window.
@MainActor
final class SessionRow {
    /// The row's box: the item less the gap below it.
    let layer = CALayer()
    let session: Session
    let isOneLine: Bool

    private var at: SessionRowLayout
    private let wash = CALayer()
    /// The arc that spins in the time's place while a click is jumping from it.
    private let spinner: Arc
    /// The button in the time's place under the pointer.
    let opener: CALayer
    /// Its time, and what it says, as last set.
    private var age: TextLine?
    private var ageText = ""
    /// Its title's layers, and the line under it.
    private var titleLayers: [CALayer] = []
    private var subLine = CALayer()
    /// What its title says after its verb, as last set: a wake's countdown changes it as the clock ticks.
    private var subject: String?

    init(_ session: Session, size: CGSize, oneLine: Bool = false) {
        let project = TextLine.text(session.project, EdgeStyle.sub, EdgeStyle.ink3)
        let radius = oneLine ? SessionRowLayout.turnRadius : SessionRowLayout.radius

        self.session = session
        isOneLine = oneLine
        at = oneLine ? SessionRowLayout(turn: size, project: TextLine.width(project)) : SessionRowLayout(size: size)
        spinner = Self.arc(right: at.age)
        opener = CardParts.opener(in: at.opener)
        subject = session.subject
        layer.frame = CGRect(origin: .zero, size: size)
        layer.cornerRadius = radius
        wash.frame = layer.bounds
        wash.cornerRadius = radius
        wash.backgroundColor = EdgeStyle.wash
        wash.borderColor = EdgeStyle.washRing
        wash.borderWidth = 1
        wash.opacity = 0
        layer.addSublayer(wash)
        layer.addSublayer(mark(at: at.mark))
        showTitle()
        subLine = oneLine ? projectLine(project) : sub(in: at.sub)
        layer.addSublayer(subLine)
        spinner.layer.isHidden = true
        layer.addSublayer(spinner.layer)
        opener.isHidden = true
        layer.addSublayer(opener)
    }

    /// A one-line row's project in its lane, on its words' baseline.
    private func projectLine(_ project: NSAttributedString) -> TextLine {
        let drop = TextLine.drop(of: EdgeStyle.sub, to: EdgeStyle.line, lineHeight: at.sub.height)

        return TextLine(project, in: at.sub.offsetBy(dx: 0, dy: drop))
    }

    /// Under the pointer, its time gives way to its button, and a row that jumps lifts; an away row, which jumps
    /// nowhere, shows its button alone.
    var isHighlighted = false {
        didSet {
            showBackground()
            showTimeOrButton()
        }
    }

    /// A click is jumping from it: it presses in, as the prototype's does in 140ms, its background in 110, and an arc
    /// spins where its time or its button was.
    var isPressed = false {
        didSet {
            guard isPressed != oldValue else {
                return
            }

            CATransaction.begin()
            CATransaction.setDisableActions(false)
            CATransaction.setAnimationDuration(0.14)
            layer.setAffineTransform(isPressed ? Self.pressedIn : .identity)
            CATransaction.setAnimationDuration(0.11)
            showBackground()
            CATransaction.commit()
            showTimeOrButton()
        }
    }

    private static let pressedIn = CGAffineTransform(scaleX: 0.985, y: 0.985)

    private func showBackground() {
        layer.backgroundColor = isPressed ? EdgeStyle.press : isHighlighted && session.jumps ? EdgeStyle.hover : nil
    }

    /// In the time's place, one of three: pressed, the spinner; under the pointer, the button; else the time.
    private func showTimeOrButton() {
        still {
            age?.isHidden = isPressed || isHighlighted
            opener.isHidden = isPressed || !isHighlighted
            spinner.layer.isHidden = !isPressed
        }
    }

    /// Its time at this moment on the wall clock, ms, or in Snoozed when it wakes, and a wake's countdown, each drawn
    /// again only when it reads differently.
    func showAge(at now: Double) {
        if session.until != nil, session.subject(at: now) != subject {
            subject = session.subject(at: now)
            showTitle()
        }
        showAge(session.timeText(at: now, in: .autoupdatingCurrent))
    }

    private func showAge(_ text: String) {
        guard text != ageText else {
            return
        }

        let words = TextLine.text(text, EdgeStyle.age, session.isSnoozed ? EdgeStyle.ink2 : EdgeStyle.ink3)

        if session.isSnoozed {
            fit(time: TextLine.width(words))
        }

        let line = TextLine(words, in: at.age, alignment: .right)

        line.contentsScale = layer.contentsScale
        line.isHidden = isPressed || isHighlighted
        if let age {
            layer.replaceSublayer(age, with: line)
        } else {
            layer.insertSublayer(line, below: spinner.layer)
        }
        age = line
        ageText = text
    }

    /// A row in Snoozed's lane fitted to when it wakes, its title and the line under it, cut short before it, laid out
    /// again where it changed: the lane only narrows as the days go, from a date to a weekday to today's time.
    private func fit(time width: CGFloat) {
        let fitted = SessionRowLayout(size: layer.bounds.size, time: width)

        guard fitted.age != at.age else {
            return
        }

        at = fitted
        showTitle()

        let sub = sub(in: at.sub)

        still { layer.replaceSublayer(subLine, with: sub) }
        subLine = sub
    }

    /// The line under its title, whole: its project, or what core says there.
    private func sub(in box: CGRect) -> TextLine {
        TextLine(TextLine.text(session.sub, EdgeStyle.sub, subColour), in: box)
    }

    /// New on the board while the panel is out: washed orange (`Wash`) from this time, ms on the display's clock,
    /// which may have passed.
    func washes(since began: Double) {
        let fade = CAKeyframeAnimation(keyPath: "opacity")

        fade.beginTime = wash.convertTime(began / 1000, from: nil)
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, NSNumber(value: Wash.held / Wash.length), 1]
        fade.timingFunctions = [CAMediaTimingFunction(name: .linear), CAMediaTimingFunction(name: .easeInEaseOut)]
        fade.duration = Wash.length / 1000
        wash.add(fade, forKey: Self.washKey)
    }

    static let washKey = "wash"

    /// The wash under way, while there is one.
    var washing: CAAnimation? { wash.animation(forKey: Self.washKey) }

    /// Its title drawn again in place of the last.
    private func showTitle() {
        let made = title()

        still {
            titleLayers.forEach { $0.removeFromSuperlayer() }
            made.forEach { line in
                line.contentsScale = layer.contentsScale
                layer.insertSublayer(line, below: spinner.layer)
            }
        }
        titleLayers = made
    }

    /// An away row's words dim; a Snoozed row's are soft, its "+2" and its project faint.
    private var titleColour: CGColor {
        session.away ? EdgeStyle.off : session.isSnoozed ? EdgeStyle.ink2 : EdgeStyle.ink
    }

    private var subColour: CGColor { session.away || session.isSnoozed ? EdgeStyle.ink3 : EdgeStyle.ink2 }

    /// Its title's layers: the title, and a session's "+2" after it, board F's, quiet in the second line's colour, 6
    /// after the name on its baseline, which the name is cut short to leave room for.
    private func title() -> [CALayer] {
        let box = at.title

        guard let more = session.more else {
            return [titleLine(in: box).layer]
        }

        let count = TextLine.text(more, EdgeStyle.count, subColour)
        let width = TextLine.width(count), gap = SessionRowLayout.countGap
        var cut = box

        cut.size.width -= width + gap

        let line = titleLine(in: cut)
        let drop = TextLine.drop(of: EdgeStyle.count, to: EdgeStyle.title, lineHeight: box.height)
        let after = CGRect(x: cut.minX + line.width + gap, y: cut.minY + drop, width: width, height: cut.height)

        return [line.layer, TextLine(count, in: after)]
    }

    /// Its title in its box, and how wide it is drawn there. A working title is grey, its lead lit by the sweep and
    /// its subject left still; one on its own work is still.
    private func titleLine(in box: CGRect) -> (layer: CALayer, width: CGFloat) {
        let line = session.headline

        if session.kind == .onItsWork {
            let drawn = TextLine(WaitingTitle.text(session, subject: subject), in: box)

            return (drawn, drawn.width)
        }

        guard session.kind == .working else {
            let drawn = TextLine(titleText(line, titleColour), in: box)

            return (drawn, drawn.width)
        }

        let shimmer = Shimmer(
            grey: titleText(line, EdgeStyle.shim), lit: titleText(line, EdgeStyle.ink, subject: false), in: box
        )

        shimmer.band.add(shimmer.sweep, forKey: "sweep")

        return (shimmer.layer, shimmer.width)
    }

    /// A line's title in a colour, its subject in mono after it: in medium, or on one line in regular.
    private func titleText(_ line: Session.Line, _ colour: CGColor, subject: Bool = true) -> NSAttributedString {
        let font = isOneLine ? EdgeStyle.line : EdgeStyle.title
        let text = TextLine.text(line.title, font, colour, kern: EdgeStyle.tightKern(font))

        if subject, let code = line.code {
            text.append(TextLine.text(code, EdgeStyle.code, colour))
        }

        return text
    }

    /// Its mark: needs you an orange dot with its glow, away or not; your turn an open white ring, on one line board
    /// D's 9; working the arc turning; on its own work the dotted ring, still; in Snoozed a faint dot, unlit.
    private func mark(at centre: CGPoint) -> CALayer {
        switch session.kind {
        case .needs:
            let dot = Self.disc(7, at: centre, fill: EdgeStyle.orange)

            dot.shadowColor = EdgeStyle.orange
            dot.shadowOpacity = 0.75
            dot.shadowRadius = 2
            dot.shadowOffset = .zero

            return dot
        case .turn:
            return Self.ring(isOneLine ? 9 : 7, at: centre, colour: EdgeStyle.ink)
        case .working:
            return Self.arc(in: CGRect(x: centre.x - 5.5, y: centre.y - 5.5, width: 11, height: 11)).layer
        case .onItsWork:
            return DottedRing.card.layer(centredOn: centre, colour: EdgeStyle.grey)
        case .snoozed:
            return Self.disc(7, at: centre, fill: EdgeStyle.ink3)
        }
    }

    /// The prototype's 11-point arc, turning once a second: a working row's mark, and a pressed row's spinner.
    private static func arc(in box: CGRect) -> Arc {
        let arc = Arc(from: -0.75 * .pi)

        arc.fit(box)
        arc.track.strokeColor = EdgeStyle.track
        arc.arc.strokeColor = EdgeStyle.ink
        arc.turn(every: 1)

        return arc
    }

    /// The arc at the right of a lane, on its middle.
    private static func arc(right lane: CGRect) -> Arc {
        arc(in: CGRect(x: lane.maxX - 11, y: lane.midY - 5.5, width: 11, height: 11))
    }

    /// An open ring this wide, its stroke 1.5 inside it: your turn's, and "N earlier"'s.
    static func ring(_ size: CGFloat, at centre: CGPoint, colour: CGColor) -> CALayer {
        let ring = disc(size, at: centre, fill: CGColor.clear)

        ring.borderWidth = 1.5
        ring.borderColor = colour

        return ring
    }

    private static func disc(_ size: CGFloat, at centre: CGPoint, fill: CGColor) -> CALayer {
        let dot = CALayer()

        dot.frame = CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)
        dot.cornerRadius = size / 2
        dot.backgroundColor = fill

        return dot
    }
}
