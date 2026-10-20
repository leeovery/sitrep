/// The other edge's ghost while a drag carries the notch, as the prototypes draw it: the notch at rest, faint, where
/// letting go would take it. It comes in over 140ms once the drag is past the screen's middle and goes in 140 as it
/// comes back; let go, it fades in 420 as the notch lands on that edge, or in 200 on its own.
public struct DragGhost: Sendable {
    private var shown = Spring(0)

    public init() {}

    /// The drag moved: past the screen's middle or not.
    public mutating func carried(across: Bool) {
        shown.to(across ? 1 : 0, 140)
    }

    /// The drag let the notch go, past the screen's middle or not.
    public mutating func dropped(across: Bool) {
        shown.to(0, across ? 420 : 200)
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
