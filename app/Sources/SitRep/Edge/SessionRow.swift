import AppKit
import SitRepPanel

/// One session's row in black, as the prototype draws it: its mark; its title, its subject in mono after it and a
/// question's "+2"; its project and session beneath, or for an away one why a click does nothing; its time at the
/// right; the lift under the pointer, and a new row's wash. A working row's arc turns and its lead shimmers, its
/// subject still, in the render server.
@MainActor
final class SessionRow {
    /// The row's box: the item less the gap below it.
    let layer = CALayer()
    let session: Session

    private let at: SessionRowLayout
    private let wash = CALayer()
    private var age: TextLine?
    private var ageText = ""

    init(_ session: Session, size: CGSize) {
        self.session = session
        at = SessionRowLayout(size: size)
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
        title().forEach(layer.addSublayer)
        layer.addSublayer(TextLine(TextLine.text(session.line2, EdgeStyle.sub, subColour), in: at.sub))
    }

    /// Under the pointer, a row that jumps lifts.
    var isHighlighted = false {
        didSet {
            layer.backgroundColor = isHighlighted && session.jumps ? EdgeStyle.hover : nil
        }
    }

    /// Its time at this moment on the wall clock, ms, drawn again only when it reads differently.
    func showAge(at now: Double) {
        let text = session.ageText(at: now)

        guard text != ageText else {
            return
        }

        let line = TextLine(TextLine.text(text, EdgeStyle.age, EdgeStyle.ink3), in: at.age, alignment: .right)

        line.contentsScale = layer.contentsScale
        if let age {
            layer.replaceSublayer(age, with: line)
        } else {
            layer.addSublayer(line)
        }
        age = line
        ageText = text
    }

    /// New on the board while the panel is out: washed orange (`Wash`).
    func washes() {
        let fade = CAKeyframeAnimation(keyPath: "opacity")

        fade.values = [1, 1, 0]
        fade.keyTimes = [0, NSNumber(value: Wash.held / Wash.length), 1]
        fade.timingFunctions = [CAMediaTimingFunction(name: .linear), CAMediaTimingFunction(name: .easeInEaseOut)]
        fade.duration = Wash.length / 1000
        wash.add(fade, forKey: "wash")
    }

    private var isWorking: Bool { session.kind == .working }

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
    /// its subject left still.
    private func titleLine(in box: CGRect) -> (layer: CALayer, width: CGFloat) {
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

    /// Needs you an orange dot with its glow, away or not; your turn an open white ring; working the arc turning.
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
            let arc = Arc(from: -0.75 * .pi)

            arc.fit(CGRect(x: centre.x - 5.5, y: centre.y - 5.5, width: 11, height: 11))
            arc.track.strokeColor = EdgeStyle.track
            arc.arc.strokeColor = EdgeStyle.ink
            arc.turn(every: 1)

            return arc.layer
        }
    }

    private func disc(_ size: CGFloat, at centre: CGPoint, fill: CGColor) -> CALayer {
        let dot = CALayer()

        dot.frame = CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)
        dot.cornerRadius = size / 2
        dot.backgroundColor = fill

        return dot
    }
}
