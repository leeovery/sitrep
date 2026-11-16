import os
import SitRepScreen

/// A clock the test moves: a sleep of a duration it lets pass returns at once, and any other waits until the test passes
/// it, or its task is cancelled. It keeps every sleep asked of it, a held one kept as it is held, so a sleep seen is one
/// `pass` ends.
public final class TestClock: JumpClock {
    private struct State {
        var sleeps: [Duration] = []
        var held: [Int: (Duration, CheckedContinuation<Void, any Error>)] = [:]
        var next = 0
    }

    private let passing: Set<Duration>
    private let state = OSAllocatedUnfairLock(initialState: State())

    public init(passing: Set<Duration> = []) {
        self.passing = passing
    }

    public var sleeps: [Duration] { state.withLock(\.sleeps) }

    public func sleep(for duration: Duration) async throws {
        guard !passing.contains(duration) else {
            state.withLock { $0.sleeps.append(duration) }
            return try Task.checkCancellation()
        }

        let id = state.withLock { state in
            state.next += 1
            return state.next
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state.withLock { state in
                    state.sleeps.append(duration)
                    state.held[id] = (duration, continuation)
                }
                if Task.isCancelled {
                    end(id, throwing: true)
                }
            }
        } onCancel: {
            end(id, throwing: true)
        }
    }

    /// Every sleep of the duration under way ends.
    public func pass(_ duration: Duration) {
        let ids = state.withLock { $0.held.filter { $0.value.0 == duration }.map(\.key) }

        ids.forEach { end($0, throwing: false) }
    }

    private func end(_ id: Int, throwing: Bool) {
        let held = state.withLock { $0.held.removeValue(forKey: id) }

        if throwing {
            held?.1.resume(throwing: CancellationError())
        } else {
            held?.1.resume()
        }
    }
}
