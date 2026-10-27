import Foundation

/// What Lee's picks in the list have the window follow, settled: a pick on its own follows the sessions it shows at
/// once; picks that follow one another sooner than `settle`, as an arrow key repeating down the list gives, follow only
/// the last, once they stop, the sessions followed as the run began standing until then. With the Mac's key repeat
/// faster than `settle`, holding ↓ follows the first row, the second, as the delay before a key repeats is longer
/// than `settle`, and the row it stops on, not every row it passes; at a slower repeat each row is followed.
struct PickFollows: Equatable, Sendable {
    /// How soon after one pick another must come to be one of a run of them.
    static let settle: TimeInterval = 0.15

    private var lastPick: Date?
    /// While a run of picks waits to settle, the sessions followed as it began, which stand until then.
    private(set) var standing: Set<String>?
    /// When the last of a run of picks is followed, while the run waits.
    private(set) var dueAt: Date?

    /// A pick at this time, these sessions followed as it came: it is followed at once, unless it is one of a run.
    mutating func picked(at time: Date, following: Set<String>) {
        defer { lastPick = time }

        guard let lastPick, time < lastPick.addingTimeInterval(Self.settle) else {
            standing = nil
            dueAt = nil
            return
        }

        standing = standing ?? following
        dueAt = time.addingTimeInterval(Self.settle)
    }

    /// The run of picks settled, once they have stopped by this time: its last pick is followed.
    mutating func settle(at time: Date) {
        guard let dueAt, time >= dueAt else {
            return
        }

        standing = nil
        self.dueAt = nil
    }
}
