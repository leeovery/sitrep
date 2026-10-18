import AppKit
import SitRepPanel

/// A tab's words, laid out once as the prototype's `.tl` lays them out: a session's panel row (its title, its project
/// and work, or why an away ask's takes no click, and its age at the right), or the count's rows. Each frame sets only
/// their opacity, their slide along the strip, and a click pressing them in.
@MainActor
final class StripWordsLayer {
    let layer = CALayer()

    /// What presses in: the row, scaled from its edge.
    private let content = CALayer()
    private let age = CALayer()
    private let spinner = CALayer()
    /// The count's rows, by session.
    private var rows: [String: CALayer] = [:]
    private var pressed = false
    private var hovered: String?

    private static let pad = StripRowLayout.pad, gap = StripRowLayout.gap, ageMin = 18.0

    init(_ words: StripFrame.Words, now: Double) {
        let size = words.frame.size

        layer.frame = words.frame
        layer.masksToBounds = true
        content.anchorPoint = CGPoint(x: 0, y: 0.5)
        content.frame = CGRect(origin: .zero, size: size)
        layer.addSublayer(content)
        switch words.content {
        case let .row(session): lay(session, in: size, now: now)
        case let .rows(sessions): lay(sessions, width: size.width)
        }
    }

    func show(_ words: StripFrame.Words, hover: String?) {
        layer.opacity = Float(words.alpha)
        layer.transform = CATransform3DMakeTranslation(0, words.dy, 0)
        if words.isPressed != pressed {
            pressed = words.isPressed
            press(content)
            age.isHidden = pressed
            spinner.isHidden = !pressed
        }
        let lit = words.pressedRow ?? hover
        if lit != hovered {
            light(lit, pressed: words.pressedRow != nil)
        }
    }

    /// As wide as the words need, before the tab's slack: a session's row, or the widest of the count's rows.
    static let measure = StripMeasure(
        row: { session in
            MainActor.assumeIsolated {
                let words = max(width(title(session)), width(sub(session)))
                return pad.left + words + gap + ageWidth(session, at: StripWordsLayer.now) + pad.right
            }
        },
        rows: { sessions in
            MainActor.assumeIsolated {
                pad.left + (sessions.map { max(width(rowTitle($0)), width(rowSub($0))) }.max() ?? 0) + pad.right
            }
        }
    )

    /// The wall clock, ms, as the sessions' times are.
    static var now: Double { Date().timeIntervalSince1970 * 1000 }

    // MARK: A session's row

    private func lay(_ session: StripSession, in size: CGSize, now: Double) {
        let at = StripRowLayout(session, in: size, now: now)

        if session.kind == .working {
            let shimmer = Shimmer(
                grey: Self.title(session, PanelStyle.shim), lit: Self.title(session, PanelStyle.ink), in: at.title
            )
            shimmer.band.add(shimmer.sweep, forKey: "sweep")
            content.addSublayer(shimmer.layer)
        } else {
            content.addSublayer(TextLine(Self.title(session), in: at.title))
        }
        content.addSublayer(TextLine(Self.sub(session), in: at.sub))

        age.frame = at.age
        age.addSublayer(TextLine(
            Self.ageText(session, at: now), in: CGRect(origin: .zero, size: age.frame.size), alignment: .right
        ))
        content.addSublayer(age)
        lay(spinner: at.spinner)
    }

    /// The age's spinner while a click jumps: an 11pt ring in the track's grey, its top quarter in ink, turning once a
    /// second.
    private func lay(spinner box: CGRect) {
        let line = 1.5, inset = CGRect(origin: .zero, size: box.size).insetBy(dx: line / 2, dy: line / 2)
        let ring = CAShapeLayer(), top = CAShapeLayer(), arc = CGMutablePath()
        arc.addArc(
            center: CGPoint(x: box.width / 2, y: box.height / 2), radius: inset.width / 2, startAngle: -0.75 * .pi,
            endAngle: -0.25 * .pi, clockwise: false
        )
        let parts = [(ring, CGPath(ellipseIn: inset, transform: nil), PanelStyle.track), (top, arc, PanelStyle.ink)]
        for (shape, path, colour) in parts {
            shape.frame = CGRect(origin: .zero, size: box.size)
            shape.path = path
            shape.fillColor = nil
            shape.strokeColor = colour
            shape.lineWidth = line
            spinner.addSublayer(shape)
        }
        spinner.frame = box
        spinner.isHidden = true
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = 0
        turn.toValue = 2 * Double.pi
        turn.duration = 1
        turn.repeatCount = .infinity
        spinner.add(turn, forKey: "spin")
        content.addSublayer(spinner)
    }

