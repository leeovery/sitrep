import Foundation
import os

/// The PATH Lee's own shell has. An app started from the Finder or at login
/// has only the system's, with no Bun or tmux, so it asks Lee's login shell
/// once; interactive as well, since `claude` is on only an interactive
/// shell's PATH.
public enum LoginPath {
    static let start = "<sitrep-path>"
    static let end = "</sitrep-path>"

    /// What a child gets when the shell gives no PATH: Homebrew's places, then the system's.
    public static let fallback = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    static let limit: TimeInterval = 10

    private static let logger = Logger(sitrep: "path")

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
        environment: [String: String] = ProcessInfo.processInfo.environment,
        run: Runner = runProgram
    ) async -> String {
        guard let shell else {
            return fallingBack("the user record names no shell")
        }

        do {
            let ran = try await run(program(shell: shell, environment: environment))

            guard let path = parse(ran.stdout) else {
                return fallingBack("\(shell) gave no PATH, exit status \(ran.status)")
            }

            logger.info("PATH from \(shell, privacy: .public): \(path, privacy: .public)")

            return path
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

    private static func fallingBack(_ why: String) -> String {
        logger.error("No PATH from the login shell (\(why, privacy: .public)): falling back to \(fallback, privacy: .public)")

        return fallback
    }
}
