/// What a jump tells as it runs: still no answer after a while, then how it ended.
public enum JumpNews: Sendable, Equatable {
    /// No answer yet, `OneJump.stillAfter` on.
    case still
    /// It ended: brought the window forward, was refused, gave no answer within its limit, or was stopped as a later
    /// click's jump took its place.
    case ended(JumpAnswer)
}

/// Lets one jump run at a time, the latest click winning: a jump asked for while one runs stops it, and its CLI with
/// every program it started, so the two never knock on one terminal at once (which can leave it reporting `$HOME`, as
/// the later takes the earlier's marker for a directory it cannot know), and nothing of the earlier brings a window
/// forward late. Lee clicked again: he has changed his mind, or the first is stuck.
@MainActor
public final class OneJump {
    /// How long a jump runs with no answer before it says it is still jumping.
    public static let stillAfter = Duration.seconds(2)

    private let sleep: @Sendable (Duration) async throws -> Void
    private var running: Task<Void, Never>?
    private var still: Task<Void, Never>?

    /// `sleep` waits out `stillAfter`: the tests' clock, in place of the real one.
    public init(sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    /// Runs the jump, stopping any running. `told` hears `.still` once it has run `stillAfter` with no answer, then
    /// how it ended; one stopped by a later jump ends `.stopped`, whatever its CLI came to, and says no more.
    public func run(_ jump: @escaping @Sendable () async -> JumpAnswer, told: @escaping @MainActor (JumpNews) -> Void) {
        running?.cancel()
        still?.cancel()

        let still = Task { [sleep] in
            guard (try? await sleep(Self.stillAfter)) != nil, !Task.isCancelled else {
                return
            }

            told(.still)
        }

        self.still = still
        running = Task {
            let answer = await jump()

            still.cancel()
            told(.ended(Task.isCancelled ? .stopped : answer))
        }
    }
}
