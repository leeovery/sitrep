import Foundation
import os

/// What `sitrep answer`, `snooze` or `wake` came to: written, or refused in the CLI's words, with nothing written.
public enum WriteAnswer: Sendable, Equatable {
    case written
    case refused(String)
}

/// Lee's answer to an ask: a yes, one of a choice's options or a words ask's words, as the CLI takes them; or his
/// ignore, which any ask takes.
public enum Answer: Sendable, Hashable {
    case words(String)
    case ignore
}

/// The plugin's CLI, `<plugin>/bin/sitrep`, run as a child with Lee's PATH.
/// The app watches the board through it, and writes only what its surfaces do: Lee's answers, snoozes and wakes. It
/// jumps itself (SitRepScreen's `Jump`), as the CLI no longer does.
public struct SitRepCLI: Sendable {
    /// `answer`, `snooze` and `wake` read and write one session's files, and run no program.
    static let sessionLimit: TimeInterval = 10

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

    /// Snoozes the session, everything it needs of Lee, until the instant given, or with none until it moves. `asks` are
    /// those its row showed, after `--` so none is read as a flag: the CLI refuses the snooze where another waits on
    /// Lee, so none is snoozed unseen.
    public func snooze(_ session: String, showing asks: [String], until: Date?) async -> WriteAnswer {
        let time = until.map { ["--until", Self.milliseconds($0)] } ?? []
        let words = ["snooze"] + time + ["--session", session, "--"] + asks

        return written(await sitrep(words, limit: Self.sessionLimit), by: "snooze")
    }

    /// Answers an ask of the session, or ignores it, into the session's inbox. The ask and the answer come after `--`,
    /// as the CLI reads any word before it as a flag, `-h` as a call for its help, so words such as `--force` or
    /// `ls -h` arrive whole.
    public func answer(_ ask: String, of session: String, with answer: Answer) async -> WriteAnswer {
        let words = switch answer {
        case let .words(words): ["--session", session, "--", ask, words]
        case .ignore: ["--session", session, "--ignore", "--", ask]
        }

        return written(await sitrep(["answer"] + words, limit: Self.sessionLimit), by: "answer")
    }

    /// Wakes the session now: everything Lee snoozed of it needs him again.
    public func wake(_ session: String) async -> WriteAnswer {
        written(await sitrep(["wake", "--session", session], limit: Self.sessionLimit), by: "wake")
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
    /// early, it is killed with its process group.
    private func sitrep(_ words: [String], limit: TimeInterval) async -> Ended {
        let program = await self.program(words, limit: limit)
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
    func program(_ words: [String], limit: TimeInterval) async -> Program {
        let environment = environment.merging(["PATH": await path()]) { _, lees in lees }

        return Program(
            executable: executable, arguments: words, environment: environment, limit: limit, stopping: .group
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
