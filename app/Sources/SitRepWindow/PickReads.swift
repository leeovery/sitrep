import Foundation

/// The reads Lee's picks ask for, settled: a pick on its own reads at once; picks that follow one another within
/// `settle`, as an arrow key held down the list gives, read only the last, once they stop. So holding ↓ runs
/// `sitrep board` for the first row and the one it stops on, not for every row it passes.
public struct PickReads: Equatable, Sendable {
    /// How soon after one pick another must come to be one of a run of them.
    public static let settle: TimeInterval = 0.15

    private var lastPick: Date?
    private var waiting: [Read] = []
    /// When the reads of the last of a run of picks are due, while they wait.
    public private(set) var dueAt: Date?

    public init() {}

    /// A pick at this time asked for these reads: those to run now.
    public mutating func picked(_ reads: [Read], at time: Date) -> [Read] {
        defer { lastPick = time }

        guard let lastPick, time.timeIntervalSince(lastPick) < Self.settle else {
            waiting = []
            dueAt = nil
            return reads
        }

        waiting = reads
        dueAt = time.addingTimeInterval(Self.settle)
        return []
    }

    /// The reads of the last of a run of picks, once the picks have stopped by this time.
    public mutating func due(at time: Date) -> [Read] {
        guard let dueAt, time >= dueAt else {
            return []
        }

        defer {
            waiting = []
            self.dueAt = nil
        }
        return waiting
    }
}
