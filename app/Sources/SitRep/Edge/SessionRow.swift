import AppKit
import SitRepPanel

/// One session's row in black, as the prototype draws it: its mark, its title (`Session.headline`), and its time at the
/// right; the lift under the pointer, and a new row's wash. Over the hairline a row is drawn whole, its title over a
/// second line, as Paper's board I draws the card: a row needing Lee is its session, as board F draws it, its name and
/// a quiet "+2" for its lines after the first, over its project, or for an away one why a click does nothing; a
/// your-turn row its open ring, what Claude left Lee in regular, over its project and session. Under the hairline a row
/// is on one line, its project faint at the right of its words, never cut: a Working row its verb, then what it acts
/// on or waits on, an arc turning and its verb shimmering in the render server, or on its own work its dotted ring and
/// its words still, a wake's countdown set again as it reads differently; a row in Snoozed a row needing Lee quieted,
/// as board G draws it, its dot grey and unlit, its name soft, its "+2" faint, and in its time's place when its
/// soonest ask wakes, soft, the lane grown to fit it. Under the pointer any row's time gives way to its button, which
/// opens its session in the SitRep window.
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
    /// Its title's layers, and the line under it, or on one line its project.
    private var titleLayers: [CALayer] = []
    private var subLine = CALayer()
    /// What its title says after its verb, as last set: a wake's countdown changes it as the clock ticks.
    private var subject: String?
    /// On one line, its project at the right of its words.
    private let project: NSAttributedString

    init(_ session: Session, size: CGSize, oneLine: Bool = false) {
        let radius = SessionRowLayout.radius(of: session.kind)

        self.session = session
        isOneLine = oneLine
        project = TextLine.text(session.project, EdgeStyle.sub, EdgeStyle.ink3)
        at = Self.layout(size, oneLine: oneLine, project: TextLine.width(project))
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
        subLine = second()
        layer.addSublayer(subLine)
        spinner.layer.isHidden = true
        layer.addSublayer(spinner.layer)
        opener.isHidden = true
        layer.addSublayer(opener)
    }

    /// Laid out whole or on one line, its time's lane this wide at the least.
    private static func layout(_ size: CGSize, oneLine: Bool, project: CGFloat, time: Double = 0) -> SessionRowLayout {
        oneLine ? SessionRowLayout(line: size, project: project, time: time) : SessionRowLayout(size: size, time: time)
    }

    /// What it draws beside its title: whole, the line under it, its project or what core says there; on one line,
    /// its project in its lane, on its words' baseline.
    private func second() -> TextLine {
        guard isOneLine else {
            return TextLine(TextLine.text(session.sub, EdgeStyle.sub, subColour), in: at.sub)
        }

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

    /// Its time at this moment on the wall clock, ms, or in Snoozed when it wakes, worded on this calendar, and a
    /// wake's countdown, each drawn again only when it reads differently.
    func showAge(at now: Double, in calendar: Calendar = WakeTime.calendar) {
        if session.until != nil, session.subject(at: now) != subject {
            subject = session.subject(at: now)
            showTitle()
        }
        showAge(session.timeText(at: now, in: calendar))
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

    /// A row in Snoozed's lane fitted to when it wakes, its title and its project cut short before it, laid out again
    /// where it changed: the lane only narrows as the days go, from a date to a weekday to today's time.
    private func fit(time width: CGFloat) {
        let fitted = Self.layout(layer.bounds.size, oneLine: isOneLine, project: TextLine.width(project), time: width)

        guard fitted.age != at.age else {
            return
        }

        at = fitted
        showTitle()

        let sub = second()

        sub.contentsScale = layer.contentsScale
        still { layer.replaceSublayer(subLine, with: sub) }
        subLine = sub
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

    /// A Snoozed row's words are soft, away or not, its "+2" and its project faint; an away row's title and the line
    /// under it dim as one (`Away`).
    private var titleColour: CGColor {
        session.isSnoozed ? EdgeStyle.ink2 : Away.dimmed(EdgeStyle.ink, session.away)
    }

    private var subColour: CGColor { session.isSnoozed ? EdgeStyle.ink3 : Away.dimmed(EdgeStyle.ink2, session.away) }

    /// Its title's layers: the title, and a session's "+2" after it, board F's, quiet in the second line's colour, in
    /// Snoozed faint, 6 after the name on its baseline, which the name is cut short to leave room for.
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
        let drop = TextLine.drop(of: EdgeStyle.count, to: titleFont, lineHeight: box.height)
        let after = CGRect(x: cut.minX + line.width + gap, y: cut.minY + drop, width: width, height: cut.height)

        return [line.layer, TextLine(count, in: after)]
    }

    /// Its title in its box, and how wide it is drawn there. A working title is grey, its verb lit by the sweep and
    /// what follows it left still; one on its own work is still (`LineTitle`).
    private func titleLine(in box: CGRect) -> (layer: CALayer, width: CGFloat) {
        switch session.kind {
        case .onItsWork:
            let drawn = TextLine(LineTitle.text(session, verb: EdgeStyle.waitingVerb, subject: subject), in: box)

            return (drawn, drawn.width)
        case .working:
            let shimmer = Shimmer(
                grey: LineTitle.text(session, verb: EdgeStyle.shim, subject: subject),
                lit: LineTitle.text(session, verb: EdgeStyle.ink, subject: subject, isFollowed: false), in: box
            )

            shimmer.band.add(shimmer.sweep, forKey: "sweep")

            return (shimmer.layer, shimmer.width)
        case .needs, .turn, .snoozed:
            let font = titleFont
            let drawn = TextLine(TextLine.text(session.title, font, titleColour, kern: EdgeStyle.tightKern(font)), in: box)

            return (drawn, drawn.width)
        }
    }

    /// Its title's type: needing Lee, its name in medium; your turn, its words in regular, as Needs you keeps the
    /// heavier title (board I); on one line, regular at 13.
    private var titleFont: NSFont {
        isOneLine ? EdgeStyle.line : session.kind == .needs ? EdgeStyle.title : EdgeStyle.subject
    }

    /// Its mark: needs you an orange dot with its glow, and away a hollow orange ring, unlit (`Away`); your turn an
    /// open white ring, board D's 9; working the arc turning; on its own work the dotted ring, still; in Snoozed a
    /// faint dot, unlit.
    private func mark(at centre: CGPoint) -> CALayer {
        switch session.kind {
        case .needs where session.away:
            return Self.ring(Away.ringSide, at: centre, colour: EdgeStyle.orange)
        case .needs:
            let dot = Self.disc(7, at: centre, fill: EdgeStyle.orange)

            dot.shadowColor = EdgeStyle.orange
            dot.shadowOpacity = 0.75
            dot.shadowRadius = 2
            dot.shadowOffset = .zero

            return dot
        case .turn:
            return Self.ring(9, at: centre, colour: EdgeStyle.ink)
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

    /// An open ring this wide, its stroke 1.5 inside it: your turn's, an away ask's, and "N earlier"'s.
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
