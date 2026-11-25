import AppKit
import SitRepPanel

/// The pointer's doings on an edge's window, in screen coordinates.
@MainActor
struct EdgePointer {
    var pressed: (CGPoint) -> Void = { _ in }
    var dragged: (CGPoint) -> Void = { _ in }
    var released: () -> Void = {}
    /// A scroll, down the content and along it.
    var scrolled: (Scroll) -> Void = { _ in }
    /// A right-click: the menu it brings up there, if any.
    var menu: (CGPoint) -> NSMenu? = { _ in nil }
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

    /// A right-click brings up the menu of what is under it, as AppKit shows a view's.
    override func menu(for event: NSEvent) -> NSMenu? {
        window.flatMap { pointer.menu($0.convertPoint(toScreen: event.locationInWindow)) }
    }

    override func scrollWheel(with event: NSEvent) {
        pointer.scrolled(Scroll(event))
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

extension Scroll {
    /// A scroll event as the edge takes it: its deltas the way the Mac scrolls, a wheel's notch as 16 points; and
    /// where it falls in its gesture, its momentum after the fingers lift, else its own phase, none for a mouse's
    /// wheel.
    init(_ event: NSEvent) {
        let scale = event.hasPreciseScrollingDeltas ? 1 : Self.lineHeight

        self.init(
            down: -event.scrollingDeltaY * scale, along: -event.scrollingDeltaX * scale, phase: Self.phase(of: event)
        )
    }

    /// A wheel's notch, scrolled as so many points.
    private static let lineHeight = 16.0

    private static func phase(of event: NSEvent) -> Phase {
        if !event.momentumPhase.isEmpty {
            return .momentum
        }
        if !event.phase.isDisjoint(with: [.mayBegin, .began]) {
            return .began
        }
        if !event.phase.isDisjoint(with: [.ended, .cancelled]) {
            return .ended
        }
        return event.phase.isEmpty ? .wheel : .changed
    }
}
