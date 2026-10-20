import AppKit
import SitRepPanel

/// The other edge's ghost while a drag carries the notch: the notch at rest in faint black on the screen's other
/// side, where letting go would take it, coming and going as `DragGhost` has it. Its window shows only while it does,
/// and takes no clicks.
@MainActor
final class GhostEdge {
    private var ghost = DragGhost()
    private let stage = CALayer()
    private let shape = CAShapeLayer()
    private let window: EdgeWindow
    private var time: Double?

    init() {
        let view = NSView(), root = CALayer()

        root.isGeometryFlipped = true
        shape.fillColor = EdgeStyle.black
        shape.opacity = 0
        stage.addSublayer(shape)
        root.addSublayer(stage)
        view.layer = root
        view.wantsLayer = true
        window = EdgeWindow(frame: .zero, view: view)
    }

    /// The drag carries the notch on this edge, past the screen's middle or not, the notch at rest in this outline.
    func carried(across: Bool, outline: CGPath, on edge: ScreenEdge) {
        let other = edge.across

        ghost.carried(across: across)
        if window.frame != other.window {
            window.setFrame(other.window, display: false)
        }
        still {
            stage.bounds = CGRect(origin: .zero, size: other.window.size)
            stage.position = CGPoint(x: stage.bounds.midX, y: stage.bounds.midY)
            stage.setAffineTransform(CGAffineTransform(scaleX: other.mirror.a, y: 1))
            shape.path = outline
        }
    }

    /// The drag let the notch go.
    func dropped() {
        ghost.dropped()
    }

    /// Gone at once, the notch hidden mid-drag.
    func hide() {
        ghost = DragGhost()
        time = nil
        still { shape.opacity = 0 }
        window.orderOut(nil)
    }

    /// One frame: whether it still comes or goes.
    func step(at time: Double) -> Bool {
        ghost.step(min(50, max(0, time - (self.time ?? time))))
        self.time = ghost.isMoving ? time : nil
        still { shape.opacity = Float(ghost.opacity) }

        let shows = ghost.opacity > 0

        if shows, !window.isVisible {
            window.orderFrontRegardless()
        } else if !shows, window.isVisible {
            window.orderOut(nil)
        }

        return ghost.isMoving
    }
}
