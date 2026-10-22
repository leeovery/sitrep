import AppKit
import SitRepEdge
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
    /// The rows by their items' keys, each in its item's layer: a row crossing the hairline is two while it folds out of
    /// one place and into the other.
    private(set) var rows: [String: (item: CALayer, row: SessionRow)] = [:]
    /// The row lifted under the pointer.
    private var hovered: SessionRow?
    /// When each row's wash began, by its session: a row made anew mid-wash carries it on.
    private var washed: [String: Double] = [:]
    private var scale: CGFloat = 1

    init() {
        layer.mask = clip
        layer.isHidden = true
        layer.addSublayer(list)
        list.addSublayer(head)
    }

    /// The list from now on: a head that reads differently drawn again; a row whose session reads the same kept, the
    /// rest made anew; and each item in its place, at its height as it folds.
    func show(_ list: PanelList) {
        guard list != shown else {
            return
        }

        still {
            let relaid = list.head != shown.head || list.content.items != shown.content.items

            if list.head != shown.head {
                let head = Self.head(list.head, in: list.content.headFrame)

                self.list.replaceSublayer(self.head, with: head)
                self.head = head
            }
            if list.content.items != shown.content.items {
                lay(list.content)
            }
            place(list.content)
            if relaid {
                rescale(self.list, to: scale)
            }
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
        rows.forEach { $1.row.isPressed = $0 == panel.pressed }
        highlight(scene.hover.flatMap { shown.item($0)?.key })
    }

    /// The rows of these sessions washed from this time, ms on the display's clock.
    func wash(_ sessions: Set<String>, at time: Double) {
        washed = Wash.live(washed, at: time)
        sessions.forEach { washed[$0] = time }
        rows.values.map(\.row).filter { sessions.contains($0.session.id) }.forEach { $0.washes(since: time) }
    }

    func rescaled(to scale: CGFloat) {
        self.scale = scale
        rescale(layer, to: scale)
    }

    private func hide() {
        layer.isHidden = true
        highlight(nil)
    }

    /// An item for each, in their order: a row kept where its session reads the same, else made anew, and the
    /// divider. A row kept stays in the tree, never taken out and put back, so nothing it runs is cut short.
    private func lay(_ content: Content) {
        var kept: [String: (item: CALayer, row: SessionRow)] = [:]
        let was = items, width = content.headFrame.width

        items = content.items.map { item in
            guard let session = item.session else {
                return Self.divider(width: width)
            }

            let row = rows[item.key].flatMap { $0.row.session == session ? $0 : nil } ?? made(session, item, width)

            kept[item.key] = row
            return row.item
        }
        was.filter { old in !items.contains { $0 === old } }.forEach { $0.removeFromSuperlayer() }
        items.filter { $0.superlayer !== list }.forEach(list.addSublayer)
        rows = kept
    }

    /// A row made anew, its wash, if one is under way, carried on from when it began.
    private func made(_ session: Session, _ item: Item, _ width: Double) -> (item: CALayer, row: SessionRow) {
        let made = Self.row(session, size: CGSize(width: width, height: item.height - Item.rowGap))

        if let began = washed[session.id] {
            made.row.washes(since: began)
        }
        return made
    }

    /// Each item in its box, which a fold shortens: what is laid out in it keeps its own height, clipped. Placed by
    /// its bounds and position, as its rise transforms it.
    private func place(_ content: Content) {
        for (item, index) in zip(items, content.entries.indices) {
            let box = content.itemFrame(index)

            item.bounds = CGRect(origin: .zero, size: box.size)
            item.position = CGPoint(x: box.midX, y: box.midY)
        }
    }

    private func paint(_ layer: CALayer, _ paint: Frame.Paint) {
        layer.opacity = Float(paint.alpha)
        layer.transform = CATransform3DMakeTranslation(0, paint.rise, 0)
    }

    /// The row under the pointer lifts, and the one lifted before comes down, kept or made anew since: the lift comes
    /// and goes in 110ms, as the prototype's does.
    private func highlight(_ id: String?) {
        let row = id.flatMap { rows[$0]?.row }

        guard row !== hovered else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0.11)
        hovered?.isHighlighted = false
        row?.isHighlighted = true
        CATransaction.commit()
        hovered = row
    }

    private static func row(_ session: Session, size: CGSize) -> (item: CALayer, row: SessionRow) {
        let item = Self.item(), row = SessionRow(session, size: size)

        item.addSublayer(row.layer)

        return (item, row)
    }

    /// An item's box, clipping what it holds as it folds.
    private static func item() -> CALayer {
        let item = CALayer()

        item.masksToBounds = true

        return item
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
        // a head with no count, as when SitRep can't run `watch`, has the line to itself
        let titleWidth = head.count.isEmpty ? 2 * half : half

        layer.addSublayer(TextLine(title, in: CGRect(x: inset.left, y: 0, width: titleWidth, height: line)))
        layer.addSublayer(TextLine(
            count, in: CGRect(x: inset.left + half, y: drop, width: half, height: line), alignment: .right
        ))

        return layer
    }

    /// The rule between what needs Lee and the rest.
    private static func divider(width: Double) -> CALayer {
        let item = Self.item(), rule = CALayer()

        rule.frame = DividerLayout.rule(width: width)
        rule.backgroundColor = EdgeStyle.rule
        item.addSublayer(rule)

        return item
    }
}
