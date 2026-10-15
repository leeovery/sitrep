import AppKit
import SitRepPanel

/// One session's row as the prototype draws it: its mark, its title (with an inline code span where it has one)
/// and its project and work beneath, its age at the right, and the highlight under the pointer. A working row's
/// arc spins and its title shimmers, while the panel is out.
@MainActor
final class SessionRow {
    /// The row's box: the item less the gap below it.
    let layer = CALayer()

    private let jumps: Bool
    /// The row's own motion, running only while the panel shows it.
    private var motions: [(layer: CALayer, animation: CAAnimation)] = []

    private static let pad = (top: 10.0, side: 10.0), gap = 10.0
    private static let markBox = CGSize(width: 12, height: 18), ageWidth = 36.0
    private static let titleLine = 18.0, subLine = 16.0

    init(_ session: Session, size: CGSize) {
        jumps = session.jumps
        layer.frame = CGRect(origin: .zero, size: size)
        layer.cornerRadius = 14

        let textX = Self.pad.side + Self.markBox.width + Self.gap
        let textWidth = size.width - textX - Self.gap - Self.ageWidth - Self.pad.side
        let titleBox = CGRect(x: textX, y: Self.pad.top, width: textWidth, height: Self.titleLine)
        let subBox = CGRect(x: textX, y: titleBox.maxY, width: textWidth, height: Self.subLine)
        let ageBox = CGRect(
            x: size.width - Self.pad.side - Self.ageWidth, y: Self.pad.top, width: Self.ageWidth, height: Self.titleLine
        )
        let markCentre = CGPoint(x: Self.pad.side + Self.markBox.width / 2, y: Self.pad.top + Self.markBox.height / 2)

        layer.addSublayer(mark(session.kind, at: markCentre))
        layer.addSublayer(title(session, in: titleBox))
        layer.addSublayer(TextLine(TextLine.text(session.sub, PanelStyle.sub, PanelStyle.ink2), in: subBox))
        layer.addSublayer(TextLine(
            TextLine.text(session.ageText, PanelStyle.age, PanelStyle.ink3), in: ageBox, alignment: .right
        ))
    }

    /// Under the pointer, a row that jumps lights up.
    var isHighlighted = false {
        didSet {
            layer.backgroundColor = isHighlighted && jumps ? PanelStyle.hover : nil
        }
    }

    func startMotion() {
        for (index, motion) in motions.enumerated() {
            motion.layer.add(motion.animation, forKey: "motion\(index)")
        }
    }

    func stopMotion() {
        motions.forEach { $0.layer.removeAllAnimations() }
    }

    private func title(_ session: Session, in box: CGRect) -> CALayer {
        switch session.kind {
        case .working: shimmering(session, in: box)
        case .quiet: TextLine(titleText(session, PanelStyle.quiet), in: box)
        case .off: TextLine(titleText(session, PanelStyle.off), in: box)
        case .needs, .turn: TextLine(titleText(session, PanelStyle.ink), in: box)
        }
    }

    private func titleText(_ session: Session, _ colour: CGColor) -> NSAttributedString {
        let font = session.kind == .needs ? PanelStyle.needsTitle : PanelStyle.title
        let text = TextLine.text(session.title, font, colour, kern: PanelStyle.tightKern(font))

        if let code = session.code {
            text.append(TextLine.text(code, PanelStyle.code, colour))
        }

        return text
    }

    /// A working title, as the prototype's shimmer: grey, with a light sweeping along it every 2.5s. The light is
    /// the title again in ink, shown through a band of a gradient three times its width, so it rises from the grey
    /// and falls back into it as the prototype's background gradient does; only the gradient moves.
    private func shimmering(_ session: Session, in box: CGRect) -> CALayer {
        let holder = CALayer()
        let grey = TextLine(titleText(session, PanelStyle.shim), in: box.offsetBy(dx: -box.minX, dy: -box.minY))
        let lit = TextLine(titleText(session, PanelStyle.ink), in: box.offsetBy(dx: -box.minX, dy: -box.minY))
        let band = CAGradientLayer()
        let width = box.width

        holder.frame = box
        band.colors = [CGColor.clear, CGColor.clear, PanelStyle.black, CGColor.clear, CGColor.clear]
        band.locations = [0, 0.36, 0.5, 0.64, 1]
        band.startPoint = CGPoint(x: 0, y: 0.5)
        band.endPoint = CGPoint(x: 1, y: 0.5)
        band.frame = CGRect(x: -2 * width, y: 0, width: 3 * width, height: lit.bounds.height)
        lit.mask = band
        holder.addSublayer(grey)
        holder.addSublayer(lit)

        let across = CABasicAnimation(keyPath: "position.x")
        across.fromValue = -0.5 * width
        across.toValue = 1.5 * width
        across.duration = 2.5
        across.repeatCount = .infinity
        motions.append((band, across))

        return holder
    }

    private func mark(_ kind: Session.Kind, at centre: CGPoint) -> CALayer {
        switch kind {
        case .needs:
            let dot = disc(7, at: centre, fill: PanelStyle.orange)

            dot.shadowColor = PanelStyle.orange
            dot.shadowOpacity = 0.75
            dot.shadowRadius = 2
            dot.shadowOffset = .zero

            return dot
        case .turn:
            return ring(7, 1.5, at: centre, PanelStyle.ink)
        case .working:
            return arc(at: centre)
        case .quiet:
            return disc(5, at: centre, fill: PanelStyle.mark)
        case .off:
            return ring(5, 1, at: centre, PanelStyle.mark)
        }
    }

    private func disc(_ size: CGFloat, at centre: CGPoint, fill: CGColor) -> CALayer {
        let dot = CALayer()

        dot.frame = CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)
        dot.cornerRadius = size / 2
        dot.backgroundColor = fill

        return dot
    }

    private func ring(_ size: CGFloat, _ border: CGFloat, at centre: CGPoint, _ colour: CGColor) -> CALayer {
        let ring = disc(size, at: centre, fill: CGColor.clear)

        ring.borderWidth = border
        ring.borderColor = colour

        return ring
    }

    /// The working mark: an 11-point ring in the track's grey, its top quarter in ink, spinning once a second.
    private func arc(at centre: CGPoint) -> CALayer {
        let size = 11.0, line = 1.5
        let spinner = CALayer()
        let middle = CGPoint(x: size / 2, y: size / 2), radius = (size - line) / 2
        let track = CGMutablePath(), top = CGMutablePath()

        spinner.frame = CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)
        track.addEllipse(in: CGRect(x: line / 2, y: line / 2, width: size - line, height: size - line))
        top.addArc(center: middle, radius: radius, startAngle: -0.75 * .pi, endAngle: -0.25 * .pi, clockwise: false)
        spinner.addSublayer(stroke(track, PanelStyle.track, line, in: spinner.bounds))
        spinner.addSublayer(stroke(top, PanelStyle.ink, line, in: spinner.bounds))

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = 1
        spin.repeatCount = .infinity
        motions.append((spinner, spin))

        return spinner
    }

    private func stroke(_ path: CGPath, _ colour: CGColor, _ width: CGFloat, in frame: CGRect) -> CAShapeLayer {
        let shape = CAShapeLayer()

        shape.frame = frame
        shape.path = path
        shape.fillColor = nil
        shape.strokeColor = colour
        shape.lineWidth = width

        return shape
    }
}
