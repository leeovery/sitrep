import AppKit
import SitRepPanel

/// The strip's one view: its black, each tab's black and words, the hairline and the marks, as layers in the stage's
/// own coordinates (y down from the screen's top), shifted up by the menu bar the window starts under. A frame changes
/// paths, places, opacities and clips; a tab's words and a mark's letters are laid out once. Clicks on it go to the
/// controller.
@MainActor
final class StripView: NSView {
    /// A click, in screen coordinates.
    var onClick: (CGPoint) -> Void = { _ in }

    private let stage = CALayer()
    private let fading = CAShapeLayer()
    private let strip = CAShapeLayer()
    private let hairline = CALayer()
    private let markLayer = CALayer()
    private var tabs: [Int: Tab] = [:]
    private var marks: [MarkKey: StripMarkLayer] = [:]

    /// A tab's black, and its words in a box clipped to its body.
    private struct Tab {
        let shape = CAShapeLayer()
        let box = CALayer()
        let clip = CAShapeLayer()
        var words: [Int: StripWordsLayer] = [:]
    }

    init() {
        super.init(frame: .zero)

        let root = CALayer()
        root.isGeometryFlipped = true
        for shape in [fading, strip] {
            shape.fillColor = PanelStyle.black
            stage.addSublayer(shape)
        }
        fading.isHidden = true
        hairline.backgroundColor = PanelStyle.rule
        stage.addSublayer(hairline)
        stage.addSublayer(markLayer)
        root.addSublayer(stage)
        layer = root
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    /// A click on the strip acts, though its window is never key and SitRep never active.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        onClick(window.convertPoint(toScreen: event.locationInWindow))
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rescale(layer)
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rescale(layer)
    }

    /// The window starts under the menu bar: the stage moves up by it.
    func place(menu: Double, height: Double) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stage.frame = CGRect(x: 0, y: -menu, width: Strip.depth, height: height)
        CATransaction.commit()
    }

    /// The strip as the frame has it, the count's row under the pointer lit.
    func show(_ frame: StripFrame, hoverRow: String?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        strip.path = frame.strip
        fading.isHidden = frame.fading == nil
        fading.path = frame.fading?.outline
        fading.opacity = Float(frame.fading?.alpha ?? 0)
        showTabs(frame.tabs, hoverRow: hoverRow)
        hairline.frame = CGRect(x: frame.hairline.x - 8, y: frame.hairline.y - 0.5, width: 16, height: 1)
        hairline.opacity = Float(frame.hairline.alpha)
        showMarks(frame.marks)
        CATransaction.commit()
    }

    private func showTabs(_ shown: [StripFrame.Tab], hoverRow: String?) {
        let now = StripWordsLayer.now
        for gone in Set(tabs.keys).subtracting(shown.map(\.id)) {
            tabs[gone].map { [$0.shape, $0.box].forEach { $0.removeFromSuperlayer() } }
            tabs[gone] = nil
        }
        for tab in shown {
            var drawn = tabs[tab.id] ?? addTab()
            drawn.shape.path = tab.outline
            drawn.shape.opacity = Float(tab.alpha)
            drawn.box.frame = tab.box
            drawn.clip.frame = drawn.box.bounds
            drawn.clip.path = PanelContent.clipPath(
                tab.clip.offsetBy(dx: -tab.box.minX, dy: -tab.box.minY), top: tab.radius, bottom: tab.radius
            )
            drawn.box.opacity = Float(tab.alpha)
            for gone in Set(drawn.words.keys).subtracting(tab.words.map(\.id)) {
                drawn.words[gone]?.layer.removeFromSuperlayer()
                drawn.words[gone] = nil
            }
            for words in tab.words {
                let layer = drawn.words[words.id] ?? {
                    let made = StripWordsLayer(words, now: now)
                    drawn.box.addSublayer(made.layer)
                    rescale(made.layer)
                    return made
                }()
                drawn.words[words.id] = layer
                layer.show(words, hover: tab.isLive ? hoverRow : nil)
            }
            tabs[tab.id] = drawn
        }
    }

    private func addTab() -> Tab {
        let tab = Tab()
        tab.shape.fillColor = PanelStyle.black
        tab.box.mask = tab.clip
        stage.insertSublayer(tab.shape, below: hairline)
        stage.insertSublayer(tab.box, above: markLayer)
        return tab
    }

    private func showMarks(_ shown: [StripFrame.Mark]) {
        for gone in Set(marks.keys).subtracting(shown.map(\.key)) {
            marks[gone]?.layer.removeFromSuperlayer()
            marks[gone] = nil
        }
        for mark in shown {
            let layer = marks[mark.key] ?? {
                let made = StripMarkLayer()
                markLayer.addSublayer(made.layer)
                rescale(made.layer)
                return made
            }()
            marks[mark.key] = layer
            layer.show(mark)
        }
    }

    /// Every layer drawn at the screen's pixel density, so the text stays crisp on Retina.
    private func rescale(_ layer: CALayer?) {
        guard let layer, let scale = window?.backingScaleFactor else {
            return
        }

        layer.contentsScale = scale
        layer.mask.map(rescale)
        layer.sublayers?.forEach(rescale)
        if layer is TextLine {
            layer.setNeedsDisplay()
        }
    }
}
