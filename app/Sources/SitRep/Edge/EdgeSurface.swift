import AppKit
import SitRepPanel

/// The pointer's doings on an edge's window, in screen coordinates.
@MainActor
struct EdgePointer {
    var pressed: (CGPoint) -> Void = { _ in }
    var dragged: (CGPoint) -> Void = { _ in }
    var released: () -> Void = {}
    /// A scroll, by this many points down the content.
    var scrolled: (Double) -> Void = { _ in }
}

/// An edge's window content: one drawing of it at a time, in the material Lee chose, and every press, drag and scroll
/// on the window, whichever draws it. A form's surface makes its drawings and replays the last frame into a new one.
@MainActor
class EdgeSurface<Drawing>: NSView {
    var pointer = EdgePointer()

    /// What the edge is made of: glass from macOS 26, black before it.
    var material = EdgeSettings.Material.black {
        didSet {
            if Self.drawn(material) != Self.drawn(oldValue) {
                swap(to: Self.drawn(material))
            }
        }
    }

    private(set) var drawing: Drawing
    private let make: (EdgeSettings.Material) -> Drawing
    private let view: (Drawing) -> NSView

    /// A wheel's notch, scrolled as so many points.
    private static var lineHeight: Double { 16 }

    init(make: @escaping (EdgeSettings.Material) -> Drawing, view: @escaping (Drawing) -> NSView) {
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

    /// The material as it can be drawn on this Mac.
    static func drawn(_ material: EdgeSettings.Material) -> EdgeSettings.Material {
        if #available(macOS 26, *) {
            return material
        }
        return .black
    }

    /// Every event on the window is the surface's, never a drawing's own views'.
    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    /// A press on the edge acts, though its window is never key and SitRep never active.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if let window {
            pointer.pressed(window.convertPoint(toScreen: event.locationInWindow))
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if let window {
            pointer.dragged(window.convertPoint(toScreen: event.locationInWindow))
        }
    }

    override func mouseUp(with event: NSEvent) {
        pointer.released()
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * Self.lineHeight

        pointer.scrolled(-delta)
    }

    /// The new drawing has been put in place: it takes the last frame.
    func replay() {}

    private func swap(to material: EdgeSettings.Material) {
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
