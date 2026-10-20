import CoreGraphics
import Foundation

/// A press on the notch or its panel, off a row, that may carry the notch, as the prototypes' drag does: moved more
/// than 4 points it is a drag, which takes the notch along the edge with the pointer, and let go past the screen's
/// middle, to the other edge. It never takes the notch to the top or the bottom.
public struct NotchDrag: Equatable, Sendable {
    /// Where the press began on the stage, and the notch's home then.
    private let press: CGPoint
    private var home: Double
    private var point: CGPoint
    /// Moved far enough to be a drag.
    public private(set) var isCarrying = false
    /// Past the screen's middle, where letting go takes the notch to the other edge.
    public private(set) var isAcross = false

    /// How far a press moves before it is a drag.
    static let from = 4.0

    public init(at press: CGPoint, home: Double) {
        self.press = press
        self.home = home
        point = press
    }

    /// The pointer moved to this point on the stage of a screen this wide: whether the press became a drag here.
    @discardableResult
    public mutating func move(to point: CGPoint, width: Double) -> Bool {
        self.point = point
        let begins = !isCarrying && hypot(point.x - press.x, point.y - press.y) > Self.from
        isCarrying = isCarrying || begins
        isAcross = isCarrying && point.x > width / 2

        return begins
    }

    /// The notch, carried, took its home from here: from where the attraction had slid it, in the prototype's
    /// `beginDrag`.
    public mutating func carries(from home: Double) {
        self.home = home
    }

    /// Where it takes the notch's home along the edge, on the stage: as far from where the press began as the pointer.
    public var notchY: Double { home + point.y - press.y }

    /// Where it lets the notch go from these settings, its home at this place on a screen this tall: there along the
    /// edge, on the other edge if it was let go across the middle.
    public func dropped(_ settings: EdgeSettings, at notchY: Double, height: Double) -> EdgeMove {
        settings.dropped(along: notchY / height, across: isAcross)
    }
}
