import Foundation
import os

/// A PATH, and where it came from: Lee's login shell, or the fallback when the shell gave none.
public enum FoundPath: Sendable, Equatable {
    case shell(String)
    case fallback(String)

    public var path: String {
        switch self {
        case let .shell(path), let .fallback(path):
            path
        }
    }
}

/// The PATH Lee's own shell has. An app started from the Finder or at login
/// has only the system's, with no Bun or tmux, so it asks Lee's login shell;
/// interactive as well, since `claude` is on only an interactive shell's
/// PATH.
public enum LoginPath {
    static let start = "<sitrep-path>"
    static let end = "</sitrep-path>"

    static let limit: TimeInterval = 10

    private static let logger = Logger(sitrep: "path")

    /// What a child gets when the shell gives no PATH: Homebrew's places, Bun's own, then the system's.
    static func fallback(home: String) -> String {
        "/opt/homebrew/bin:/usr/local/bin:\(home)/.bun/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    /// The shell, asked to print its PATH between markers, since a shell's
    /// start-up files (Oh My Zsh) may print around it.
    static func program(shell: String, environment: [String: String]) -> Program {
        Program(
            executable: URL(fileURLWithPath: shell),
            arguments: ["-l", "-i", "-c", "printf '%s' \"\(start)$PATH\(end)\""],
            environment: environment,
            limit: limit
        )
    }

    /// The PATH between the markers; nil when a marker is missing or nothing is between them.
    static func parse(_ output: String) -> String? {
        guard
            let opened = output.range(of: start),
            let closed = output.range(of: end, range: opened.upperBound..<output.endIndex)
        else {
            return nil
        }

        let path = output[opened.upperBound..<closed.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)

        return path.isEmpty ? nil : path
    }

    /// Lee's login shell's PATH, else the fallback, each logged.
    public static func find(
        shell: String? = userShell(),
        home: String = NSHomeDirectory(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        run: Runner = runProgram
    ) async -> FoundPath {
        let fallingBack = { (why: String) -> FoundPath in
            let path = fallback(home: home)

            logger.error("No PATH from the login shell (\(why, privacy: .public)): falling back to \(path, privacy: .public)")

            return .fallback(path)
        }

        guard let shell else {
            return fallingBack("the user record names no shell")
        }

        do {
            let ran = try await run(program(shell: shell, environment: environment))

            guard let path = parse(ran.stdout) else {
                return fallingBack("\(shell) gave no PATH, exit status \(ran.status)")
            }

            logger.info("PATH from \(shell, privacy: .public): \(path, privacy: .public)")

            return .shell(path)
        } catch {
            return fallingBack("\(shell) \(error)")
        }
    }

    /// The shell in the user record, as the Terminal would start it.
    public static func userShell() -> String? {
        guard let shell = getpwuid(getuid())?.pointee.pw_shell else {
            return nil
        }

        let path = String(cString: shell)

        return path.isEmpty ? nil : path
    }
}

/// Lee's PATH for the CLI's runs. The shell's is asked for once and kept;
/// a fallback serves one run, and the shell is asked again at the next, so
/// a shell slow as Lee logs in costs no more than that run. Runs at once
/// share one asking.
public actor ShellPath {
    private let find: @Sendable () async -> FoundPath
    private var asking: Task<FoundPath, Never>?

    public init(find: @escaping @Sendable () async -> FoundPath = { await LoginPath.find() }) {
        self.find = find
    }

    public func path() async -> String {
        let asking = self.asking ?? Task { await find() }

        self.asking = asking

        let found = await asking.value

        if case .fallback = found, self.asking == asking {
            self.asking = nil
        }

        return found.path
    }
}
