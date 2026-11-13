import AppKit
import SitRepPanel

/// The card's parts beside its rows, in black, as Paper's board D draws them: a section's eyebrow, drawn once, in a box
/// the size of what its item draws.
@MainActor
enum CardParts {
    /// An eyebrow: its name in white at 55%, its count 6 after it, in orange for Needs you, the faint grey for Snoozed
    /// (board G) and white at 30% for the rest, and its chevron, down while the section is open and right while it is
    /// folded.
    static func eyebrow(_ eyebrow: Eyebrow, size: CGSize) -> CALayer {
        let layer = CALayer(), box = EyebrowLayout.label(in: size)
        let font = EdgeStyle.eyebrowTitle
        let name = TextLine(TextLine.text(eyebrow.section.title, font, EdgeStyle.eyebrow), in: box)
        let ink = switch eyebrow.section {
        case .needsYou: EdgeStyle.orange
        case .snoozed: EdgeStyle.ink3
        case .working: EdgeStyle.eyebrowCount
        }
        let after = CGRect(x: box.minX + name.width + EyebrowLayout.gap, y: box.minY, width: 40, height: box.height)

        layer.frame = CGRect(origin: .zero, size: size)
        layer.addSublayer(name)
        layer.addSublayer(TextLine(TextLine.text("\(eyebrow.count)", EdgeStyle.eyebrowFigures, ink), in: after))
        layer.addSublayer(chevron(isOpen: !eyebrow.isFolded, in: EyebrowLayout.chevron(in: size)))

        return layer
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
