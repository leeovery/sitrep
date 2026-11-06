import Foundation
import os

/// What `sitrep jump` came to: the window brought forward; why not, in the CLI's words; no answer in time, within
/// SitRep's limit or an app's, as when the Mac is too busy; or stopped, as a later click's jump took its place.
public enum JumpAnswer: Sendable, Equatable {
    case jumped
    case refused(String)
    case unanswered
    case stopped
}

/// What `sitrep snooze` or `wake` came to: written, or refused in the CLI's words, with nothing written.
public enum WriteAnswer: Sendable, Equatable {
    case written
    case refused(String)
}

/// What a snooze or a wake names: asks of a session, by their ids, or its turn, by the instant the turn ended, as its
/// row's time counts from.
public enum Snoozable: Sendable, Equatable {
    case asks([String])
    case turn(ended: Date)

    /// What a row's Snooze puts off: its turn, by the turn's end, where it is one; else the asks its lines show; none
    /// with neither, as on a row of stops alone or a working one.
    public static func of(isTurn: Bool, ended: Date, asks: [String]) -> Snoozable? {
        if isTurn {
            return .turn(ended: ended)
        }
        return asks.isEmpty ? nil : .asks(asks)
    }

    public var isTurn: Bool {
        if case .turn = self { true } else { false }
    }
}

/// The plugin's CLI, `<plugin>/bin/sitrep`, run as a child with Lee's PATH.
/// The app watches the board and jumps, and writes only what the card's row menu does: Lee's snoozes and wakes.
public struct SitRepCLI: Sendable {
    /// `snooze` and `wake` read and write one session's files, and run no program.
    static let sessionLimit: TimeInterval = 10
    /// How long a whole jump may take, Bun's start and the board's read among it (4 November 2026). One takes under a
    /// second as Ghostty answers, and one Ghostty does not answer at all, as with the screen locked, is refused at its
    /// first question, after 5s; each Ghostty program the CLI runs is killed at 8s, and each of tmux, `ps`, lsappinfo
    /// and `open` at 2s (cli/jump.ts, cli/ghostty.ts, cli/front.ts, cli/tmux.ts, cli/apps.ts). Past this the Mac is
    /// too busy for a jump to land while Lee still wants it. It was 180s, a backstop, until a jump under a load of 250
    /// ran all of it, and every click behind it waited.
    static let jumpLimit: TimeInterval = 15
    /// How long a jump told to end has before it is killed. It was for the knock's marker, which the CLI put back
    /// before it exited; since 6 November 2026 the CLI holds nothing to put back and dies at the signal, so the grace
    /// buys nothing and costs time only for a CLI stuck. Kept as it was, as it harms nothing.
    static let jumpGrace: TimeInterval = 1
    /// How the CLI says an app gave a jump no answer in time, as when the Mac is too busy (cli/main.ts).
    static let unansweredStatus: Int32 = 3

    private static let logger = Logger(sitrep: "cli")

    let executable: URL
    let path: @Sendable () async -> String
    let environment: [String: String]
    let run: Runner

    /// Every child gets Lee's PATH, as it stands at each run, and otherwise the app's own environment.
    public init(
        plugin: URL,
        path: @escaping @Sendable () async -> String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        run: @escaping Runner = runProgram
    ) {
        executable = plugin.appending(path: "bin/sitrep")
        self.path = path
        self.environment = environment
        self.run = run
    }

    /// At its limit, or its task cancelled, the jump is told to end, then killed a grace later, with every program it
    /// started. One an app gave no answer in time ends unanswered, as at the limit.
    public func jump(to work: String) async -> JumpAnswer {
        let ended = await sitrep(
            ["jump", "--session", work], limit: Self.jumpLimit, stopping: .gently(grace: Self.jumpGrace)
        )

        return switch ended {
        case .success:
            .jumped
        case .failure(.unrun(.timedOut)):
            .unanswered
        case let .failure(.exited(ran)) where ran.status == Self.unansweredStatus:
            .unanswered
        case .failure(.unrun(.stopped)):
            .stopped
        case let .failure(unanswered):
            .refused(unanswered.complaint(of: "jump"))
        }
    }

