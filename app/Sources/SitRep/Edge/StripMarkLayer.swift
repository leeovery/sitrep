import AppKit
import SitRepPanel

/// One mark on the strip in black, drawn as the prototype's `.mk`: the project's letters in a 24pt ring whose colour
/// carries the state, a glow outside it while it needs Lee, the working arc turning round it, lifted under the
/// pointer, and pressed in with its arc turning while a click on it jumps. Just arrived, it is washed orange and its
/// ring flashes, and its lift eases as the model eases it, a frame at a time; any other change of look eases over
/// 240ms, as the prototype's transitions do.
@MainActor
final class StripMarkLayer {
    let layer = CALayer()

    private let glow = CALayer()
    /// The ring: internal only for the tests, which read its fill's ease.
    let ring = CALayer()
    /// The arc: internal only for the tests, which read its fade.
    let spinner = Arc(line: StripMarkLayer.line)
    private var letters: TextLine?
    private var look: Look?

    private static let size = StripFrame.Mark.size, line = 1.5
    /// The panel dot's glow: 9 across, at 0.45.
    private static let blur = 9.0, glowAlpha = 0.45
    /// A new mark's ring at its brightest flash.
    static let flashed = LiveLight.RGB(r: 255, g: 160, b: 120)

    /// How long a change of look eases, in seconds, the ring's colour and its glow, as the prototype's `.mk`
    /// transitions do; and the pressed fill, as its background's.
    static let lookEase = 0.24, pressEase = 0.11

    /// How long the arc takes to fade, in seconds: in over 60ms as a click's jump starts, as the prototype's
    /// `.mk.jumping .arc` has it, so a quick answer still shows it; otherwise over the mark's 240.
    static func arcFade(jumping: Bool) -> Double {
        jumping ? 0.06 : lookEase
    }

    init() {
        let box = CGRect(x: 0, y: 0, width: Self.size, height: Self.size)
        let outside = CALayer()

        layer.bounds = box
        glow.frame = box
        glow.shadowOffset = .zero
        glow.shadowColor = EdgeStyle.orange
        outside.frame = box
        outside.mask = Self.outside(box)
        outside.addSublayer(glow)
        ring.frame = box
        ring.cornerRadius = Self.size / 2
        spinner.fit(box)
        layer.addSublayer(outside)
        layer.addSublayer(ring)
        layer.addSublayer(spinner.layer)
    }

    /// What the mark looks like, short of its place, its lift and its arrival.
    private struct Look: Equatable {
        let kind: StripFrame.Mark.Look
        let text: String
        let jumping: Bool
    }

    /// The mark as the frame has it, centred here in the window.
    func show(_ mark: StripFrame.Mark, at centre: CGPoint) {
        layer.position = centre
        layer.transform = CATransform3DMakeScale(mark.scale, mark.scale, 1)
        layer.opacity = Float(mark.alpha)

        let look = Look(kind: mark.look, text: mark.text, jumping: mark.isJumping)
        let presses = self.look.map { $0.jumping != look.jumping } ?? false

        if look != self.look {
            restyle(look, eased: self.look != nil)
        }
        if mark.wash > 0 || mark.flash > 0 {
            return arrive(wash: mark.wash, flash: mark.flash)
        }

        if glow.shadowRadius != Self.blur / 2 || ring.borderWidth != Self.line {
            restyle(look, eased: false)
        }
        // pressed in or let out, the fill eases over 110ms, as the prototype's background does; otherwise it is the
        // lift as the frame has it, eased by the model: set with no animation of its own, so nothing restarts it
        CATransaction.begin()
        CATransaction.setDisableActions(!presses)
        CATransaction.setAnimationDuration(Self.pressEase)
        ring.backgroundColor = look.jumping ? EdgeStyle.press : EdgeStyle.hover.copy(alpha: mark.lift)
        CATransaction.commit()
    }

    private func restyle(_ look: Look, eased: Bool) {
        let kind = look.kind
        let glows = !look.jumping && [.needs, .away, .needsCount].contains(kind)

        CATransaction.begin()
        CATransaction.setDisableActions(!eased)
        CATransaction.setAnimationDuration(Self.lookEase)
        ring.borderWidth = Self.line
        ring.borderColor = look.jumping ? EdgeStyle.track : Self.ringColour(kind)
        glow.shadowPath = CGPath(ellipseIn: glow.bounds, transform: nil)
        glow.shadowRadius = Self.blur / 2
        glow.shadowOpacity = glows ? Float(Self.glowAlpha) : 0
        spinner.track.strokeColor = look.jumping ? nil : EdgeStyle.track
        spinner.arc.strokeColor = look.jumping && kind == .needs ? EdgeStyle.orange
            : look.jumping && kind == .turn ? EdgeStyle.ink : EdgeStyle.arc
        CATransaction.commit()

        CATransaction.begin()
        CATransaction.setDisableActions(!eased)
        CATransaction.setAnimationDuration(Self.arcFade(jumping: look.jumping))
        spinner.layer.opacity = kind == .working || look.jumping ? 1 : 0
        CATransaction.commit()

        if look.text != self.look?.text || kind != self.look?.kind {
            setLetters(look.text, Self.letterColour(kind))
        }
        spinner.turn(every: look.jumping ? 0.9 : 1.2)
        self.look = look
    }

    /// Washed orange inside the ring and its glow brighter, for two seconds, the ring flashing: set each frame.
    private func arrive(wash: Double, flash: Double) {
        let spread = wash + 1.5 * flash

        ring.backgroundColor = EdgeStyle.color(LiveLight.orange, alpha: 0.2 * wash)
        ring.borderWidth = Self.line + 1.1 * flash
        ring.borderColor = EdgeStyle.color(LiveLight.orange.mix(Self.flashed, flash))
        glow.shadowPath = CGPath(ellipseIn: glow.bounds.insetBy(dx: -spread, dy: -spread), transform: nil)
        glow.shadowRadius = (Self.blur + 3 * wash + 7 * flash) / 2
        glow.shadowOpacity = Float(Self.glowAlpha + 0.2 * wash + 0.3 * flash)
    }

    private func setLetters(_ text: String, _ colour: CGColor) {
        let font = EdgeStyle.letters
        let string = TextLine.text(text, font, colour, kern: 0.01 * font.pointSize)
        let width = TextLine.width(string).rounded(.up) + 1, height = 12.0
        let line = TextLine(
            string, in: CGRect(x: (Self.size - width) / 2, y: (Self.size - height) / 2, width: width, height: height)
        )

        line.contentsScale = layer.contentsScale
        letters?.removeFromSuperlayer()
        layer.addSublayer(line)
        letters = line
    }

    private static func ringColour(_ kind: StripFrame.Mark.Look) -> CGColor? {
        switch kind {
        case .needs, .away, .needsCount: EdgeStyle.orange
        case .turn: EdgeStyle.ink
        case .working: nil
        case .count: EdgeStyle.track
        }
    }

    private static func letterColour(_ kind: StripFrame.Mark.Look) -> CGColor {
        switch kind {
        case .needs, .turn, .needsCount: EdgeStyle.ink
        case .away: EdgeStyle.ink3
        case .working: EdgeStyle.grey
        case .count: EdgeStyle.ink2
        }
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
