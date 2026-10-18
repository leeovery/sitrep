import AppKit
import SitRepPanel

/// The panel's content: its head and its list, laid out once from the model's items. Each frame moves it with the
/// panel, clips it to the black's body with its front corners rounded, and sets each row's opacity and rise, never
/// setting any text again.
@MainActor
final class PanelContent {
    let layer = CALayer()

    private let clip = CAShapeLayer()
    private let head: CALayer
    /// One for each of the model's items, in its order, and the session rows among them by the same index.
    private let items: [CALayer]
    private let rows: [Int: SessionRow]
    private var hovered: Int?

    init(items: [Item], content: Content) {
        var rows: [Int: SessionRow] = [:]

        head = Self.head(Head(items), in: content.headFrame)
        self.items = items.indices.map { index in
            let item = CALayer()
            let box = content.itemFrame(index)

            item.frame = box
            if let session = items[index].session {
                let row = SessionRow(session, size: CGSize(width: box.width, height: box.height - Item.rowGap))

                rows[index] = row
                item.addSublayer(row.layer)
            } else {
                item.addSublayer(Self.divider(width: box.width))
            }

            return item
        }
        self.rows = rows

        layer.mask = clip
        layer.isHidden = true
        layer.addSublayer(head)
        self.items.forEach(layer.addSublayer)
    }

    /// The content as the frame has it, the row under the pointer lit; hidden while the panel is in.
    func show(_ panel: Frame.Panel?, hover: Int?) {
        guard let panel else {
            return hide()
        }

        if layer.isHidden {
            layer.isHidden = false
            rows.values.forEach { $0.startMotion() }
        }

        layer.frame = panel.frame
        clip.frame = layer.bounds
        clip.path = Self.clipPath(
            panel.clip.offsetBy(dx: -panel.frame.minX, dy: -panel.frame.minY),
            top: panel.topRadius, bottom: panel.bottomRadius
        )
        paint(head, panel.head)
        zip(items, panel.items).forEach(paint)
        highlight(hover)
    }

    private func hide() {
        guard !layer.isHidden else {
            return
        }

        layer.isHidden = true
        rows.values.forEach { $0.stopMotion() }
        highlight(nil)
    }

    private func paint(_ layer: CALayer, _ paint: Frame.Paint) {
        layer.opacity = Float(paint.alpha)
        layer.transform = CATransform3DMakeTranslation(0, paint.rise, 0)
    }

    /// The highlight comes and goes in 110ms, as the prototype's does.
    private func highlight(_ row: Int?) {
        guard row != hovered else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0.11)
        hovered.flatMap { rows[$0] }?.isHighlighted = false
        row.flatMap { rows[$0] }?.isHighlighted = true
        CATransaction.commit()
        hovered = row
    }

    /// The clip: a rectangle with its front corners rounded; the strip's tabs are clipped so too.
    nonisolated static func clipPath(_ rect: CGRect, top: CGFloat, bottom: CGFloat) -> CGPath {
        let path = CGMutablePath()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
            radius: top
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY),
            radius: bottom
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }

    /// The head: how many need Lee at the left, how many sessions at the right, on one baseline.
    private static func head(_ head: Head, in box: CGRect) -> CALayer {
        let layer = CALayer()
        let line = HeadLayout.line, inset = HeadLayout.inset
        let font = PanelStyle.headTitle
        let title = TextLine.text(head.title, font, PanelStyle.ink, kern: PanelStyle.tightKern(font))
        let count = TextLine.text(head.count, PanelStyle.headCount, PanelStyle.ink3)
        let drop = TextLine.baseline(title, lineHeight: line) - TextLine.baseline(count, lineHeight: line)
        let half = (box.width - inset.left - inset.right) / 2

        layer.frame = box
        layer.addSublayer(TextLine(title, in: CGRect(x: inset.left, y: 0, width: half, height: line)))
        layer.addSublayer(TextLine(
            count, in: CGRect(x: inset.left + half, y: drop, width: half, height: line), alignment: .right
        ))

        return layer
    }

    /// The rule between what needs Lee and the rest.
    private static func divider(width: CGFloat) -> CALayer {
        let rule = CALayer()

        rule.frame = DividerLayout.rule(width: width)
        rule.backgroundColor = PanelStyle.rule

        return rule
    }
}
