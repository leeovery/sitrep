import Foundation
import os

/// The folder of the plugin SitRep ran at the last look that went well, kept across starts, for a look that meets
/// trouble to run meanwhile.
public struct RememberedPlugin: Sendable {
    let read: @Sendable () -> String?
    let write: @Sendable (String) -> Void

    public init(read: @escaping @Sendable () -> String?, write: @escaping @Sendable (String) -> Void) {
        self.read = read
        self.write = write
    }

    /// Kept in SitRep's own defaults.
    public static let defaults = RememberedPlugin(
        read: { UserDefaults.standard.string(forKey: key) }, write: { UserDefaults.standard.set($0, forKey: key) }
    )

    private static let key = "pluginFolder"
}

/// SitRep's look at the plugin as it starts (DESIGN, "Installing and updating"): `claude` found, what it lists of
/// the marketplaces and plugins read, the plan's steps taken, and the plugin SitRep then runs. A look that meets
/// trouble runs the plugin of the last look that went well while its folder is there, else SitRep's own copy, and
/// SitRep looks again, waiting longer each time, as it starts `watch` again.
public struct PluginSetup: Sendable {
    private static let logger = Logger(sitrep: "plugin")

    let copies: PluginCopies
    let remembered: RememberedPlugin
    let home: String
    let path: @Sendable () async -> String
    let environment: [String: String]
    let run: Runner
    let isExecutable: @Sendable (String) -> Bool
    let isThere: @Sendable (String) -> Bool
    let entry: @Sendable (String) -> MarketplaceEntry?

    /// Every `claude` gets Lee's PATH and otherwise the app's own environment, as the CLI does.
    public init(
        copies: PluginCopies,
        remembered: RememberedPlugin = .defaults,
        home: String = NSHomeDirectory(),
        path: @escaping @Sendable () async -> String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        run: @escaping Runner = runProgram,
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        isThere: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        entry: @escaping @Sendable (String) -> MarketplaceEntry? = MarketplaceEntry.sitrep(in:)
    ) {
        self.copies = copies
        self.remembered = remembered
        self.home = home
        self.path = path
        self.environment = environment
        self.run = run
        self.isExecutable = isExecutable
        self.isThere = isThere
        self.entry = entry
    }

    /// Each look's standing, as it comes: looking again after trouble, a second after the first, doubling to half a
    /// minute, and ending with the first that runs.
    public func standings(waiting wait: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) })
        -> AsyncStream<PluginStanding>
    {
        AsyncStream { continuation in
            let looking = Task {
                var backoff = Backoff()

                while !Task.isCancelled {
                    let standing = await look()

                    continuation.yield(standing)
                    guard case .trouble = standing else {
                        break
                    }

                    await wait(backoff.wait(after: .zero))
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in looking.cancel() }
        }
    }

    /// One look.
    public func look() async -> PluginStanding {
        let path = await path()
        var standing: PluginStanding

        if let found = Claude.find(home: home, path: path, isExecutable: isExecutable) {
            do {
                standing = try await setUp(Claude(executable: found, path: path, environment: environment, run: run))
            } catch {
                standing = .trouble(error, folder: nil)
            }
        } else {
            standing = .trouble(.noClaude, folder: nil)
        }

        switch standing {
        case let .running(_, folder):
            remembered.write(folder)
        case let .trouble(trouble, _):
            standing = .trouble(trouble, folder: remembered.read().flatMap { isThere($0) ? $0 : nil } ?? copies.ownIfThere)
        }
        Self.logger.info("The plugin: \(String(describing: standing), privacy: .public)")

        return standing
    }

    private func setUp(_ claude: Claude) async throws(PluginTrouble) -> PluginStanding {
        let plan = PluginPlan(
            marketplaces: try await claude.marketplaces(), plugins: try await claude.plugins(), own: copies.standing,
            home: home, entry: entry
        )

        Self.logger.info("Steps: \(String(describing: plan.steps), privacy: .public)")
        for step in plan.steps {
            switch step {
            case .copy: try copies.replace()
            case .addMarketplace: try await claude.addMarketplace(copies.own.path)
            case .updateMarketplace: try await claude.updateMarketplace(PluginPlan.marketplace)
            case .install: try await claude.install(PluginPlan.plugin)
            case .update: try await claude.update(PluginPlan.plugin)
            }
        }

        return plan.standing
    }
}
