/// Where a jump reads its board from: for SitRep's, the watch (`JumpBoard`).
public protocol JumpBoardSource: Sendable {
    /// The board, once there is one to jump from; why none will come, once none will; the reason none is there yet,
    /// should the task asking be cancelled first.
    func current() async -> JumpBoard.Read
    /// Why there is no board yet, in plain words: for a jump whose time ran out waiting for one.
    func missing() async -> String
}

/// The board a jump goes from: the last line of a watch that is running and has printed, a look old at most. A jump
/// asked for while the watch starts, starts again or is stale, as from a banner clicked as SitRep starts, waits for its
/// next line, refused in the watch's words only if its time runs out first; or, with no plugin to run the watch, at
/// once in the plugin's.
@MainActor
public final class JumpBoard: JumpBoardSource {
    /// The board, or why there is none, in plain words.
    public enum Read: Sendable, Equatable {
        case board(Board)
        case unread(String)
    }

    /// What a jump that waited its whole time for the watch's first line says.
    static let unprinted = "SitRep has no board yet: sitrep watch has printed none."
    /// What a jump that waited its whole time on a stale board says, before why, as the views say it.
    static let unread = "SitRep can't read the board"

    /// The watch's last look; none before its first.
    private var last: LastBoard?
    /// Why no plugin runs the watch, while none does.
    private var unrun: String?
    private var waiting: [Int: CheckedContinuation<Read, Never>] = [:]
    private var asked = 0

    public init() {}

    /// Each look of the watch.
    public func heard(_ last: LastBoard) {
        self.last = last
        unrun = nil
        settle()
    }

    /// No plugin to run the watch, for the reason given: no board will come until one does.
    public func unrun(_ why: String) {
        unrun = why
        settle()
    }

    public func current() async -> Read {
        if let read {
            return read
        }

        asked += 1

        let id = asked

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(returning: .unread(missing()))
                } else {
                    waiting[id] = continuation
                }
            }
        } onCancel: {
            Task { @MainActor in self.end(id) }
        }
    }

    /// The watch's words for why its board is not there, as the views say them; else that it has printed none.
    public func missing() -> String {
        last?.stale.map { "\(Self.unread): \($0)" } ?? Self.unprinted
    }

    /// The board, from a watch running and printed; else why none will come, while no plugin runs the watch.
    private var read: Read? {
        if let last, let board = last.board, last.stale == nil {
            return .board(board)
        }

        return unrun.map(Read.unread)
    }

    private func settle() {
        guard let read else {
            return
        }

        let settled = waiting.values

        waiting = [:]
        settled.forEach { $0.resume(returning: read) }
    }

    /// A wait whose task was cancelled ends, saying why the board is not there.
    private func end(_ id: Int) {
        waiting.removeValue(forKey: id)?.resume(returning: .unread(missing()))
    }
}
