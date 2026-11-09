/// The board a jump goes from: the watch's last line, a look old at most. A jump asked for before the watch's first
/// line, as one from a banner clicked as SitRep starts, waits for it, or for why none will come: `watch` heard failing
/// before its first line, or no plugin to run it. A board once heard is kept, stale or not, as every surface keeps
/// showing it.
@MainActor
public final class JumpBoard {
    /// The board, or why there is none, in plain words.
    public enum Read: Sendable, Equatable {
        case board(Board)
        case unread(String)
    }

    private var read: Read?
    private var waiting: [CheckedContinuation<Read, Never>] = []

    public init() {}

    /// Each look of the watch: its board, or, with none heard yet, why it has none.
    public func heard(_ last: LastBoard) {
        if let board = last.board {
            settle(.board(board))
        } else if let stale = last.stale {
            settle(.unread(stale.description))
        }
    }

    /// No plugin to run the watch, for the reason given: unless a board was heard, none will come.
    public func unrun(_ why: String) {
        if case .board = read {
            return
        }
        settle(.unread(why))
    }

    /// The board as last heard; else the first, or why there is none, once it comes.
    public func current() async -> Read {
        if let read {
            return read
        }

        return await withCheckedContinuation { waiting.append($0) }
    }

    private func settle(_ read: Read) {
        self.read = read
        waiting.forEach { $0.resume(returning: read) }
        waiting = []
    }
}
