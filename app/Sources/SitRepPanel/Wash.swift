import Foundation

/// A new row's orange wash, as the prototype washes it: held at its full, then easing out.
public enum Wash {
    /// How long it lasts, ms, and how long of that it is held.
    public static let length = 2000.0, held = 300.0

    /// How washed a row is this long after its wash began, ms: from 1 as it comes to 0.
    public static func amount(since elapsed: Double) -> Double {
        let out = min(max((elapsed - held) / (length - held), 0), 1)

        return 1 - out * out * (3 - 2 * out)
    }

    /// The washes still under way at this time, of those begun when each says.
    public static func live<Key: Hashable>(_ began: [Key: Double], at time: Double) -> [Key: Double] {
        began.filter { time - $0.value < length }
    }

    /// The washes still under way at this time, of those begun when each says.
    public static func live<Key: Hashable>(_ began: [Key: Date], at time: Date) -> [Key: Date] {
        began.filter { time.timeIntervalSince($0.value) * 1000 < length }
    }
}
