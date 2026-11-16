import Foundation
import os
import Testing

extension Trait where Self == Backstop {
    /// A minute for each test, slept out on the main actor, which every suite carries (`BackstopTests`).
    public static var backstop: Self {
        Backstop(limit: .seconds(60))
    }
}

/// Fails a test whose body runs past its limit, rather than let the run sit on it: a wait on what never comes, a
/// double's continuation never resumed, hangs a test, and `.timeLimit` records the overrun only once the body ends,
/// which a hung one never does. The limit is slept out on the main actor, which every app test shares, as
/// `until(within:)` sleeps one out, so a loaded run stretches it.
///
/// The hung body cannot be let go: Swift Testing lends a scope its body only for the length of the call, and one held
/// past it (`withoutActuallyEscaping`) traps as the call returns. So the test is failed and left hanging, the rest of
/// the run goes on, and once every other test has ended the run ends (`InFlight`), where it would sit idle for ever.
public struct Backstop: SuiteTrait, TestTrait, TestScoping {
    let limit: Duration

    public var isRecursive: Bool { true }

    /// Each test case, never the suite as a whole.
    public func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? {
        testCase == nil ? nil : self
    }

    public func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
    ) async throws {
        let running = InFlight.shared.began()
        let watch = Task { [limit] in
            let slept = await sleepOut(limit, tick: .milliseconds(250), isolation: MainActor.shared) { running.hasEnded }

            guard !slept.isDone, !Task.isCancelled else {
                return
            }

            let why = slept.ranOut("for the test to end", nil).rawValue

            Issue.record(
                "\(test.name) ran past its backstop: it is left hanging, and the run ends once every other test has. \(why)",
                sourceLocation: test.sourceLocation
            )
            InFlight.shared.hung()
        }

        defer {
            running.end()
            watch.cancel()
        }
        try await function()
    }
}

/// The tests under way, and those of them hung past their backstop: once the hung are all that is left, and stay so
/// for a while, as no test is still to start, the run ends, failed.
final class InFlight: Sendable {
    static let shared = InFlight()

    /// How long the hung must be all that is left before the run ends: tests still to start begin as others end.
    private static let quiet = 10

    private struct State {
        var running = 0
        var hung = 0
        var isWatching = false
    }

    /// A test under way, until it ends.
    final class Running: Sendable {
        private let ended = OSAllocatedUnfairLock(initialState: false)
        private let inFlight: InFlight

        fileprivate init(_ inFlight: InFlight) {
            self.inFlight = inFlight
        }

        var hasEnded: Bool { ended.withLock { $0 } }

        func end() {
            ended.withLock { $0 = true }
            inFlight.state.withLock { $0.running -= 1 }
        }
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func began() -> Running {
        state.withLock { $0.running += 1 }
        return Running(self)
    }

    /// A test hung past its backstop: from the first, the run is watched for the hung to be all that is left.
    func hung() {
        let watches = state.withLock { state in
            state.hung += 1
            defer { state.isWatching = true }
            return !state.isWatching
        }

        if watches {
            Thread.detachNewThread { self.endOnceOnlyTheHungAreLeft() }
        }
    }

    private func endOnceOnlyTheHungAreLeft() {
        var quietFor = 0

        while quietFor < Self.quiet {
            Thread.sleep(forTimeInterval: 1)
            quietFor = state.withLock { $0.running == $0.hung } ? quietFor + 1 : 0
        }

        let hung = state.withLock(\.hung)

        FileHandle.standardError.write(Data("Every other test has ended; \(hung) hung past the backstop, so the run ends.\n".utf8))
        exit(EXIT_FAILURE)
    }
}