    /// Snoozes what is named of the session until the instant given: asks, all of them or none, which the CLI refuses
    /// with no time; or its turn, with none until it moves.
    public func snooze(_ named: Snoozable, of session: String, until: Date?) async -> WriteAnswer {
        let time = until.map { ["--until", Self.milliseconds($0)] } ?? []
        let words = ["snooze"] + time + ["--session", session] + Self.words(naming: named)

        return written(await sitrep(words, limit: Self.sessionLimit), by: "snooze")
    }

    /// Wakes what is named of the session now, asleep: asks, all of them or none, or its turn.
    public func wake(_ named: Snoozable, of session: String) async -> WriteAnswer {
        let words = ["wake", "--session", session] + Self.words(naming: named)

        return written(await sitrep(words, limit: Self.sessionLimit), by: "wake")
    }

    /// What a snooze or a wake names, as the CLI takes it: asks after `--`, so none is read as a flag; a turn by its
    /// end.
    private static func words(naming named: Snoozable) -> [String] {
        switch named {
        case let .asks(asks): ["--"] + asks
        case let .turn(ended): ["--turn", milliseconds(ended)]
        }
    }

    /// An instant in whole milliseconds since the epoch, as the board keeps every time.
    private static func milliseconds(_ instant: Date) -> String {
        String(Int64((instant.timeIntervalSince1970 * 1000).rounded()))
    }

    private func written(_ ended: Ended, by command: String) -> WriteAnswer {
        switch ended {
        case .success:
            .written
        case let .failure(unanswered):
            .refused(unanswered.complaint(of: command))
        }
    }

    /// The CLI run on the words given; a run that exits other than 0 is a failure, as one that never ends is. Ended
    /// early, it goes with every program it started.
    private func sitrep(_ words: [String], limit: TimeInterval, stopping: Stopping = .group) async -> Ended {
        let program = await self.program(words, limit: limit, stopping: stopping)
        let clock = ContinuousClock()
        let started = clock.now
        let ended: Ended

        do {
            let ran = try await run(program)

            ended = ran.status == 0 ? .success(ran) : .failure(.exited(ran))
        } catch let error as RunError {
            ended = .failure(.unrun(error))
        } catch {
            ended = .failure(.unrun(.unstartable("\(error)")))
        }

        let took = (clock.now - started).formatted(.units(allowed: [.milliseconds], width: .narrow))

        Self.logger.info("sitrep \(words.joined(separator: " "), privacy: .public): \(ended.logged, privacy: .public), in \(took, privacy: .public)")

        return ended
    }

    /// The CLI on the words given, with Lee's PATH as it stands now.
    func program(_ words: [String], limit: TimeInterval, stopping: Stopping = .group) async -> Program {
        let environment = environment.merging(["PATH": await path()]) { _, lees in lees }

        return Program(
            executable: executable, arguments: words, environment: environment, limit: limit, stopping: stopping
        )
    }
}

/// How a run of the CLI ended.
typealias Ended = Result<Ran, Unanswered>

/// A run of the CLI that gave no answer: it exited other than 0, or never ran to its end.
enum Unanswered: Error {
    case exited(Ran)
    case unrun(RunError)

    /// Why, in a line: the CLI's own when it gave some, which it prints to
    /// stderr as `sitrep: <words>`.
    func complaint(of command: String) -> String {
        switch self {
        case let .exited(ran):
            ran.complaint ?? "sitrep \(command) ended with status \(ran.status)."
        case let .unrun(error):
            "sitrep \(command) \(error)."
        }
    }
}

private extension Ended {
    var logged: String {
        switch self {
        case let .success(ran), let .failure(.exited(ran)):
            "exit status \(ran.status)"
        case let .failure(.unrun(error)):
            "\(error)"
        }
    }
}

private extension Ran {
    var complaint: String? { Said(stderr).reason }
}