    // MARK: The count's rows

    private func lay(_ sessions: [StripSession], width: Double) {
        for (i, session) in sessions.enumerated() {
            let at = StripRowsLayout(i, width: width), box = CALayer()
            box.frame = at.box
            box.cornerRadius = 10
            box.addSublayer(TextLine(Self.rowTitle(session), in: at.title))
            box.addSublayer(TextLine(Self.rowSub(session), in: at.sub))
            content.addSublayer(box)
            rows[session.id] = box
        }
    }

    /// The count's row under the pointer lifts; one a click jumps from presses in.
    private func light(_ id: String?, pressed: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.11)
        if let hovered, let row = rows[hovered] {
            row.backgroundColor = nil
            row.transform = CATransform3DIdentity
        }
        if let id, let row = rows[id] {
            row.backgroundColor = pressed ? PanelStyle.press : PanelStyle.hover
            if pressed {
                row.transform = CATransform3DMakeScale(0.985, 0.985, 1)
            }
        }
        CATransaction.commit()
        hovered = id
    }

    /// Pressed in, the words scale to 0.985 from their edge over 140ms, and back.
    private func press(_ layer: CALayer) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.14)
        layer.transform = pressed ? CATransform3DMakeScale(0.985, 0.985, 1) : CATransform3DIdentity
        CATransaction.commit()
    }

    // MARK: The words

    private static func title(_ s: StripSession, _ colour: CGColor? = nil) -> NSAttributedString {
        let font = s.kind == .needs ? PanelStyle.needsTitle : PanelStyle.title
        let ink = colour ?? (s.away ? PanelStyle.quiet : PanelStyle.ink)
        let text = TextLine.text(s.title, font, ink, kern: PanelStyle.tightKern(font))
        if let code = s.code {
            text.append(TextLine.text(code, PanelStyle.code, ink))
        }
        if let more = s.more {
            text.addAttribute(.kern, value: 6, range: NSRange(location: text.length - 1, length: 1))
            text.append(TextLine.text("+\(more)", PanelStyle.title, PanelStyle.ink3))
        }
        return text
    }

    private static func sub(_ s: StripSession) -> NSAttributedString {
        TextLine.text(s.line2, PanelStyle.sub, PanelStyle.ink2)
    }

    private static func ageText(_ s: StripSession, at now: Double) -> NSAttributedString {
        TextLine.text(Session.ageText(now - s.since), PanelStyle.age, PanelStyle.ink3)
    }

    static func ageWidth(_ s: StripSession, at now: Double) -> Double {
        max(ageMin, width(ageText(s, at: now)))
    }

    private static func rowTitle(_ s: StripSession) -> NSAttributedString {
        let text = TextLine.text(s.title, PanelStyle.rowTitle, s.kind == .turn ? PanelStyle.ink : PanelStyle.grey)
        if let code = s.code {
            text.append(TextLine.text(code, PanelStyle.code, s.kind == .turn ? PanelStyle.ink : PanelStyle.grey))
        }
        return text
    }

    private static func rowSub(_ s: StripSession) -> NSAttributedString {
        TextLine.text(s.sub, PanelStyle.rowSub, PanelStyle.ink2)
    }

    private static func width(_ text: NSAttributedString) -> Double {
        CTLineGetTypographicBounds(CTLineCreateWithAttributedString(text), nil, nil, nil)
    }
}
