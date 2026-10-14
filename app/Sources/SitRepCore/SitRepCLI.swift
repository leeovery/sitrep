import Foundation
import os

/// What `sitrep list` came to: the works on screen, or why there are none to show, in words.
public enum ListAnswer: Sendable, Equatable {
    case works([OnScreen])
    case failed(String)
}

/// What `sitrep jump` came to: the window brought forward, or why not, in the CLI's words.
public enum JumpAnswer: Sendable, Equatable {
    case jumped
    case refused(String)
}

/// The plugin's CLI, `<plugin>/bin/sitrep`, run as a child with Lee's PATH.
/// The app only reads the board and jumps: it never writes to it.
public struct SitRepCLI: Sendable {
    /// `list --json` answers in about 0.15s, and never hangs over tmux or `ps`.
    static let listLimit: TimeInterval = 10
    /// Each question a jump asks Ghostty waits at most 5s, and it may ask several.
    static let jumpLimit: TimeInterval = 30

    private static let logger = Logger(sitrep: "cli")

    let executable: URL
    let environment: [String: String]
    let run: Runner

    /// Every child gets Lee's PATH, and otherwise the app's own environment.
    public init(
        plugin: URL,
        path: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        run: @escaping Runner = runProgram
    ) {
        executable = plugin.appending(path: "bin/sitrep")
        self.environment = environment.merging(["PATH": path]) { _, given in given }
        self.run = run
    }

    public func list() async -> ListAnswer {
        switch await sitrep(["list", "--json"], limit: Self.listLimit) {
        case let .failure(unanswered):
            return .failed(unanswered.complaint(of: "list"))
        case let .success(ran):
            do {
                return .works(try Listing.read(ran.stdout).onScreen)
            } catch {
                return .failed("sitrep list \(error).")
            }
        }
    }

    public func jump(to work: String) async -> JumpAnswer {
        switch await sitrep(["jump", "--work", work], limit: Self.jumpLimit) {
        case .success:
            .jumped
        case let .failure(unanswered):
            .refused(unanswered.complaint(of: "jump"))
        }
    }

    /// The CLI run on the words given; a run that exits other than 0 is a failure, as one that never ends is.
    private func sitrep(_ words: [String], limit: TimeInterval) async -> Ended {
        let program = Program(executable: executable, arguments: words, environment: environment, limit: limit)
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
}

/// How a run of the CLI ended.
typealias Ended = Result<Ran, Unanswered>

/// A run of the CLI that gave no answer: it exited other than 0, or never ran to its end.
enum Unanswered: Error {
    case exited(Ran)
    case unrun(RunError)

    /// Why, in words: the CLI's own when it gave some, which it prints to
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
    static let prefix = "sitrep: "

    var complaint: String? {
        let said = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = said.hasPrefix(Self.prefix) ? String(said.dropFirst(Self.prefix.count)) : said

        return words.isEmpty ? nil : words
    }
}
