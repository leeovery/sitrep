import Foundation
import os
@testable import SitRepCore

/// What `claude plugin` printed on Lee's Mac on 20 October 2026, read-only, where the `sitrep` marketplace is the
/// clone, `~/Code/sitrep`, as a folder marketplace, and `sitrep@sitrep` loads in place from it.
enum LeesClaude {
    static let home = "/Users/leeovery"
    static let marketplaces = printed("marketplaces-lee.json")
    static let plugins = printed("plugins-lee.json")

    private static func printed(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: "Claude/\(name)", withExtension: nil),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            fatalError("The fixture \(name) is missing from SitRepCoreTests")
        }

        return text
    }
}

/// `claude plugin marketplace list --json` and `claude plugin list --json` in the shape Claude Code prints them, as a
/// scratch install printed them: a folder marketplace, and a plugin it loads in place.
enum ClaudeLists {
    static func folderMarketplace(_ name: String = "sitrep", path: String) -> String {
        #"{"name": "\#(name)", "source": "directory", "path": "\#(path)", "installLocation": "\#(path)"}"#
    }

    static let github = #"""
    {"name": "sitrep", "source": "github", "repo": "leeovery/sitrep", "installLocation": "/Users/lee/.claude/plugins/marketplaces/sitrep"}
    """#

    static func plugin(_ id: String = "sitrep@sitrep", version: String = "0.2.0", readFrom folder: String? = nil) -> String {
        let read = folder.map { #", "readFromFolder": "\#($0)", "folderVersion": "\#(version)""# } ?? ""

        return #"""
        {"id": "\#(id)", "version": "\#(version)", "scope": "user", "enabled": true, \#
        "installPath": "/Users/lee/.claude/plugins/cache/sitrep/sitrep/\#(version)"\#(read), \#
        "installedAt": "2026-10-20T11:38:42.238Z", "lastUpdated": "2026-10-20T11:38:42.238Z", "projectEnabled": false}
        """#
    }

    /// One installed from a folder marketplace whose folder, or its `marketplace.json`, is gone, as Claude prints it
    /// then: no `readFromFolder`, and its installPath the stale copy in Claude's cache.
    static func unloaded(_ id: String = "sitrep@sitrep", version: String = "0.1.0") -> String {
        #"""
        {"id": "\#(id)", "version": "\#(version)", "scope": "user", "enabled": true, \#
        "installPath": "/Users/lee/.claude/plugins/cache/sitrep/sitrep/\#(version)", \#
        "installedAt": "2026-10-13T20:31:34.339Z", "lastUpdated": "2026-10-13T20:31:34.339Z", \#
        "errors": ["Marketplace sitrep failed to load: cache-miss"], \#
        "errorDetails": [{"type": "marketplace-load-failed", "marketplace": "sitrep"}], "projectEnabled": false}
        """#
    }

    static func list(_ items: String...) -> String {
        "[\(items.joined(separator: ",\n"))]"
    }

    static func marketplaces(_ json: String) -> [Marketplace] {
        decoded(json)
    }

    static func plugins(_ json: String) -> [InstalledPlugin] {
        decoded(json)
    }

    private static func decoded<Item: Decodable>(_ json: String) -> [Item] {
        do {
            return try JSONDecoder().decode([Item].self, from: Data(json.utf8))
        } catch {
            fatalError("Unreadable fixture: \(error)")
        }
    }
}

extension RememberedPlugin {
    /// Kept in memory, starting with the folder given; `read` says what it holds.
    static func inMemory(_ folder: String? = nil) -> (remembered: RememberedPlugin, read: @Sendable () -> String?) {
        let kept = OSAllocatedUnfairLock<String?>(initialState: folder)
        let read: @Sendable () -> String? = { kept.withLock { $0 } }

        return (RememberedPlugin(read: read, write: { folder in kept.withLock { $0 = folder } }), read)
    }
}

/// A `claude` faked: each run answered by its words, `plugin marketplace list` and `plugin list` as given and every
/// other run as given in `answers`, else done; the words of each run kept, in order.
final class FakeClaude: Sendable {
    let executable = URL(fileURLWithPath: "/Users/lee/.local/bin/claude")
    private let marketplaces: String
    private let plugins: String
    private let answers: [String: Ran]
    private let kept = OSAllocatedUnfairLock<[Program]>(initialState: [])

    init(marketplaces: String, plugins: String, answers: [String: Ran] = [:]) {
        self.marketplaces = marketplaces
        self.plugins = plugins
        self.answers = answers
    }

    var programs: [Program] { kept.withLock { $0 } }

    /// The words of each run, as a line each, as a shell would show them.
    var runs: [String] { programs.map { $0.arguments.joined(separator: " ") } }

    var run: Runner {
        { [self] program in
            kept.withLock { $0.append(program) }

            return switch program.arguments.joined(separator: " ") {
            case "plugin marketplace list --json": Ran(status: 0, stdout: marketplaces, stderr: "")
            case "plugin list --json": Ran(status: 0, stdout: plugins, stderr: "")
            case let words: answers[words] ?? Ran(status: 0, stdout: #"{"outcome":"ok"}"#, stderr: "")
            }
        }
    }
}
