/// A scroll on an edge's window, as the Mac gives it: how far, pt, down the content and along it, the way the Mac
/// scrolls them, so with natural scrolling fingers moving up go down and fingers moving left go along; and where it
/// falls in its gesture.
public struct Scroll: Equatable, Sendable {
    /// Where a scroll falls in its gesture: a trackpad's from its fingers' first touch to their lift, or to the Mac
    /// cancelling it, and the momentum that runs on after; a mouse's wheel, which has no phases.
    public enum Phase: Sendable {
        case began, changed, ended, cancelled, momentum, wheel
    }

    public let down: Double
    public let along: Double
    public let phase: Phase

    public init(down: Double, along: Double = 0, phase: Phase = .wheel) {
        self.down = down
        self.along = along
        self.phase = phase
    }
}
