import AppKit
import SitRepPanel

/// One way of drawing the strip a frame at a time: in black, or in glass.
@MainActor
protocol StripDrawing: NSView {
    /// The window starts under the menu bar: the stage moves up by it.
    func place(menu: Double, height: Double)
    /// The strip as the frame has it, the count's row under the pointer lit.
    func show(_ frame: StripFrame, hoverRow: String?)
}

/// The strip's window content: the strip drawn in the material Lee chose, and its clicks, whichever draws it.
@MainActor
final class StripSurface: NSView {
    /// A click, in screen coordinates.
    var onClick: (CGPoint) -> Void = { _ in }

    /// What the strip is made of; one the Mac can't draw is drawn black.
    var material = StripMaterial.black {
        didSet {
            if material.drawn != oldValue.drawn {
                draw(in: material.drawn)
            }
        }
    }

    private var drawing: any StripDrawing = StripView()
    private var placed: (menu: Double, height: Double) = (0, 0)
    private var last: (frame: StripFrame, hoverRow: String?)?

    init() {
        super.init(frame: .zero)
        add(drawing)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    /// Every click on the window is the surface's, never the glass's hosting view's.
    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    /// A click on the strip acts, though its window is never key and SitRep never active.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        onClick(window.convertPoint(toScreen: event.locationInWindow))
    }

    func place(menu: Double, height: Double) {
        placed = (menu, height)
        drawing.place(menu: menu, height: height)
    }

    func show(_ frame: StripFrame, hoverRow: String?) {
        last = (frame, hoverRow)
        drawing.show(frame, hoverRow: hoverRow)
    }

    private func draw(in material: StripMaterial) {
        drawing.removeFromSuperview()
        drawing = Self.drawing(material)
        add(drawing)
        drawing.place(menu: placed.menu, height: placed.height)
        if let last {
            drawing.show(last.frame, hoverRow: last.hoverRow)
        }
    }

    private func add(_ drawing: NSView) {
        drawing.frame = bounds
        drawing.autoresizingMask = [.width, .height]
        addSubview(drawing)
    }

    private static func drawing(_ material: StripMaterial) -> any StripDrawing {
        if #available(macOS 26, *), material == .glass {
            return StripGlassView()
        }
        return StripView()
    }
}
