import AppKit

/// A side panel's window content: one drawing of it at a time, in the material Lee chose, and every click on the
/// window, whichever draws it. A form's surface makes its drawings and replays the last frame into a new one.
@MainActor
class PanelSurface<Drawing>: NSView {
    /// A click, in screen coordinates.
    var onClick: (CGPoint) -> Void = { _ in }

    /// What the panel is made of; one the Mac can't draw is drawn black.
    var material = PanelMaterial.black {
        didSet {
            if material.drawn != oldValue.drawn {
                swap(to: material.drawn)
            }
        }
    }

    private(set) var drawing: Drawing
    private let make: (PanelMaterial) -> Drawing
    private let view: (Drawing) -> NSView

    init(make: @escaping (PanelMaterial) -> Drawing, view: @escaping (Drawing) -> NSView) {
        self.make = make
        self.view = view
        drawing = make(.black)
        super.init(frame: .zero)
        add(view(drawing))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var isFlipped: Bool { true }

    /// Every click on the window is the surface's, never a drawing's own views'.
    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    /// A click on the panel acts, though its window is never key and SitRep never active.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            return
        }

        onClick(window.convertPoint(toScreen: event.locationInWindow))
    }

    /// The new drawing has been put in place: it takes the last frame.
    func replay() {}

    private func swap(to material: PanelMaterial) {
        view(drawing).removeFromSuperview()
        drawing = make(material)
        add(view(drawing))
        replay()
    }

    private func add(_ drawing: NSView) {
        drawing.frame = bounds
        drawing.autoresizingMask = [.width, .height]
        addSubview(drawing)
    }
}
