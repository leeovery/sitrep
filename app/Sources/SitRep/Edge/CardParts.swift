import AppKit
import SitRepPanel

/// The card's parts beside its rows, in black, as Paper's board D draws them: a section's eyebrow, and Your turn's "N
/// earlier". Each is drawn once, in a box the size of what its item draws.
@MainActor
enum CardParts {
    /// An eyebrow: its name in white at 55%, its count 6 after it, in orange for Needs you and white at 30% for the
    /// rest, and its chevron, down while the section is open and right while it is folded.
    static func eyebrow(_ eyebrow: Eyebrow, size: CGSize) -> CALayer {
        let layer = CALayer(), box = EyebrowLayout.label(in: size)
        let font = EdgeStyle.eyebrowTitle
        let name = TextLine(TextLine.text(eyebrow.section.title, font, EdgeStyle.eyebrow), in: box)
        let ink = eyebrow.section == .needsYou ? EdgeStyle.orange : EdgeStyle.eyebrowCount
        let after = CGRect(x: box.minX + name.width + EyebrowLayout.gap, y: box.minY, width: 40, height: box.height)

        layer.frame = CGRect(origin: .zero, size: size)
        layer.addSublayer(name)
        layer.addSublayer(TextLine(TextLine.text("\(eyebrow.count)", EdgeStyle.eyebrowFigures, ink), in: after))
        layer.addSublayer(chevron(isOpen: !eyebrow.isFolded, in: EyebrowLayout.chevron(in: size)))

        return layer
    }

    /// "N earlier": its ring at white 35%, "8 earlier" in the soft grey, the projects faint after it, cut short, and
    /// its chevron, right while it is folded and down while it is open; on a box that lifts as a row does.
    static func earlier(_ earlier: Earlier, size: CGSize) -> EarlierLine {
        let line = EarlierLine(), layer = line.layer, box = EarlierLayout.words(in: size)
        let font = EdgeStyle.line
        let words = TextLine.text(earlier.title, font, EdgeStyle.ink2, kern: EdgeStyle.tightKern(font))
        let title = TextLine(words, in: box)
        let projects = TextLine.text(earlier.projects.joined(separator: ", "), EdgeStyle.sub, EdgeStyle.ink3)
        let x = box.minX + title.width + EarlierLayout.gap
        let drop = TextLine.drop(of: EdgeStyle.sub, to: font, lineHeight: box.height)

        layer.frame = CGRect(origin: .zero, size: size)
        layer.cornerRadius = SessionRowLayout.turnRadius
        layer.addSublayer(SessionRow.ring(9, at: EarlierLayout.mark(in: size), colour: EdgeStyle.earlierRing))
        layer.addSublayer(title)
        layer.addSublayer(TextLine(
            projects, in: CGRect(x: x, y: box.minY + drop, width: max(0, box.maxX - x), height: box.height)
        ))
        layer.addSublayer(chevron(isOpen: earlier.isOpen, in: EarlierLayout.chevron(in: size)))

        return line
    }

    private static func chevron(isOpen: Bool, in box: CGRect) -> CAShapeLayer {
        let chevron = CAShapeLayer()

        chevron.frame = box
        chevron.path = CardChevron.path(isOpen: isOpen)
        chevron.fillColor = nil
        chevron.strokeColor = EdgeStyle.chevron
        chevron.lineWidth = CardChevron.stroke
        chevron.lineCap = .round
        chevron.lineJoin = .round

        return chevron
    }
}

/// What lifts under the pointer on the black card: a row, or "N earlier".
@MainActor
protocol Lifting: AnyObject {
    var isHighlighted: Bool { get set }
}

extension SessionRow: Lifting {}

/// "N earlier" in black, which lifts under the pointer as a row does.
@MainActor
final class EarlierLine: Lifting {
    let layer = CALayer()

    var isHighlighted = false {
        didSet {
            layer.backgroundColor = isHighlighted ? EdgeStyle.hover : nil
        }
    }
}
