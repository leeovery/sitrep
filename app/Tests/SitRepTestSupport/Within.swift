import os
import Testing

/// What a wait is given, or nil once the time is up, slept out on the caller's actor as `until(within:)` sleeps it, which
/// fails the test at the caller rather than let it wait on what never comes. `start` is handed the call that gives the
/// answer, to keep where the answer comes from, a double's continuation say; only the first answer counts.
public func answer<Value: Sendable>(
    within limit: Duration, _ comment: Comment? = nil, isolation: isolated (any Actor)? = #isolation,
    sourceLocation: SourceLocation = #_sourceLocation, _ start: (@escaping @Sendable (Value) -> Void) -> Void
) async -> Value? {
    let first = FirstAnswer<Value>()

    start { first.give(.given($0)) }

    let timer = Task {
        _ = await sleepOut(limit, isolation: isolation) { first.isAnswered }
        first.give(.ranOut)
    }

    defer { timer.cancel() }
    guard case let .given(value) = await first.value() else {
        let why = comment.map { ": \($0.rawValue)" } ?? "."

        Issue.record("The wait ran out of time\(why)", sourceLocation: sourceLocation)
        return nil
    }

    return value
}

/// The task's value, or nil once the time is up, which fails the test at the caller; the task, cancelled then, is let
/// go, never waited on.
@discardableResult
public func value<Value: Sendable>(
    of task: Task<Value, Never>, within limit: Duration, _ comment: Comment? = nil,
    isolation: isolated (any Actor)? = #isolation, sourceLocation: SourceLocation = #_sourceLocation
) async -> Value? {
    let value = await answer(within: limit, comment, sourceLocation: sourceLocation) { give in
        Task { give(await task.value) }
    }

    if value == nil {
        task.cancel()
    }
    return value
}

/// How a task that may throw ended, or nil once the time is up, as `value(of:within:)`.
@discardableResult
public func result<Value: Sendable>(
    of task: Task<Value, any Error>, within limit: Duration, _ comment: Comment? = nil,
    isolation: isolated (any Actor)? = #isolation, sourceLocation: SourceLocation = #_sourceLocation
) async -> Result<Value, any Error>? {
    let result = await answer(within: limit, comment, sourceLocation: sourceLocation) { give in
        Task { give(await task.result) }
    }

    if result == nil {
        task.cancel()
    }
    return result
}

/// Once the task, where there is one, has ended, or once the time is up, failing the test at the caller, as
/// `value(of:within:)`.
public func ended(
    _ task: Task<Void, Never>?, within limit: Duration, _ comment: Comment? = nil,
    isolation: isolated (any Actor)? = #isolation, sourceLocation: SourceLocation = #_sourceLocation
) async {
    if let task {
        await value(of: task, within: limit, comment, sourceLocation: sourceLocation)
    }
}

/// The first of a wait's answer and its running out of time; the other dropped.
private final class FirstAnswer<Value: Sendable>: Sendable {
    enum Answer: Sendable {
        case given(Value)
        case ranOut
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
