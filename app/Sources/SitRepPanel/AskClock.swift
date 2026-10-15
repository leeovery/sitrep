/// When the last new ask was, on the wall clock. The model stamps an ask on its sim clock, which stands still while
/// frames stop; the light breathes on the wall clock, so each new stamp is placed on it once, from the first frame
/// that carries it, and the flash plays out in its own time whether frames run or not.
public struct AskClock: Equatable, Sendable {
    private var stamp: Double?
    private var wall: Double?

    public init() {}

    /// A frame's sim time and its last ask, at a wall time, ms.
    public mutating func take(lastAsk: Double?, simTime: Double, at wallTime: Double) {
        guard lastAsk != stamp else {
            return
        }

        stamp = lastAsk
        wall = lastAsk.map { wallTime - (simTime - $0) }
    }

    /// How long before this wall time the last ask was, ms; nil when there has been none.
    public func since(_ wallTime: Double) -> Double? {
        wall.map { wallTime - $0 }
    }
}
