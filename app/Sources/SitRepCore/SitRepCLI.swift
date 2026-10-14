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
    /// Only a backstop for a CLI that hangs, above the longest a jump can
    /// take (cli/jump.ts, cli/ghostty.ts, cli/front.ts): tmux and `ps` 2s;
    /// Ghostty's terminals listed up to three times, 5s each; then, for each
    /// device, its remembered terminal's focus (5s), the find (about 1s of
    /// looking, or 5s for a question that goes unanswered) and the
    /// put-back's listing again, 15s at most; then the watch on the front,
    /// about 10s at worst. About 27s plus 26s a device: 80s over two
    /// devices, 131s over four, 157s over five.
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
        let environment = environment.merging(["PATH": await path()]) { _, lees in lees }
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
    static let prefix = "sitrep: "

    /// The first line of stderr the CLI wrote as its own, its prefix
    /// dropped; else the first with anything on it, such as the head of a
    /// Bun stack trace. One line, as it fits a menu item or a banner.
    var complaint: String? {
        let lines = stderr.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let own = lines.compactMap { $0.hasPrefix(Self.prefix) ? String($0.dropFirst(Self.prefix.count)) : nil }

        return (own + lines).first { !$0.isEmpty }
    }
}
