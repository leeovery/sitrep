/// What a jump came to: the window brought forward; why not, in plain words; no answer in time, within the jump's limit,
/// as when the Mac is too busy; or stopped, as a later click's jump took its place.
public enum JumpAnswer: Sendable, Equatable {
    case jumped
    case refused(String)
    case unanswered
    case stopped
}

/// What a jump tells as it runs: still no answer after a while, then how it ended.
public enum JumpNews: Sendable, Equatable {
    /// No answer yet, `OneJump.stillAfter` on.
    case still
    /// It ended: brought the window forward, was refused, gave no answer in time, or was stopped as a later click's
    /// jump took its place.
    case ended(JumpAnswer)
}

/// Lets one jump run at a time, the latest click winning: a jump asked for while one runs stops it, its task cancelled,
/// and runs once that one has ended, so the two never run at once. A jump stopped ends between its steps, letting go
/// of any it cannot stop, an Apple Event in flight, so waiting costs only that moment. Lee clicked again: he has
/// changed his mind, or the first is stuck.
///
/// A click on the session a jump runs to, before it says it is still jumping, joins it rather than starting it over: a
/// double-click, or a quick second click, would otherwise stop it midway and start it again. Once it says it is still
/// jumping, a click on it is Lee trying again, and starts it over.
@MainActor
public final class OneJump {
    /// How long a jump runs with no answer before it says it is still jumping.
    public static let stillAfter = Duration.seconds(2)

    /// Each jump's news, once a jump, after every click on it has heard it.
    public var heard: (JumpNews) -> Void = { _ in }

    private let sleep: @Sendable (Duration) async throws -> Void
    private var current: UnderWay?

    /// `sleep` waits out `stillAfter`: the tests' clock, in place of the real one.
    public init(sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.sleep = sleep
    }

    /// Runs a jump to the session, stopping any running, unless one to the same session runs that has not yet said it
    /// is still jumping, which this click joins. `told` hears this click's news: `.still` once the jump has run
    /// `stillAfter` with no answer, then how it ended; one stopped by a later jump ends `.stopped`, whatever it came
    /// to, and says no more.
    public func run(
        to session: String, _ jump: @escaping @Sendable () async -> JumpAnswer,
        told: @escaping @MainActor (JumpNews) -> Void
    ) {
        if let current, current.session == session, !current.isStill {
            current.clicks.append(told)
            return
        }

        let previous = current
        let running = UnderWay(session: session, told: told)

        previous?.stop()
        current = running
        running.timer = Task { [sleep] in
            guard (try? await sleep(Self.stillAfter)) != nil, !Task.isCancelled else {
                return
            }

            running.isStill = true
            self.tell(running, .still)
        }
        running.task = Task {
            await previous?.task?.value

            let answer = Task.isCancelled ? .stopped : await jump()

            running.timer?.cancel()
            if self.current === running {
                self.current = nil
            }
            self.tell(running, .ended(Task.isCancelled ? .stopped : answer))
        }
    }

    private func tell(_ running: UnderWay, _ news: JumpNews) {
        running.clicks.forEach { $0(news) }
        heard(news)
    }

    /// A jump under way: its session, the clicks on it, whether it has said it is still jumping, and its tasks.
    @MainActor
    private final class UnderWay {
        let session: String
        var clicks: [@MainActor (JumpNews) -> Void]
        var isStill = false
        var task: Task<Void, Never>?
        var timer: Task<Void, Never>?

        init(session: String, told: @escaping @MainActor (JumpNews) -> Void) {
            self.session = session
            clicks = [told]
        }

        /// Its task cancelled, which ends it between its steps, and no word of still jumping.
        func stop() {
            task?.cancel()
            timer?.cancel()
        }
    }
}
