import AppKit
import SitRepPanel

/// The card's parts beside its rows, in black, as Paper's board D draws them: a section's eyebrow, drawn once, in a box
/// the size of what its item draws.
@MainActor
enum CardParts {
    /// An eyebrow: its name in white at 55%, its counts 6 after it and 6 apart, Needs you's asks in orange and its
    /// stopped in blue, the faint grey for Snoozed (board G) and white at 30% for the rest, and its chevron, down while
    /// the section is open and right while it is folded.
    static func eyebrow(_ eyebrow: Eyebrow, size: CGSize) -> CALayer {
        let layer = CALayer(), box = EyebrowLayout.label(in: size)
        let name = TextLine(TextLine.text(eyebrow.section.title, EdgeStyle.eyebrowTitle, EdgeStyle.eyebrow), in: box)
        var end = box.minX + name.width

        layer.frame = CGRect(origin: .zero, size: size)
        layer.addSublayer(name)
        for count in eyebrow.counts {
            let colour = count.need.map(EdgeStyle.colour) ?? ink(of: eyebrow.section)
            let after = CGRect(x: end + EyebrowLayout.gap, y: box.minY, width: 40, height: box.height)
            let figures = TextLine(TextLine.text("\(count.value)", EdgeStyle.eyebrowFigures, colour), in: after)

            layer.addSublayer(figures)
            end = after.minX + figures.width
        }
        layer.addSublayer(chevron(isOpen: !eyebrow.isFolded, in: EyebrowLayout.chevron(in: size)))

        return layer
    }

    /// The ink of a section's count where it is counted whole, as Working and Snoozed are.
    private static func ink(of section: BoardSection) -> CGColor {
        section == .snoozed ? EdgeStyle.ink3 : EdgeStyle.eyebrowCount
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
