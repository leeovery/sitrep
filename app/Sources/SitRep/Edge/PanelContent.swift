import AppKit
import SitRepPanel

/// The panel's content in black: its head and its list, laid out as the list changes, a row kept as it was while its
/// session reads the same, so its arc and shimmer run on. Each frame moves it with the panel, clips it to the black's
/// body with its front corners rounded, scrolls it, and sets each row's opacity and rise and its time, never setting
/// any other text again.
@MainActor
final class PanelContent {
    let layer = CALayer()

    private let clip = CAShapeLayer()
    /// The head and the items, scrolled inside the clip.
    private let list = CALayer()
    private var head = CALayer()
    private var shown = PanelList(head: Head(title: "", count: ""), content: Content(laying: []))
    /// One for each of the list's items, in its order.
    private var items: [CALayer] = []
    /// The rows by their sessions' ids, each in its item's layer.
    private var rows: [String: (item: CALayer, row: SessionRow)] = [:]
    private var hovered: String?
    private var scale: CGFloat = 1

    init() {
        layer.mask = clip
        layer.isHidden = true
        layer.addSublayer(list)
        list.addSublayer(head)
    }

    /// The list from now on: the head drawn again, a row whose session reads the same kept, the rest made anew.
    func show(_ list: PanelList) {
        guard list != shown else {
            return
        }

        still {
            let head = Self.head(list.head, in: list.content.headFrame)

            self.list.replaceSublayer(self.head, with: head)
            self.head = head
            lay(list.content)
            rescale(self.list, to: scale)
        }
        shown = list
    }

    /// The content as the frame has it, scrolled this far, the row under the pointer lit; hidden while the panel is
    /// in.
    func show(_ scene: NotchScene) {
        guard let panel = scene.frame.panel else {
            return hide()
        }

        layer.isHidden = false
        layer.frame = panel.drawn(scene.mirror)
        clip.frame = layer.bounds
        clip.path = panel.clipPath(scene.mirror)
        list.frame = CGRect(x: 0, y: -scene.scroll, width: layer.bounds.width, height: shown.content.height)
        paint(head, panel.head)
        zip(items, panel.items).forEach(paint)
        rows.values.forEach { $0.row.showAge(at: scene.now) }
        highlight(scene.hover.flatMap { shown.item($0)?.session?.id })
    }

    func wash(_ keys: Set<String>) {
        keys.compactMap { rows[$0]?.row }.forEach { $0.washes() }
    }

    func rescaled(to scale: CGFloat) {
        self.scale = scale
        rescale(layer, to: scale)
    }

    private func hide() {
        layer.isHidden = true
        highlight(nil)
    }

    /// Each item in its place: a row kept where its session reads the same, else made anew, and the divider. A row
    /// kept stays in the tree, never taken out and put back, so nothing it runs is cut short.
    private func lay(_ content: Content) {
        var kept: [String: (item: CALayer, row: SessionRow)] = [:]
        let was = items

        items = content.entries.indices.map { index in
            let box = content.itemFrame(index)

            guard let session = content.entries[index].item.session else {
                return Self.divider(in: box)
            }

            let size = CGSize(width: box.width, height: box.height - Item.rowGap)
            let row = rows[session.id].flatMap { $0.row.session == session && $0.row.layer.bounds.size == size ? $0 : nil }
                ?? Self.row(session, size: size)

            row.item.frame = box
            kept[session.id] = row
            return row.item
        }
        was.filter { old in !items.contains { $0 === old } }.forEach { $0.removeFromSuperlayer() }
        items.filter { $0.superlayer !== list }.forEach(list.addSublayer)
        rows = kept
        hovered = nil
    }

    private func paint(_ layer: CALayer, _ paint: Frame.Paint) {
        layer.opacity = Float(paint.alpha)
        layer.transform = CATransform3DMakeTranslation(0, paint.rise, 0)
    }

    /// The lift comes and goes in 110ms, as the prototype's does.
    private func highlight(_ id: String?) {
        guard id != hovered else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0.11)
        hovered.flatMap { rows[$0] }?.row.isHighlighted = false
        id.flatMap { rows[$0] }?.row.isHighlighted = true
        CATransaction.commit()
        hovered = id
    }

    private static func row(_ session: Session, size: CGSize) -> (item: CALayer, row: SessionRow) {
        let item = CALayer(), row = SessionRow(session, size: size)

        item.addSublayer(row.layer)

        return (item, row)
    }

    /// The head: how many need Lee at the left, how many sessions at the right, on one baseline.
    private static func head(_ head: Head, in box: CGRect) -> CALayer {
        let layer = CALayer()
        let line = HeadLayout.line, inset = HeadLayout.inset
        let font = EdgeStyle.headTitle
        let title = TextLine.text(head.title, font, EdgeStyle.ink, kern: EdgeStyle.tightKern(font))
        let count = TextLine.text(head.count, EdgeStyle.headCount, EdgeStyle.ink3)
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
    private static func divider(in box: CGRect) -> CALayer {
        let item = CALayer(), rule = CALayer()

        item.frame = box
        rule.frame = DividerLayout.rule(width: box.width)
        rule.backgroundColor = EdgeStyle.rule
        item.addSublayer(rule)

        return item
    }
}
