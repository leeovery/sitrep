import Foundation
import os

/// A marketplace as `claude plugin marketplace list --json` lists it: its name, its kind of source (`directory`,
/// `github`, `git`, `url`…) and where that is.
public struct Marketplace: Decodable, Equatable, Sendable {
    public let name: String
    public let source: String
    public let path: String?
    public let repo: String?
    public let url: String?
    /// Where Claude Code keeps it: a `directory` one's own folder, else its copy in Claude's own folder.
    public let installLocation: String?
}

/// A plugin as `claude plugin list --json` lists it: its id, `sitrep@sitrep`, the version Claude's record of it says,
/// and where Claude Code keeps and loads it.
public struct InstalledPlugin: Decodable, Equatable, Sendable {
    public let id: String
    public let version: String?
    /// Its copy in Claude's own folder.
    public let installPath: String?
    /// The folder it loads in place from, for one from a `directory` marketplace whose folder reads; Claude leaves it
    /// out for one that does not, and would then load nothing of it.
    public let readFromFolder: String?

    /// Its own name, `sitrep` of `sitrep@kit`.
    public var name: Substring { id.prefix { $0 != "@" } }

    /// The marketplace it is installed from, `kit` of `sitrep@kit`.
    public var marketplace: Substring { id.firstIndex(of: "@").map { id[id.index(after: $0)...] } ?? "" }
}

/// Claude Code's own CLI, `claude plugin`, run as a child with Lee's PATH and otherwise the app's environment: what
/// it lists of the marketplaces and the plugins, and the steps that install and refresh one.
public struct Claude: Sendable {
    /// A backstop for a `claude` that hangs: each run takes about half a second, a little more to install.
    static let limit: TimeInterval = 60

    private static let logger = Logger(sitrep: "claude")

    let executable: URL
    let path: String
    let environment: [String: String]
    let run: Runner

    public init(executable: URL, path: String, environment: [String: String], run: @escaping Runner) {
        self.executable = executable
        self.path = path
        self.environment = environment
        self.run = run
    }

    /// Where Claude Code's installers put `claude`: its own installer's, Homebrew's, npm's on an Intel Mac, and the
    /// old local install's.
    static func places(home: String) -> [String] {
        ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude", "\(home)/.claude/local/claude"]
    }

    /// The first `claude` that runs, where its installers put it, else on Lee's PATH; nil with none.
    public static func find(home: String, path: String, isExecutable: (String) -> Bool) -> URL? {
        let onPath = path.split(separator: ":").map { "\($0)/claude" }

        return (places(home: home) + onPath).first(where: isExecutable).map(URL.init(fileURLWithPath:))
    }

    public func marketplaces() async throws(PluginTrouble) -> [Marketplace] {
        try await listed(["plugin", "marketplace", "list", "--json"])
    }

    public func plugins() async throws(PluginTrouble) -> [InstalledPlugin] {
        try await listed(["plugin", "list", "--json"])
    }

    public func addMarketplace(_ folder: String) async throws(PluginTrouble) {
        _ = try await claude(["plugin", "marketplace", "add", folder, "--json"])
    }

    public func updateMarketplace(_ name: String) async throws(PluginTrouble) {
        _ = try await claude(["plugin", "marketplace", "update", name, "--json"])
    }

    public func install(_ plugin: String) async throws(PluginTrouble) {
        _ = try await claude(["plugin", "install", plugin, "--json"])
    }

    public func update(_ plugin: String) async throws(PluginTrouble) {
        _ = try await claude(["plugin", "update", plugin, "--json"])
    }

    private func listed<Item: Decodable>(_ words: [String]) async throws(PluginTrouble) -> [Item] {
        let ran = try await claude(words)

        do {
            return try JSONDecoder().decode([Item].self, from: Data(ran.stdout.utf8))
        } catch {
            throw .failed("claude \(words.joined(separator: " ")) printed what SitRep can't read.")
        }
    }

    /// `claude` run on the words given; a run that exits other than 0 fails, in its own words.
    private func claude(_ words: [String]) async throws(PluginTrouble) -> Ran {
        let program = Program(
            executable: executable, arguments: words,
            environment: environment.merging(["PATH": path]) { _, lees in lees }, limit: Self.limit
        )
        let command = "claude \(words.joined(separator: " "))"
        let ran: Ran

        do {
            ran = try await run(program)
        } catch {
            Self.logger.error("\(command, privacy: .public): \(error, privacy: .public)")
            throw .failed("\(command) \(error).")
        }

        Self.logger.info("\(command, privacy: .public): exit status \(ran.status, privacy: .public)")
        guard ran.status == 0 else {
            throw .failed(Self.complaint(ran) ?? "\(command) ended with status \(ran.status).")
        }

        return ran
    }

    /// Why a run failed, as it says it: the `message` of the line `--json` ends on, else its last line on stderr,
    /// which it begins with ✘.
    static func complaint(_ ran: Ran) -> String? {
        struct Outcome: Decodable {
            let message: String
        }

        let last = { (text: String) in
            text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.last { !$0.isEmpty }
        }
        let said = last(ran.stdout).flatMap { try? JSONDecoder().decode(Outcome.self, from: Data($0.utf8)) }?.message
            ?? last(ran.stderr).map { $0.hasPrefix("✘") ? $0.dropFirst().trimmingCharacters(in: .whitespaces) : $0 }

        return said.flatMap { $0.isEmpty ? nil : $0 }
    }
}
