import AppKit
import SitRepPanel

/// The strip in black: its black, each tab's black, and the hairline, through the edge's mirror; over them the marks
/// and each tab's words, placed through it but never mirrored themselves. All are layers in the stage's own coordinates
/// (y down from the screen's top), hung from the menu bar the window starts under. A frame changes paths, places,
/// opacities and clips; a tab's words and a mark's letters are laid out once.
@MainActor
final class StripView: StageHost, StripDrawing {
    /// The blacks, through the edge's mirror, ...
    private let stage = CALayer()
    private let fading = CAShapeLayer()
    private let strip = CAShapeLayer()
    private let hairline = CALayer()
    /// ... and the marks, then the tabs' words, over them.
    private let over = CALayer()
    private let marks = CALayer()
    private var tabs: [Int: Tab] = [:]
    private var shownMarks: [MarkKey: StripMarkLayer] = [:]

    /// A tab's black, and its words in a box clipped to its body.
    private struct Tab {
        let shape = CAShapeLayer()
        let box = CALayer()
        let clip = CAShapeLayer()
        var words: [Int: StripWordsLayer] = [:]
    }

    init() {
        let root = CALayer()

        super.init(hosting: root)
        for shape in [fading, strip] {
            shape.fillColor = EdgeStyle.black
            stage.addSublayer(shape)
        }
        fading.isHidden = true
        hairline.backgroundColor = EdgeStyle.rule
        stage.addSublayer(hairline)
        over.addSublayer(marks)
        root.addSublayer(stage)
        root.addSublayer(over)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rescaleToWindow()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        rescaleToWindow()
    }

    func show(_ scene: StripScene) {
        let frame = scene.frame

        still {
            place(scene)
            strip.path = frame.strip
            fading.isHidden = frame.fading == nil
            fading.path = frame.fading?.outline
            fading.opacity = Float(frame.fading?.alpha ?? 0)
            showTabs(scene)
            hairline.frame = CGRect(x: frame.hairline.x - 8, y: frame.hairline.y - 0.5, width: 16, height: 1)
            hairline.opacity = Float(frame.hairline.alpha)
            showMarks(scene)
        }
    }

    /// The stage, hung from the menu bar, its blacks turned about its centre for the window's mirror.
    private func place(_ scene: StripScene) {
        let size = CGSize(width: Strip.depth, height: scene.menu + bounds.height)
        let hung = CGRect(origin: CGPoint(x: 0, y: -scene.menu), size: size)

        for layer in [stage, over] {
            layer.bounds = CGRect(origin: .zero, size: size)
            layer.position = CGPoint(x: hung.midX, y: hung.midY)
        }
        stage.setAffineTransform(CGAffineTransform(scaleX: scene.mirror.a, y: 1))
    }

    private func showTabs(_ scene: StripScene) {
        let shown = scene.frame.tabs

        for gone in Set(tabs.keys).subtracting(shown.map(\.id)) {
            tabs[gone].map { [$0.shape, $0.box].forEach { $0.removeFromSuperlayer() } }
            tabs[gone] = nil
        }
        for tab in shown {
            var drawn = tabs[tab.id] ?? addTab()
            let box = scene.box(tab)

            drawn.shape.path = tab.outline
            drawn.shape.opacity = Float(tab.alpha)
            drawn.box.frame = box
            drawn.box.opacity = Float(tab.alpha)
            drawn.clip.frame = drawn.box.bounds
            drawn.clip.path = scene.clip(tab)
            showWords(tab, in: &drawn, scene)
            tabs[tab.id] = drawn
        }
    }

    /// A tab's words, each laid out once as it comes, and again should what they say of the board change, or how
    /// they move.
    private func showWords(_ tab: StripFrame.Tab, in drawn: inout Tab, _ scene: StripScene) {
        for gone in Set(drawn.words.keys).subtracting(tab.words.map(\.id)) {
            drawn.words[gone]?.layer.removeFromSuperlayer()
            drawn.words[gone] = nil
        }
        for words in tab.words {
            let frame = scene.frame(words, in: tab)
            let layer = drawn.words[words.id].flatMap { $0.says(scene) ? $0 : nil } ?? {
                let made = StripWordsLayer(words, in: frame, scene)

                drawn.words[words.id]?.layer.removeFromSuperlayer()
                drawn.box.addSublayer(made.layer)
                rescaled(made.layer)
                return made
            }()

            drawn.words[words.id] = layer
            layer.show(words, in: frame, hover: tab.isLive ? scene.hoverRow : nil, now: scene.now)
        }
    }

    private func addTab() -> Tab {
        let tab = Tab()

        tab.shape.fillColor = EdgeStyle.black
        tab.box.mask = tab.clip
        stage.insertSublayer(tab.shape, below: hairline)
        over.addSublayer(tab.box)
        return tab
    }

    private func showMarks(_ scene: StripScene) {
        let shown = scene.frame.marks

        for gone in Set(shownMarks.keys).subtracting(shown.map(\.key)) {
            shownMarks[gone]?.layer.removeFromSuperlayer()
            shownMarks[gone] = nil
        }
        for mark in shown {
            let layer = shownMarks[mark.key] ?? {
                let made = StripMarkLayer()

                marks.addSublayer(made.layer)
                rescaled(made.layer)
                return made
            }()

            shownMarks[mark.key] = layer
            layer.show(mark, at: scene.centre(mark))
        }
    }

    private func rescaleToWindow() {
        rescaled(stage)
        rescaled(over)
    }

    /// Drawn at the window's pixel density, once there is a window.
    private func rescaled(_ layer: CALayer) {
        if let scale = window?.backingScaleFactor {
            rescale(layer, to: scale)
        }
    }
}
