import Foundation

/// The sessions Lee's picks in the list ask to read, settled: a pick on its own reads at once; picks that follow one
/// another sooner than `settle`, as an arrow key repeating down the list gives, read only the last, once they stop.
/// Holding ↓ reads the first row, the second, as the Mac's delay before a key repeats is longer than `settle`, and
/// the row it stops on, not every row it passes. Only the reads that run take a ticket (`WindowRun`), so one dropped
/// here never supersedes a read already under way.
public struct PickReads: Equatable, Sendable {
    /// How soon after one pick another must come to be one of a run of them.
    public static let settle: TimeInterval = 0.15

    private var lastPick: Date?
    private var waiting: [String] = []
    /// When the last of a run of picks reads, while its sessions wait.
    public private(set) var dueAt: Date?

    public init() {}

    /// A pick at this time asked to read these sessions: those to read now.
    public mutating func picked(_ sessions: [String], at time: Date) -> [String] {
        defer { lastPick = time }

        guard let lastPick, time < lastPick.addingTimeInterval(Self.settle) else {
            waiting = []
            dueAt = nil
            return sessions
        }

        waiting = sessions
        dueAt = sessions.isEmpty ? nil : time.addingTimeInterval(Self.settle)
        return []
    }

    /// The sessions the last of a run of picks reads, once the picks have stopped by this time.
    public mutating func due(at time: Date) -> [String] {
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
