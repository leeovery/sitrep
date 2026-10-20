/// When the last new ask was, on the display's clock. The model stamps an ask on its sim clock, which stands still
/// while frames stop; the light breathes on the display's clock, so each new stamp is placed on it once, from the
/// first frame that carries it, and the flash plays out in its own time whether frames run or not.
public struct AskClock: Equatable, Sendable {
    private var stamp: Double?
    private var placed: Double?

    public init() {}

    /// A frame's sim time and its last ask, at a time on the display's clock, ms.
    public mutating func take(lastAsk: Double?, simTime: Double, at time: Double) {
        guard lastAsk != stamp else {
            return
        }

        stamp = lastAsk
        placed = lastAsk.map { time - (simTime - $0) }
    }

    /// How long before this time on the display's clock the last ask was, ms; nil when there has been none.
    public func since(_ time: Double) -> Double? {
        placed.map { time - $0 }
    }
}
