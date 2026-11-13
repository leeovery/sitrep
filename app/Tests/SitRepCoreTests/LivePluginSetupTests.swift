import Foundation
import os
@testable import SitRepCore
import Testing

/// The folder `SITREP_LIVE_CLAUDE` names, holding `carried`, the plugin a bundle carries: each live run's own Claude
/// config (`CLAUDE_CONFIG_DIR`), Application Support and board go in a folder of its own there, so it never touches
/// Claude's own.
private let live = ProcessInfo.processInfo.environment["SITREP_LIVE_CLAUDE"].map { URL(fileURLWithPath: $0) }

/// SitRep's setup run on the real `claude` and the real file system, as the app starts. Only when
/// `SITREP_LIVE_CLAUDE` names a folder for it.
@Suite(.enabled(if: live != nil), .serialized)
struct LivePluginSetupTests {
    /// One run's world: its config, its Application Support, the plugin carried, and the `claude` runs it made.
    private final class World: Sendable {
        let folder: URL
        let carried: URL
        let config: URL
        let own: URL
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let environment: [String: String]
        let claude: Claude
        private let kept = OSAllocatedUnfairLock<[String]>(initialState: [])

        init(_ name: String) throws {
            let live = try #require(live)

            folder = live.appending(path: name)
            carried = live.appending(path: "carried")
            config = folder.appending(path: "config")
            own = folder.appending(path: "Application Support/sitrep")
            environment = ProcessInfo.processInfo.environment.merging(["CLAUDE_CONFIG_DIR": config.path]) { $1 }
            try #require(FileManager.default.fileExists(atPath: carried.path))
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)

            let found = try #require(Claude.find(home: NSHomeDirectory(), path: path) { FileManager.default.isExecutableFile(atPath: $0) })

            claude = Claude(executable: found, path: path, environment: environment, run: runProgram)
        }

        var runs: [String] { kept.withLock { $0 } }

        func setup(carrying carried: URL? = nil) -> PluginSetup {
            let runner: Runner = { [self] program in
                kept.withLock { $0.append(program.arguments.joined(separator: " ")) }
                return try await runProgram(program)
            }

            return PluginSetup(
                copies: PluginCopies(carried: carried ?? self.carried, own: own), remembered: RememberedPlugin.inMemory().remembered,
                path: { [path] in path }, environment: environment, run: runner
            )
        }

        /// A clone of Lee's, its marketplace added and its plugin installed, as on this Mac.
        func clone() async throws -> URL {
            let clone = folder.appending(path: "Code/sitrep")

            try FileManager.default.createDirectory(at: clone.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: carried, to: clone)
            try await claude.addMarketplace(clone.path)
            try await claude.install(PluginPlan.plugin)
            return clone
        }
    }

    private static let lists = ["plugin marketplace list --json", "plugin list --json"]

    @Test func aFirstStartARelaunchAndAnUpdate() async throws {
        let world = try World("install")
        let next = world.folder.appending(path: "carried-next")

        #expect(await world.setup().look() == .running(.own, folder: world.own.path))
        #expect(world.runs == Self.lists + ["plugin marketplace add \(world.own.path) --json", "plugin install sitrep@sitrep --json"])
        #expect(try await world.claude.marketplaces().map(\.path) == [world.own.path])
        #expect(try await world.claude.plugins().map(\.readFromFolder) == [world.own.path])

        var seen = world.runs.count

        #expect(await world.setup().look() == .running(.own, folder: world.own.path))
        #expect(Array(world.runs.dropFirst(seen)) == Self.lists)

        try FileManager.default.copyItem(at: world.carried, to: next)
        try Self.bump(next.appending(path: ".claude-plugin/plugin.json"), to: "9.9.9")
        try Data("next".utf8).write(to: next.appending(path: PluginCopies.buildFile))
        seen = world.runs.count

        #expect(await world.setup(carrying: next).look() == .running(.own, folder: world.own.path))
        #expect(Array(world.runs.dropFirst(seen)) == Self.lists + ["plugin marketplace update sitrep --json", "plugin update sitrep@sitrep --json"])
        #expect(PluginCopies.version(world.own) == "9.9.9")
        #expect(try await world.claude.plugins().map(\.version) == ["9.9.9"])

        let state = world.folder.appending(path: "state")
        let cli = SitRepCLI(plugin: world.own, path: { [path = world.path] in path }, environment: world.environment.merging(["XDG_STATE_HOME": state.path]) { $1 })

        #expect(await cli.wake("sr-zzzzzz") == .refused("There is no session sr-zzzzzz on the board, in any project."))
    }

    /// The first reviewer's state: Claude's record of its marketplaces gone, so `marketplace list` says `[]`, while
    /// its settings still declare the clone and the plugin reads from it.
    @Test func aCloneWhoseMarketplaceRecordIsGoneIsLeftAsItIs() async throws {
        let world = try World("no-record")
        let clone = try await world.clone()
        let settings = world.config.appending(path: "settings.json")

        try FileManager.default.removeItem(at: world.config.appending(path: "plugins/known_marketplaces.json"))

        let before = try Data(contentsOf: settings)
        let standing = await world.setup().look()

        #expect(world.runs == Self.lists)
        #expect(standing == .running(.folder(clone.path), folder: clone.path))
        #expect(try Data(contentsOf: settings) == before)
        #expect(!FileManager.default.fileExists(atPath: world.own.path))
    }

    /// The second reviewer's state: the clone's `marketplace.json` gone, so Claude lists the plugin without the
    /// folder it reads from, and its installPath is the stale copy in its cache.
    @Test func aCloneWithoutItsMarketplaceFileIsNeverRunFromClaudesCache() async throws {
        let world = try World("no-marketplace-file")
        let clone = try await world.clone()

        try FileManager.default.removeItem(at: clone.appending(path: ".claude-plugin/marketplace.json"))

        let cache = try #require(try await world.claude.plugins().first?.installPath)
        let standing = await world.setup().look()

        #expect(world.runs == Self.lists)
        #expect(standing.trouble == .unfound(.folder(clone.path)))
        #expect(standing.folder != cache)
        #expect(!FileManager.default.fileExists(atPath: world.own.path))
    }

    private static func bump(_ manifest: URL, to version: String) throws {
        var json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])

        json["version"] = version
        try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]).write(to: manifest)
    }
}
