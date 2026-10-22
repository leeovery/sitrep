import AppKit
import SitRepPanel

/// One session's row in black, as the prototype draws it: its mark; its title, its subject in mono after it and a
/// question's "+2"; its project and session beneath, or for an away one why a click does nothing; its time at the
/// right; the lift under the pointer, and a new row's wash. A working row's arc turns and its lead shimmers, its
/// subject still, in the render server. A row on its own work is still: its dotted ring, and its title, a wake's
/// countdown in it set again as it reads differently.
@MainActor
final class SessionRow {
    /// The row's box: the item less the gap below it.
    let layer = CALayer()
    let session: Session

    private let at: SessionRowLayout
    private let wash = CALayer()
    /// The arc that spins in the time's place while a click is jumping from it.
    private let spinner: Arc
    private var age: TextLine?
    private var ageText = ""
    private var titleLayers: [CALayer] = []
    /// What its title says after its verb, as last set: a wake's countdown changes it as the clock ticks.
    private var subject: String?

    init(_ session: Session, size: CGSize) {
        self.session = session
        at = SessionRowLayout(size: size)
        spinner = Self.arc(right: at.age)
        layer.frame = CGRect(origin: .zero, size: size)
        layer.cornerRadius = SessionRowLayout.radius
        wash.frame = layer.bounds
        wash.cornerRadius = SessionRowLayout.radius
        wash.backgroundColor = EdgeStyle.wash
        wash.borderColor = EdgeStyle.washRing
        wash.borderWidth = 1
        wash.opacity = 0
        layer.addSublayer(wash)
        layer.addSublayer(mark())
        subject = session.subject
        showTitle()
        layer.addSublayer(TextLine(TextLine.text(session.sub, EdgeStyle.sub, subColour), in: at.sub))
        spinner.layer.isHidden = true
        layer.addSublayer(spinner.layer)
    }

    /// Under the pointer, a row that jumps lifts.
    var isHighlighted = false {
        didSet {
            showBackground()
        }
    }

    /// A click is jumping from it: it presses in, as the prototype's does in 140ms, its background in 110, and an arc
    /// spins where its time was.
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
                age?.isHidden = isPressed
                spinner.layer.isHidden = !isPressed
            }
        }
    }

    private static let pressedIn = CGAffineTransform(scaleX: 0.985, y: 0.985)

    private func showBackground() {
        layer.backgroundColor = isPressed ? EdgeStyle.press : isHighlighted && session.jumps ? EdgeStyle.hover : nil
    }

    /// Its time at this moment on the wall clock, ms, and a wake's countdown, each drawn again only when it reads
    /// differently.
    func showAge(at now: Double) {
        if session.until != nil, session.subject(at: now) != subject {
            subject = session.subject(at: now)
            showTitle()
        }

        let text = session.ageText(at: now)

        guard text != ageText else {
            return
        }

        let line = TextLine(TextLine.text(text, EdgeStyle.age, EdgeStyle.ink3), in: at.age, alignment: .right)

        line.contentsScale = layer.contentsScale
        line.isHidden = isPressed
        if let age {
            layer.replaceSublayer(age, with: line)
        } else {
            layer.addSublayer(line)
        }
        age = line
        ageText = text
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

    private var isWorking: Bool { session.kind == .working }

    /// Its title drawn again in place of the last.
    private func showTitle() {
        let made = title()

        still {
            titleLayers.forEach { $0.removeFromSuperlayer() }
            made.forEach { line in
                line.contentsScale = layer.contentsScale
                layer.addSublayer(line)
            }
        }
        titleLayers = made
    }

    /// An away row's words dim.
    private var titleColour: CGColor { session.away ? EdgeStyle.off : EdgeStyle.ink }

    private var subColour: CGColor { session.away ? EdgeStyle.ink3 : EdgeStyle.ink2 }

    /// The title's layers: the title, and a question's "+2" after it, which the title is cut short to leave room for.
    private func title() -> [CALayer] {
        guard let more = session.more else {
            return [titleLine(in: at.title).layer]
        }

        let count = TextLine.text(more, EdgeStyle.title, EdgeStyle.ink2)
        let width = TextLine.width(count), gap = SessionRowLayout.moreGap
        var box = at.title

        box.size.width -= width + gap

        let line = titleLine(in: box)
        let after = CGRect(x: box.minX + line.width + gap, y: box.minY, width: width, height: box.height)

        return [line.layer, TextLine(count, in: after)]
    }

    /// The title in its box, and how wide it is drawn there. A working title is grey, its lead lit by the sweep and
    /// its subject left still; one on its own work is still.
    private func titleLine(in box: CGRect) -> (layer: CALayer, width: CGFloat) {
        if session.kind == .onItsWork {
            let line = TextLine(WaitingTitle.text(session, subject: subject), in: box)

            return (line, line.width)
        }

        guard isWorking else {
            let line = TextLine(titleText(titleColour), in: box)

            return (line, line.width)
        }

        let shimmer = Shimmer(grey: titleText(EdgeStyle.shim), lit: titleText(EdgeStyle.ink, subject: false), in: box)

        shimmer.band.add(shimmer.sweep, forKey: "sweep")

        return (shimmer.layer, shimmer.width)
    }

    /// The title in a colour, its subject in mono after it.
    private func titleText(_ colour: CGColor, subject: Bool = true) -> NSAttributedString {
        let font = session.kind == .needs ? EdgeStyle.needsTitle : EdgeStyle.title
        let text = TextLine.text(session.title, font, colour, kern: EdgeStyle.tightKern(font))

        if subject, let code = session.code {
            text.append(TextLine.text(code, EdgeStyle.code, colour))
        }

        return text
    }

    /// Needs you an orange dot with its glow, away or not; your turn an open white ring; working the arc turning; on
    /// its own work the dotted ring, still.
    private func mark() -> CALayer {
        let centre = at.mark

        switch session.kind {
        case .needs:
            let dot = disc(7, at: centre, fill: EdgeStyle.orange)

            dot.shadowColor = EdgeStyle.orange
            dot.shadowOpacity = 0.75
            dot.shadowRadius = 2
            dot.shadowOffset = .zero

            return dot
        case .turn:
            let ring = disc(7, at: centre, fill: CGColor.clear)

            ring.borderWidth = 1.5
            ring.borderColor = EdgeStyle.ink

            return ring
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

    private func disc(_ size: CGFloat, at centre: CGPoint, fill: CGColor) -> CALayer {
        let dot = CALayer()

        dot.frame = CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)
        dot.cornerRadius = size / 2
        dot.backgroundColor = fill

        return dot
    }
}
