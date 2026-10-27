import Foundation
import os

/// The sessions the SitRep window follows, as the app's one `sitrep watch` is told them on its standard input, a
/// `{"follow": [...]}` line giving the whole set: each run is told the set as it starts, before anything else, and
/// again whenever it changes; a look now tells it the set again, as each such line wakes the watch for a look at once.
/// It outlives every run, so a run started after a back-off, a renewal or a move to another plugin follows what the
/// window shows. Told from the main actor, it never waits on a run: a line goes into the run's input, which its
/// watcher writes on its own time.
public final class Following: Sendable {
    private struct Told {
        var sessions: Set<String> = []
        var runs = 0
        /// The run under way, by its place among those begun, and its input.
        var current: (run: Int, input: AsyncStream<String>.Continuation)?
    }

    private let told = OSAllocatedUnfairLock(initialState: Told())

    public init() {}

    /// The window follows these sessions now: the run under way is told, where the set changed.
    public func follow(_ sessions: Set<String>) {
        told.withLock { told in
            guard sessions != told.sessions else {
                return
            }

            told.sessions = sessions
            told.current?.input.yield(Self.line(sessions))
        }
    }

    /// The run under way is told the set again, which has it look at once.
    public func lookNow() {
        told.withLock { told in
            _ = told.current?.input.yield(Self.line(told.sessions))
        }
    }

    /// A run starts: its input, the set its first line.
    func begin() -> RunInput {
        let (lines, input) = AsyncStream<String>.makeStream()

        return told.withLock { told in
            told.runs += 1
            told.current = (told.runs, input)
            input.yield(Self.line(told.sessions))
            return RunInput(lines: lines, input: input, run: told.runs)
        }
    }

    /// A run has ended: it is told nothing more.
    func end(_ run: RunInput) {
        told.withLock { told in
            if told.current?.run == run.run {
                told.current = nil
            }
        }
        run.input.finish()
    }

    /// `{"follow":["sr-k3f9qa",...]}`, the ids sorted, so a set is always the same line. A list of text always encodes.
    private static func line(_ sessions: Set<String>) -> String {
        String(decoding: (try? JSONEncoder().encode(["follow": sessions.sorted()])) ?? Data(), as: UTF8.self)
    }
}

/// What a run of `watch` is told on its standard input, a line at a time, each without its newline.
struct RunInput: Sendable {
    let lines: AsyncStream<String>
    fileprivate let input: AsyncStream<String>.Continuation
    fileprivate let run: Int
}
