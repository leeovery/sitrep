import os
import Testing

/// What a wait is given; one not given before the time is up, slept out on the caller's actor as `until(within:)`
/// sleeps it, ends the test at the caller rather than let it wait on what never comes. `start` is handed the call that
/// gives the answer, to keep where the answer comes from, a double's continuation say; only the first answer counts.
public func answer<Value: Sendable>(
    within limit: Duration, _ comment: Comment? = nil, isolation: isolated (any Actor)? = #isolation,
    sourceLocation: SourceLocation = #_sourceLocation, _ start: (@escaping @Sendable (Value) -> Void) -> Void
) async throws -> Value {
    let raced = await race(limit, start)
    let answered = raced.value

    return try #require(answered, raced.slept.ranOut("for an answer", comment), sourceLocation: sourceLocation)
}

/// The task's value, as `answer(within:)` waits on it; a task not ended in time is cancelled and let go, never waited on.
@discardableResult
public func value<Value: Sendable>(
    of task: Task<Value, Never>, within limit: Duration, _ comment: Comment? = nil,
    isolation: isolated (any Actor)? = #isolation, sourceLocation: SourceLocation = #_sourceLocation
) async throws -> Value {
    let raced = await race(limit) { give in
        Task { give(await task.value) }
    }
    let ended = raced.value

    if ended == nil {
        task.cancel()
    }
    return try #require(ended, raced.slept.ranOut("for the task to end", comment), sourceLocation: sourceLocation)
}

/// How a task that may throw ended, as `value(of:within:)` waits on it.
@discardableResult
public func result<Value: Sendable>(
    of task: Task<Value, any Error>, within limit: Duration, _ comment: Comment? = nil,
    isolation: isolated (any Actor)? = #isolation, sourceLocation: SourceLocation = #_sourceLocation
) async throws -> Result<Value, any Error> {
    let raced = await race(limit) { give in
        Task { give(await task.result) }
    }
    let ended = raced.value

    if ended == nil {
        task.cancel()
    }
    return try #require(ended, raced.slept.ranOut("for the task to end", comment), sourceLocation: sourceLocation)
}

/// Once the task, where there is one, has ended, as `value(of:within:)` waits on it.
public func ended(
    _ task: Task<Void, Never>?, within limit: Duration, _ comment: Comment? = nil,
    isolation: isolated (any Actor)? = #isolation, sourceLocation: SourceLocation = #_sourceLocation
) async throws {
    if let task {
        try await value(of: task, within: limit, comment, sourceLocation: sourceLocation)
    }
}

/// The first answer `start` gives, or nil where the time, slept out on the caller's actor a tick at a time, ran out
/// first; and how long the wait took.
func race<Value: Sendable>(
    _ limit: Duration, tick: Duration = .milliseconds(5), isolation: isolated (any Actor)? = #isolation,
    _ start: (@escaping @Sendable (Value) -> Void) -> Void
) async -> (value: Value?, slept: Slept) {
    let first = FirstAnswer<Value>()

    start { first.give(.given($0)) }

    let timer = Task {
        let slept = await sleepOut(limit, tick: tick, isolation: isolation) { first.isAnswered }

        first.give(.ranOut(slept))
    }

    defer { timer.cancel() }
    switch await first.value() {
    case let .given(value):
        return (value, Slept(limit: limit, isDone: true, took: .zero))
    case let .ranOut(slept):
        return (nil, slept)
    }
}

/// The first of a wait's answer and its running out of time; the other dropped.
private final class FirstAnswer<Value: Sendable>: Sendable {
    enum Answer: Sendable {
        case given(Value)
        case ranOut(Slept)
    }

    private enum State {
        case pending(CheckedContinuation<Answer, Never>?)
        case answered(Answer)
    }

    private let state = OSAllocatedUnfairLock(uncheckedState: State.pending(nil))

    var isAnswered: Bool {
        state.withLock { state in
            if case .answered = state { true } else { false }
        }
    }

    func give(_ answer: Answer) {
        let waiting: CheckedContinuation<Answer, Never>?? = state.withLock { state in
            guard case let .pending(waiting) = state else {
                return nil
            }

            state = .answered(answer)
            return waiting
        }

        waiting??.resume(returning: answer)
    }

    func value() async -> Answer {
        await withCheckedContinuation { continuation in
            let answered: Answer? = state.withLock { state in
                switch state {
                case let .answered(answer):
                    return answer
                case .pending:
                    state = .pending(continuation)
                    return nil
                }
            }

            answered.map { continuation.resume(returning: $0) }
        }
    }
}
