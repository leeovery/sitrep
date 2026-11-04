import Foundation
import os

/// What `sitrep jump` came to: the window brought forward, or why not, in the CLI's words.
public enum JumpAnswer: Sendable, Equatable {
    case jumped
    case refused(String)
}

/// What `sitrep answer`, `finish`, `snooze` or `wake` came to: written, or refused in the CLI's words, with nothing
/// written.
public enum WriteAnswer: Sendable, Equatable {
    case written
    case refused(String)
}

/// What `sitrep screen` came to: which sessions show on screen, or why it could not say, in words.
public enum ScreenAnswer: Sendable, Equatable {
    case read(ScreenReading)
    case failed(String)

    /// The reading; none where the run failed.
    public var reading: ScreenReading? {
        if case let .read(reading) = self { reading } else { nil }
    }
}

/// Lee's answer to an ask, as the button pressed says it: a yes or one of a choice's options, in the board's words;
/// or Lee's ignore, which any ask takes.
public enum Answer: Sendable, Hashable {
    case words(String)
    case ignore
}

/// The plugin's CLI, `<plugin>/bin/sitrep`, run as a child with Lee's PATH.
/// The app watches the board, reads which sessions show on screen, and jumps, and writes only what the board's own
/// buttons do: Lee's answers, finishes, snoozes and wakes.
public struct SitRepCLI: Sendable {
    /// `answer`, `finish`, `snooze` and `wake` read and write one session's files, and run no program.
    static let sessionLimit: TimeInterval = 10
    /// `screen --json` reads the sessions a window holds and asks tmux and `ps`, each given 2s and asked at once: about
    /// 0.2s of CPU over Lee's board, and never hanging over them.
    static let screenLimit: TimeInterval = 10
    /// Only a backstop for a CLI that hangs, well above any realistic jump
    /// (cli/jump.ts, cli/ghostty.ts, cli/front.ts, cli/tmux.ts, cli/apps.ts):
    /// one takes under a second as Ghostty answers, and one Ghostty does not
    /// answer at all, as with the screen locked, is refused at its first
    /// question, after 5s. No true ceiling: the 5s hold for each question to
    /// Ghostty, an Apple Event, and a program sends several (a listing three
    /// a try, a focus two, a find some 40), so a Ghostty answering every
    /// question only just inside its 5s could keep a jump going past this,
    /// and the app would then report that the jump did not answer. Each place
    /// a jump tries adds at most 2s for tmux's select (made once a jump), 2s
    /// for each lsappinfo look that an app is running, and 2s for its `open`:
    /// a few places at most, far under this.
    static let jumpLimit: TimeInterval = 180

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

    /// Which sessions a live window holds show on a terminal of this Mac. Read-only: it asks tmux and `ps`, and moves
    /// nothing.
    public func screen() async -> ScreenAnswer {
        switch await sitrep(["screen", "--json"], limit: Self.screenLimit) {
        case let .failure(unanswered):
            .failed(unanswered.complaint(of: "screen"))
        case let .success(ran):
            Self.reading(ran.stdout)
        }
    }

    private static func reading(_ json: String) -> ScreenAnswer {
        do {
            return .read(try ScreenReading.read(json))
        } catch {
            return .failed("sitrep screen \(error).")
        }
    }

    public func jump(to work: String) async -> JumpAnswer {
        switch await sitrep(["jump", "--session", work], limit: Self.jumpLimit) {
        case .success:
            .jumped
        case let .failure(unanswered):
            .refused(unanswered.complaint(of: "jump"))
        }
    }

    /// Answers an ask of the session, or ignores it, into the session's inbox. The ask and the answer come after
    /// `--`, so neither is read as a flag, whatever its words.
    public func answer(_ ask: String, of session: String, with answer: Answer) async -> WriteAnswer {
        let words = switch answer {
        case let .words(words): ["--session", session, "--", ask, words]
        case .ignore: ["--session", session, "--ignore", "--", ask]
        }

        return written(await sitrep(["answer"] + words, limit: Self.sessionLimit), by: "answer")
    }

    /// Finishes a session no window holds.
    public func finish(_ session: String) async -> WriteAnswer {
        written(await sitrep(["finish", "--session", session], limit: Self.sessionLimit), by: "finish")
    }

    /// Snoozes asks of the session until the instant given, all of them or none. The asks come after `--`, as an
    /// answer's do.
    public func snooze(_ asks: [String], of session: String, until: Date) async -> WriteAnswer {
        let until = String(Int64((until.timeIntervalSince1970 * 1000).rounded()))
        let words = ["snooze", "--until", until, "--session", session, "--"] + asks

        return written(await sitrep(words, limit: Self.sessionLimit), by: "snooze")
    }

    /// Wakes snoozed asks of the session now, all of them or none.
    public func wake(_ asks: [String], of session: String) async -> WriteAnswer {
        written(await sitrep(["wake", "--session", session, "--"] + asks, limit: Self.sessionLimit), by: "wake")
    }

    private func written(_ ended: Ended, by command: String) -> WriteAnswer {
        switch ended {
        case .success:
            .written
        case let .failure(unanswered):
            .refused(unanswered.complaint(of: command))
        }
    }

    /// The CLI run on the words given; a run that exits other than 0 is a failure, as one that never ends is.
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

        return Program(executable: executable, arguments: words, environment: environment, limit: limit)
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
