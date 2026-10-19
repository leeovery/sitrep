/// The other edge's ghost while a drag carries the notch, as the prototypes draw it: the notch at rest, faint, where
/// letting go would take it. It comes in over 140ms once the drag is past the screen's middle and goes in 200 as it
/// comes back; let go there, it fades in 420 as the notch lands on that edge.
public struct DragGhost: Sendable {
    private var shown = Spring(0)

    public init() {}

    /// The drag moved: past the screen's middle or not.
    public mutating func carried(across: Bool) {
        shown.to(across ? 1 : 0, across ? 140 : 200)
    }

    /// The drag let the notch go.
    public mutating func dropped() {
        shown.to(0, 420)
    }

    /// The ghost this many ms on.
    public mutating func step(_ dt: Double) {
        shown.step(dt)
    }

    /// How opaque it is: the panel's black at 0.3 at most.
    public var opacity: Double { 0.3 * clamp(shown.x, 0, 1) }

    /// Whether it still comes or goes: frames must keep coming until it is done.
    public var isMoving: Bool { !shown.isAtRest }
}
