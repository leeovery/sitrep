import Foundation
import SitRepCore
import SitRepMenu

/// The Claude plugin SitRep runs (DESIGN, "Installing and updating"): seen to as the app starts, installing or
/// refreshing SitRep's own copy where neither of Claude's lists has anything of sitrep or the marketplace is its own,
/// and looked at again after trouble until it settles; meanwhile the plugin of the last look that went well, or
/// SitRep's own copy. Whatever asks of the CLI first waits for the first look.
@MainActor
final class Plugin {
    private let setup: PluginSetup
    /// Lee's PATH: his login shell's, asked for once and kept, a fallback serving one asking until the shell answers
    /// (`ShellPath`).
    let path: @Sendable () async -> String
    private var standing: PluginStanding?
    private var waiting: [CheckedContinuation<PluginStanding, Never>] = []

    init() {
        let shellPath = ShellPath()
        let path: @Sendable () async -> String = { await shellPath.path() }

        self.path = path
        setup = PluginSetup(copies: .app, remembered: .standard, path: path)
    }

    /// Looks, and looks again after trouble; `changed` hears each look's standing.
    func start(_ changed: @escaping (PluginStanding) -> Void) {
        Task {
            for await standing in setup.standings() {
                self.standing = standing
                waiting.forEach { $0.resume(returning: standing) }
                waiting = []
                changed(standing)
            }
        }
    }

    /// What the CLI answers; with no CLI to run, `unrun` given why.
    func ask<Answer>(_ asked: (SitRepCLI) async -> Answer, unrun: (String) -> Answer) async -> Answer {
        switch await settled() {
        case let .running(_, folder), let .trouble(_, folder?):
            await asked(cli(at: folder))
        case let .trouble(trouble, nil):
            unrun(trouble.line)
        }
    }

    /// The CLI of the plugin in the folder given.
    func cli(at folder: String) -> SitRepCLI {
        SitRepCLI(plugin: URL(fileURLWithPath: folder), path: path)
    }

    /// The standing as it is, once the first look is done.
    private func settled() async -> PluginStanding {
        if let standing {
            return standing
        }

        return await withCheckedContinuation { waiting.append($0) }
    }
}
