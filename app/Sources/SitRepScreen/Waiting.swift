import Dispatch
import os

/// What a jump waits by: its half second's pause, its second's watch of the front, and its limits. The tests' clock
/// moves when they say, in place of the real one.
public protocol JumpClock: Sendable {
    /// Returns once the time has passed; throws `CancellationError` as soon as the task asking is cancelled.
    func sleep(for duration: Duration) async throws
}

/// The real clock.
public struct SystemClock: JumpClock {
    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

/// An operation's answer, or nil once the limit passes or the task asking is cancelled, whichever comes first. What has
/// not answered by then is cancelled and let go, never waited on: a step it is in that cannot be stopped, an Apple
/// Event in flight, runs on in the background, its answer dropped.
func answer<Value: Sendable>(
    within limit: Duration, on clock: any JumpClock, _ operation: @escaping @Sendable () async -> Value
) async -> Value? {
    guard !Task.isCancelled else {
        return nil
    }

    let first = First<Value?>()
    let work = Task { first.answer(await operation()) }
    let timer = Task {
        if (try? await clock.sleep(for: limit)) != nil {
            first.answer(nil)
        }
    }
    let answer = await first.value(onCancel: nil)

    work.cancel()
    timer.cancel()
    return answer
}

/// A blocking call made on a thread of its own, never the main one nor Swift's: its answer, or nil once the task asking
/// is cancelled, the call let go and its answer dropped. A task cancelled already makes no call.
func onThread<Value: Sendable>(_ call: @escaping @Sendable () -> Value) async -> Value? {
    guard !Task.isCancelled else {
        return nil
    }

    let first = First<Value?>()

    DispatchQueue.global().async { first.answer(call()) }
    return await first.value(onCancel: nil)
}

/// The first of several answers to one question, awaited once: whichever comes first is kept, and the rest dropped. One
/// that comes before it is awaited is kept for it, so an answer is never missed for coming early.
final class First<Value: Sendable>: Sendable {
    private enum State {
        case pending(CheckedContinuation<Value, Never>?)
        case answered(Value)
    }

    private let state = OSAllocatedUnfairLock(initialState: State.pending(nil))

    /// Answers, unless answered already.
    func answer(_ value: Value) {
        let waiting: CheckedContinuation<Value, Never>?? = state.withLock { state in
            guard case let .pending(waiting) = state else {
                return nil
            }

            state = .answered(value)
            return waiting
        }

        waiting??.resume(returning: value)
    }

    /// The first answer, once it comes; the one given, should the task awaiting it be cancelled first.
    func value(onCancel cancelled: Value) async -> Value {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let answered: Value? = state.withLock { state in
                    switch state {
                    case let .answered(value):
                        return value
                    case .pending:
                        state = .pending(continuation)
                        return nil
                    }
                }

                answered.map { continuation.resume(returning: $0) }
            }
        } onCancel: {
            answer(cancelled)
        }
    }
}
