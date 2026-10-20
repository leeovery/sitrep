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
    private let ring = CALayer()
    private let spinner = Arc(line: StripMarkLayer.line)
    private var letters: TextLine?
    private var look: Look?

    private static let size = StripFrame.Mark.size, line = 1.5
    /// The panel dot's glow: 9 across, at 0.45.
    private static let blur = 9.0, glowAlpha = 0.45
    /// A new mark's ring at its brightest flash.
    static let flashed = LiveLight.RGB(r: 255, g: 160, b: 120)

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

        if look != self.look {
            restyle(look, eased: self.look != nil)
        }
        if mark.wash > 0 || mark.flash > 0 {
            return arrive(wash: mark.wash, flash: mark.flash)
        }

        if glow.shadowRadius != Self.blur / 2 || ring.borderWidth != Self.line {
            restyle(look, eased: false)
        }
        // the lift as the frame has it, eased by the model: set with no animation of its own, so nothing restarts it
        ring.backgroundColor = look.jumping ? EdgeStyle.press : EdgeStyle.hover.copy(alpha: mark.lift)
    }

    private func restyle(_ look: Look, eased: Bool) {
        let kind = look.kind
        let glows = !look.jumping && [.needs, .away, .needsCount].contains(kind)

        CATransaction.begin()
        CATransaction.setDisableActions(!eased)
        CATransaction.setAnimationDuration(0.24)
        ring.borderWidth = Self.line
        ring.borderColor = look.jumping ? EdgeStyle.track : Self.ringColour(kind)
        glow.shadowPath = CGPath(ellipseIn: glow.bounds, transform: nil)
        glow.shadowRadius = Self.blur / 2
        glow.shadowOpacity = glows ? Float(Self.glowAlpha) : 0
        spinner.layer.opacity = kind == .working || look.jumping ? 1 : 0
        spinner.track.strokeColor = look.jumping ? nil : EdgeStyle.track
        spinner.arc.strokeColor = look.jumping && kind == .needs ? EdgeStyle.orange
            : look.jumping && kind == .turn ? EdgeStyle.ink : EdgeStyle.arc
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
