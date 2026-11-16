import os

/// A clock the test moves: a sleep of a duration it lets pass returns at once, and any other waits until the test passes
/// it. A cancelled sleep ends at once, throwing, as `Task.sleep` does; or, where the clock holds cancelled sleeps, waits
/// on until the test passes it and returns as any other, so what runs after a sleep has to see the cancellation itself.
/// It keeps every sleep asked of it, a held one kept as it is held, so a sleep seen is one `pass` ends.
public final class TestClock: Sendable {
    private struct State {
        var sleeps: [Duration] = []
        var held: [Int: (Duration, CheckedContinuation<Void, any Error>)] = [:]
        var next = 0
    }

    private let passing: Set<Duration>
    private let holdsCancelled: Bool
    private let state = OSAllocatedUnfairLock(initialState: State())

    public init(passing: Set<Duration>, holdsCancelled: Bool = false) {
        self.passing = passing
        self.holdsCancelled = holdsCancelled
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

        if holdsCancelled {
            return try await hold(id, duration, endingIfCancelled: false)
        }
        try await withTaskCancellationHandler {
            try await hold(id, duration, endingIfCancelled: true)
        } onCancel: {
            end(id, throwing: true)
        }
    }

    /// Every sleep of the duration under way ends.
    public func pass(_ duration: Duration) {
        let ids = state.withLock { $0.held.filter { $0.value.0 == duration }.map(\.key) }

        ids.forEach { end($0, throwing: false) }
    }

    /// Held until passed; a task cancelled before it is held, which its cancellation handler has missed, ends at once.
    private func hold(_ id: Int, _ duration: Duration, endingIfCancelled: Bool) async throws {
        try await withCheckedThrowingContinuation { continuation in
            state.withLock { state in
                state.sleeps.append(duration)
                state.held[id] = (duration, continuation)
            }
            if endingIfCancelled, Task.isCancelled {
                end(id, throwing: true)
            }
        }
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
