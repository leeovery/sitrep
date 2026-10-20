import AppKit
import SitRepPanel

/// The other edge's ghost while a drag carries the notch or the strip: the notch at rest, or the strip as it is, in
/// faint black on the screen's other side, where letting go would take it, coming and going as `DragGhost` has it.
/// Its window shows only while it does, and takes no clicks.
@MainActor
final class GhostEdge {
    private var ghost = DragGhost()
    private let stage = CALayer()
    private let shape = CAShapeLayer()
    /// Its window: internal only for the tests, which read where the ghost lands in it.
    let window: EdgeWindow
    private var time: Double?

    init() {
        let root = CALayer()

        shape.fillColor = EdgeStyle.black
        shape.opacity = 0
        stage.addSublayer(shape)
        root.addSublayer(stage)
        window = EdgeWindow(frame: .zero, view: StageHost(hosting: root))
    }

    /// The drag carries the notch or the strip on this edge, past the screen's middle or not, landing there in this
    /// outline on the stage.
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

    /// The drag let it go, past the screen's middle or not.
    func dropped(across: Bool) {
        ghost.dropped(across: across)
    }

    /// Gone at once, the notch or the strip hidden mid-drag.
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
