import AppKit
import SitRepPanel

/// One session's row in black, as the prototype draws it: for each of its lines, its mark, its title, its subject in
/// mono after it and a question's "+2", and its time at the right, the lines 4 apart; its project and session beneath,
/// or for an away one why a click does nothing; the lift under the pointer, and a new row's wash, the row's as one. A
/// working row's arc turns and its lead shimmers, its subject still, in the render server. A row on its own work is
/// still: its dotted ring, and its title, a wake's countdown in it set again as it reads differently. A your-turn row
/// on the card is on one line, as board D draws it: its ring, its words in regular, its project faint at the right of
/// them, never cut, and its time.
@MainActor
final class SessionRow {
    /// The row's box: the item less the gap below it.
    let layer = CALayer()
    let session: Session
    let isOneLine: Bool

    private let at: SessionRowLayout
    private let wash = CALayer()
    /// The arc that spins in the first line's time's place while a click is jumping from it.
    private let spinner: Arc
    /// Each line's time, and what it says, as last set.
    private var ages: [TextLine?]
    private var ageTexts: [String]
    /// Each line's title's layers.
    private var titleLayers: [[CALayer]]
    /// What each line's title says after its verb, as last set: a wake's countdown changes it as the clock ticks.
    private var subjects: [String?]

    init(_ session: Session, size: CGSize, oneLine: Bool = false) {
        let project = TextLine.text(session.project, EdgeStyle.sub, EdgeStyle.ink3)
        let radius = oneLine ? SessionRowLayout.turnRadius : SessionRowLayout.radius

        self.session = session
        isOneLine = oneLine
        at = oneLine
            ? SessionRowLayout(turn: size, project: TextLine.width(project))
            : SessionRowLayout(size: size, lines: session.lines.count)
        spinner = Self.arc(right: at.age)
        ages = session.lines.map { _ in nil }
        ageTexts = session.lines.map { _ in "" }
        titleLayers = session.lines.map { _ in [] }
        subjects = session.lines.map(\.subject)
        layer.frame = CGRect(origin: .zero, size: size)
        layer.cornerRadius = radius
        wash.frame = layer.bounds
        wash.cornerRadius = radius
        wash.backgroundColor = EdgeStyle.wash
        wash.borderColor = EdgeStyle.washRing
        wash.borderWidth = 1
        wash.opacity = 0
        layer.addSublayer(wash)
        at.lines.forEach { layer.addSublayer(mark(at: $0.mark)) }
        session.lines.indices.forEach(showTitle)
        layer.addSublayer(oneLine ? projectLine(project) : TextLine(TextLine.text(session.sub, EdgeStyle.sub, subColour), in: at.sub))
        spinner.layer.isHidden = true
        layer.addSublayer(spinner.layer)
    }

    /// A one-line row's project in its lane, on its words' baseline.
    private func projectLine(_ project: NSAttributedString) -> TextLine {
        let drop = TextLine.drop(of: EdgeStyle.sub, to: EdgeStyle.line, lineHeight: at.sub.height)

        return TextLine(project, in: at.sub.offsetBy(dx: 0, dy: drop))
    }

    /// Under the pointer, a row that jumps lifts.
    var isHighlighted = false {
        didSet {
            showBackground()
        }
    }

    /// A click is jumping from it: it presses in, as the prototype's does in 140ms, its background in 110, and an arc
    /// spins where its first line's time was, the others' gone meanwhile.
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
            still {
                ages.forEach { $0?.isHidden = isPressed }
                spinner.layer.isHidden = !isPressed
            }
        }
    }

    private static let pressedIn = CGAffineTransform(scaleX: 0.985, y: 0.985)

    private func showBackground() {
        layer.backgroundColor = isPressed ? EdgeStyle.press : isHighlighted && session.jumps ? EdgeStyle.hover : nil
    }

    /// Each line's time at this moment on the wall clock, ms, and a wake's countdown, each drawn again only when it
    /// reads differently.
    func showAge(at now: Double) {
        for (index, line) in session.lines.enumerated() {
            if line.until != nil, line.subject(at: now) != subjects[index] {
                subjects[index] = line.subject(at: now)
                showTitle(index)
            }
            showAge(index, line.ageText(at: now))
        }
    }

    private func showAge(_ index: Int, _ text: String) {
        guard text != ageTexts[index] else {
            return
        }

        let line = TextLine(TextLine.text(text, EdgeStyle.age, EdgeStyle.ink3), in: at.lines[index].age, alignment: .right)

        line.contentsScale = layer.contentsScale
        line.isHidden = isPressed
        if let age = ages[index] {
            layer.replaceSublayer(age, with: line)
        } else {
            layer.addSublayer(line)
        }
        ages[index] = line
        ageTexts[index] = text
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

    /// A line's title drawn again in place of the last.
    private func showTitle(_ index: Int) {
        let made = title(index)

        still {
            titleLayers[index].forEach { $0.removeFromSuperlayer() }
            made.forEach { line in
                line.contentsScale = layer.contentsScale
                layer.addSublayer(line)
            }
        }
        titleLayers[index] = made
    }

    /// An away row's words dim.
    private var titleColour: CGColor { session.away ? EdgeStyle.off : EdgeStyle.ink }

    private var subColour: CGColor { session.away ? EdgeStyle.ink3 : EdgeStyle.ink2 }

    /// A line's title's layers: the title, and a question's "+2" after it, which the title is cut short to leave room
    /// for.
    private func title(_ index: Int) -> [CALayer] {
        let box = at.lines[index].title

        guard let more = session.lines[index].more else {
            return [titleLine(index, in: box).layer]
        }

        let count = TextLine.text(more, EdgeStyle.title, EdgeStyle.ink2)
        let width = TextLine.width(count), gap = SessionRowLayout.moreGap
        var cut = box

        cut.size.width -= width + gap

        let line = titleLine(index, in: cut)
        let after = CGRect(x: cut.minX + line.width + gap, y: cut.minY, width: width, height: cut.height)

        return [line.layer, TextLine(count, in: after)]
    }

    /// A line's title in its box, and how wide it is drawn there. A working title is grey, its lead lit by the sweep
    /// and its subject left still; one on its own work is still.
    private func titleLine(_ index: Int, in box: CGRect) -> (layer: CALayer, width: CGFloat) {
        let line = session.lines[index]

        if session.kind == .onItsWork {
            let drawn = TextLine(WaitingTitle.text(session, subject: subjects[index]), in: box)

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

    /// A line's mark: needs you an orange dot with its glow, away or not; your turn an open white ring, on one line
    /// board D's 9; working the arc turning; on its own work the dotted ring, still.
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
