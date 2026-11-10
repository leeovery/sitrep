/// What a jump came to: the window brought forward; no window showing the session, but one to be opened for it, which
/// comes next; a window opened for it; one opened for it a moment ago, which it is not on screen in yet; why not, in
/// plain words, a jump's or a window's that could not be opened; no answer in time, within the jump's limit, as when
/// the Mac is too busy; or stopped, as a later click's jump took its place.
public enum JumpAnswer: Sendable, Equatable {
    case jumped
    case openable
    case opened
    case opening
    case refused(String)
    case unopened(String)
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
/// jumping, a click on it is Lee trying again, and starts it over. A jump waiting on Lee, as for his choice of where a
/// window opens, never says it is still jumping while it waits (`Hold`), so a click on its session joins it then.
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

    /// Runs a jump to the session, as `run(to:_:told:)` with a hold does, the jump never waiting on Lee.
    public func run(
        to session: String, _ jump: @escaping @Sendable () async -> JumpAnswer,
        told: @escaping @MainActor (JumpNews) -> Void
    ) {
        run(to: session, { _ in await jump() }, told: told)
    }

    /// Runs a jump to the session, stopping any running, unless one to the same session runs that has not yet said it
    /// is still jumping, which this click joins. `told` hears this click's news: `.still` once the jump has run
    /// `stillAfter` with no answer, not counting what it waits on Lee through its `Hold`, then how it ended; one
    /// stopped by a later jump ends `.stopped`, whatever it came to, and says no more.
    public func run(
        to session: String, _ jump: @escaping @Sendable (Hold) async -> JumpAnswer,
        told: @escaping @MainActor (JumpNews) -> Void
    ) {
        if let current, current.session == session, !current.isStill {
            current.clicks.append(told)
            return
        }

        let previous = current
        let running = UnderWay(session: session, told: told)
        let hold = Hold { [weak self] isHeld in
            await self?.hold(running, isHeld)
        }

        previous?.stop()
        current = running
        startStill(running)
        running.task = Task {
            await previous?.task?.value

            let answer = Task.isCancelled ? .stopped : await jump(hold)

            running.timer?.cancel()
            if self.current === running {
                self.current = nil
            }
            self.tell(running, .ended(Task.isCancelled ? .stopped : answer))
        }
    }

    /// The word of still jumping, `stillAfter` from now, for a jump still running.
    private func startStill(_ running: UnderWay) {
        running.timer = Task { [sleep] in
            guard (try? await sleep(Self.stillAfter)) != nil, !Task.isCancelled else {
                return
            }

            running.isStill = true
            self.tell(running, .still)
        }
    }

    /// The word of still jumping held while the jump waits on Lee, and its time started afresh once he has answered.
    private func hold(_ running: UnderWay, _ isHeld: Bool) {
        running.timer?.cancel()
        if !isHeld, current === running, !running.isStill {
            startStill(running)
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

    /// What lets a jump wait on Lee without saying it is still jumping: his choice takes as long as he takes, and a
    /// click on its session meanwhile joins it rather than starting it over. A click on another session still stops
    /// it, its task cancelled, which what it waits on is to hear.
    public struct Hold: Sendable {
        private let held: @Sendable (Bool) async -> Void

        init(_ held: @escaping @Sendable (Bool) async -> Void) {
            self.held = held
        }

        /// What `asking` answers, the word of still jumping held while it is asked.
        public func whileWaitingOnLee<Answer: Sendable>(
            _ asking: @Sendable () async -> Answer
        ) async -> Answer {
            await held(true)

            let answer = await asking()

            await held(false)
            return answer
        }
    }
}
