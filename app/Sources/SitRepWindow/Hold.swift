import Foundation

/// Held while the pointer is over what it holds and for a second after it leaves, as the strip holds its marks, so a
/// change shows in place; and, after a pick made in it, for a second after the pick. The board's list holds its order
/// so (`HeldOrder`), and a page its closed asks.
struct Hold: Equatable, Sendable {
    /// How long after the pointer leaves, or after the last pick, the hold lets go.
    static let settle: TimeInterval = 1

    private var isPointerIn = false
    /// When the hold lets go, a second after the pointer left or after the last pick.
    private(set) var endsAt: Date?

    init() {}

    /// Held, while the pointer is over it and until the second after it leaves or after a pick runs out.
    var isHeld: Bool { isPointerIn || endsAt != nil }

    /// The pointer came over it, or left it at this time.
    mutating func pointer(isIn: Bool, at time: Date) {
        guard isIn != isPointerIn else {
            return
        }

        isPointerIn = isIn
        endsAt = isIn ? nil : time.addingTimeInterval(Self.settle)
    }

    /// A pick made in it at this time: held until the second after it runs out, or, with the pointer over it, for as
    /// long as the pointer holds it.
    mutating func picked(at time: Date) {
        if !isPointerIn {
            endsAt = max(endsAt ?? time, time.addingTimeInterval(Self.settle))
        }
    }

    /// The second after the pointer left, or after the last pick, has run out by this time: held no more. Whether it
    /// ran out now.
    @discardableResult
    mutating func settle(at time: Date) -> Bool {
        guard let due = endsAt, time >= due, !isPointerIn else {
            return false
        }

        endsAt = nil
        return true
    }

    /// The pointer gone with it, as when the window closes under it, which tells no exit: held no more.
    mutating func release() {
        isPointerIn = false
        endsAt = nil
    }
}
