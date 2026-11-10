import Foundation
import os

/// An environment, and where it came from: Lee's login shell's, or SitRep's own with the fallback PATH when the shell
/// gave none.
public enum FoundEnvironment: Sendable, Equatable {
    case shell([String: String])
    case fallback([String: String])

    public var environment: [String: String] {
        switch self {
        case let .shell(environment), let .fallback(environment):
            environment
        }
    }

    public var path: String {
        environment["PATH"] ?? ""
    }
}

/// The environment Lee's own shell has. An app started from the Finder or at login has only the system's, with no Bun
/// or tmux on its PATH, and none of what Lee's startup files set, zmx's `ZMX_DIR` among it; so it asks Lee's login
/// shell, interactive as well, since `claude` is on only an interactive shell's PATH. What a window SitRep opens types
/// its command into is such a shell, so tmux and zmx asked with this see what that command will.
public enum LoginEnvironment {
    static let start = "<sitrep-environment>"
    static let end = "</sitrep-environment>"

    static let limit: TimeInterval = 10

    private static let logger = Logger(sitrep: "path")

    /// What a child's PATH is when the shell gives none: Homebrew's places, Bun's own, then the system's.
    static func fallback(home: String) -> String {
        "/opt/homebrew/bin:/usr/local/bin:\(home)/.bun/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    /// The shell, asked to print its environment between markers, since a shell's start-up files (Oh My Zsh) may
    /// print around it: each variable ended by a NUL, as a value may hold a newline, by the system's own `env`, not
    /// one the PATH puts first.
    static func program(shell: String, environment: [String: String]) -> Program {
        Program(
            executable: URL(fileURLWithPath: shell),
            arguments: ["-l", "-i", "-c", "printf '%s' '\(start)'; /usr/bin/env -0; printf '%s' '\(end)'"],
            environment: environment,
            limit: limit
        )
    }

    /// The variables between the markers, each `name=value`; nil where a marker is missing or they give no PATH.
    static func parse(_ output: String) -> [String: String]? {
        guard
            let opened = output.range(of: start),
            let closed = output.range(of: end, options: .backwards, range: opened.upperBound..<output.endIndex)
        else {
            return nil
        }

        let variables = output[opened.upperBound..<closed.lowerBound].split(separator: "\0").reduce(
            into: [String: String]()
        ) { variables, line in
            if let equals = line.firstIndex(of: "="), equals != line.startIndex {
                variables[String(line[..<equals])] = String(line[line.index(after: equals)...])
            }
        }
        let path = variables["PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return path.isEmpty ? nil : variables
    }

    /// Lee's login shell's environment, else SitRep's own with the fallback PATH, each logged by its PATH alone.
    public static func find(
        shell: String? = userShell(),
        home: String = NSHomeDirectory(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        run: Runner = runProgram
    ) async -> FoundEnvironment {
        let fallingBack = { (why: String) -> FoundEnvironment in
            let path = fallback(home: home)

            logger.error("No PATH from the login shell (\(why, privacy: .public)): falling back to \(path, privacy: .public)")

            return .fallback(environment.merging(["PATH": path]) { _, fallback in fallback })
        }

        guard let shell else {
            return fallingBack("the user record names no shell")
        }

        do {
            let ran = try await run(program(shell: shell, environment: environment))

            guard let found = parse(ran.stdout) else {
                return fallingBack("\(shell) gave no PATH, exit status \(ran.status)")
            }

            logger.info("PATH from \(shell, privacy: .public): \(found["PATH"] ?? "", privacy: .public)")

            return .shell(found)
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

/// Lee's environment for the CLI's runs, and tmux's and zmx's. The shell's is asked for once and kept; a fallback
/// serves one run, and the shell is asked again at the next, so a shell slow as Lee logs in costs no more than that
/// run. Runs at once share one asking.
public actor ShellEnvironment {
    private let find: @Sendable () async -> FoundEnvironment
    private var asking: Task<FoundEnvironment, Never>?

    public init(find: @escaping @Sendable () async -> FoundEnvironment = { await LoginEnvironment.find() }) {
        self.find = find
    }

    public func environment() async -> [String: String] {
        await found().environment
    }

    public func path() async -> String {
        await found().path
    }

    private func found() async -> FoundEnvironment {
        let asking = self.asking ?? Task { await find() }

        self.asking = asking

        let found = await asking.value

        if case .fallback = found, self.asking == asking {
            self.asking = nil
        }

        return found
    }
}
