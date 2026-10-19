import AppKit
import SitRepPanel

/// One mark on the strip, drawn as the prototype's `.mk`: the project's letters in a 24pt ring whose colour carries
/// the state, a glow outside it while it needs Lee, the working arc turning round it, lifted under the pointer, and
/// pressed in with its arc turning while a click on it jumps. Just arrived, it is washed orange and its ring flashes,
/// and its lift eases as the model eases it, a frame at a time; any other change of look eases over 240ms, as the
/// prototype's transitions do.
@MainActor
final class StripMarkLayer {
    let layer = CALayer()

    private let glow = CALayer()
    private let ring = CALayer()
    private let spinner = CALayer()
    private let track = CAShapeLayer()
    private let arc = CAShapeLayer()
    private var letters: TextLine?
    private var look: Look?

    private static let size = StripFrame.Mark.size, line = 1.5
    /// The panel dot's glow: 9 across, at 0.45.
    private static let blur = 9.0, glowAlpha = 0.45
    /// A new mark's ring at its brightest flash.
    private static let flashed = LiveLight.RGB(r: 255, g: 160, b: 120)

    init() {
        let box = CGRect(x: 0, y: 0, width: Self.size, height: Self.size)

        layer.bounds = box
        glow.frame = box
        glow.shadowOffset = .zero
        glow.shadowColor = PanelStyle.orange
        let outside = CALayer()
        outside.frame = box
        outside.mask = Self.outside(box)
        outside.addSublayer(glow)
        ring.frame = box
        ring.cornerRadius = Self.size / 2
        spinner.frame = box
        for (shape, path) in [(track, Self.circle()), (arc, Self.quarter())] {
            shape.frame = box
            shape.path = path
            shape.fillColor = nil
            shape.lineWidth = Self.line
            shape.lineCap = .round
            spinner.addSublayer(shape)
        }
        layer.addSublayer(outside)
        layer.addSublayer(ring)
        layer.addSublayer(spinner)
    }

    /// What the mark looks like, short of its place, its lift and its arrival.
    private struct Look: Equatable {
        let kind: StripFrame.Mark.Look
        let text: String
        let jumping: Bool
    }

    func show(_ mark: StripFrame.Mark) {
        layer.position = mark.centre
        layer.transform = CATransform3DMakeScale(mark.scale, mark.scale, 1)
        layer.opacity = Float(mark.alpha)

        let look = Look(kind: mark.look, text: mark.text, jumping: mark.isJumping)
        if look != self.look {
            restyle(look, eased: self.look != nil)
        }
        if mark.wash > 0 || mark.flash > 0 {
            return arrive(wash: mark.wash, flash: mark.flash)
        }

        if glow.shadowRadius != Self.blur / 2 || ring.borderWidth != Self.line {
            restyle(look, eased: false)
        }
        // the lift as the frame has it, eased by the model: set with no animation of its own, nothing restarts it
        ring.backgroundColor = look.jumping ? PanelStyle.press : PanelStyle.hover.copy(alpha: mark.lift)
    }

    private func restyle(_ look: Look, eased: Bool) {
        let kind = look.kind
        CATransaction.begin()
        CATransaction.setDisableActions(!eased)
        CATransaction.setAnimationDuration(0.24)
        ring.borderWidth = Self.line
        ring.borderColor = look.jumping ? PanelStyle.track : Self.ringColour(kind)
        let glows = !look.jumping && (kind == .needs || kind == .away)
        glow.shadowPath = CGPath(ellipseIn: glow.bounds, transform: nil)
        glow.shadowRadius = Self.blur / 2
        glow.shadowOpacity = glows ? Float(Self.glowAlpha) : 0
        spinner.opacity = kind == .working || look.jumping ? 1 : 0
        track.strokeColor = look.jumping ? nil : PanelStyle.track
        arc.strokeColor = look.jumping && kind == .needs ? PanelStyle.orange
            : look.jumping && kind == .turn ? PanelStyle.ink : PanelStyle.arc
        CATransaction.commit()

        if look.text != self.look?.text || kind != self.look?.kind {
            setLetters(look.text, Self.letterColour(kind))
        }
        if look.jumping != self.look?.jumping || spinner.animation(forKey: "spin") == nil {
            spin(look.jumping ? 0.9 : 1.2)
        }
        self.look = look
    }

    /// Washed orange inside the ring and its glow brighter, for two seconds, the ring flashing: set each frame.
    private func arrive(wash: Double, flash: Double) {
        ring.backgroundColor = PanelStyle.color(LiveLight.orange, alpha: 0.2 * wash)
        ring.borderWidth = Self.line + 1.1 * flash
        ring.borderColor = PanelStyle.color(LiveLight.orange.mix(Self.flashed, flash))
        let spread = wash + 1.5 * flash
        glow.shadowPath = CGPath(ellipseIn: glow.bounds.insetBy(dx: -spread, dy: -spread), transform: nil)
        glow.shadowRadius = (Self.blur + 3 * wash + 7 * flash) / 2
        glow.shadowOpacity = Float(Self.glowAlpha + 0.2 * wash + 0.3 * flash)
    }

    private func setLetters(_ text: String, _ colour: CGColor) {
        let font = PanelStyle.letters
        let string = TextLine.text(text, font, colour, kern: 0.01 * font.pointSize)
        let width = CTLineGetTypographicBounds(CTLineCreateWithAttributedString(string), nil, nil, nil).rounded(.up) + 1
        let height = 12.0
        let line = TextLine(
            string, in: CGRect(x: (Self.size - width) / 2, y: (Self.size - height) / 2, width: width, height: height)
        )

        line.contentsScale = layer.contentsScale
        letters?.removeFromSuperlayer()
        layer.addSublayer(line)
        letters = line
    }

    /// The arc turns once in this many seconds, from a phase of its own.
    private func spin(_ seconds: Double) {
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = 0
        turn.toValue = 2 * Double.pi
        turn.duration = seconds
        turn.repeatCount = .infinity
        turn.timeOffset = Double.random(in: 0 ..< seconds)
        spinner.add(turn, forKey: "spin")
    }

    private static func ringColour(_ kind: StripFrame.Mark.Look) -> CGColor? {
        switch kind {
        case .needs, .away: PanelStyle.orange
        case .turn: PanelStyle.ink
        case .working: nil
        case .count: PanelStyle.track
        }
    }

    private static func letterColour(_ kind: StripFrame.Mark.Look) -> CGColor {
        switch kind {
        case .needs, .turn: PanelStyle.ink
        case .away: PanelStyle.ink3
        case .working: PanelStyle.grey
        case .count: PanelStyle.ink2
        }
    }

    private static func circle() -> CGPath {
        let r = (size - line) / 2
        return CGPath(ellipseIn: CGRect(x: size / 2 - r, y: size / 2 - r, width: 2 * r, height: 2 * r), transform: nil)
    }

    /// The arc: the ring's top-right quarter, from its top round to its right.
    private static func quarter() -> CGPath {
        let path = CGMutablePath()
        path.addArc(
            center: CGPoint(x: size / 2, y: size / 2), radius: (size - line) / 2, startAngle: -.pi / 2, endAngle: 0,
            clockwise: false
        )
        return path
    }

    /// Everything round the ring and none of it inside, so the glow shows only outside it, as a box-shadow does.
    private static func outside(_ box: CGRect) -> CAShapeLayer {
        let mask = CAShapeLayer(), path = CGMutablePath()
        mask.frame = box
        path.addRect(box.insetBy(dx: -30, dy: -30))
        path.addEllipse(in: box)
        mask.path = path
        mask.fillRule = .evenOdd
        return mask
    }
}
