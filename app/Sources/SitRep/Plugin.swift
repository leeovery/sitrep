import Foundation
import os
import SitRepCore

/// The plugin this SitRep runs, which `app/build` names in the Info.plist.
enum Plugin {
    /// The Info.plist key `app/build` stamps the plugin's folder under.
    private static let key = "SitRepPlugin"

    static let unbuilt = "This SitRep names no plugin to run: build it with app/build."

    /// The plugin's folder; nil for a SitRep not built by `app/build`.
    static var folder: String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    /// The plugin's CLI, run with Lee's PATH; nil for a SitRep not built by `app/build`.
    static func cli() -> SitRepCLI? {
        guard let folder else {
            Logger(sitrep: "cli").error("No \(key, privacy: .public) in the Info.plist: \(unbuilt, privacy: .public)")

            return nil
        }

        let shellPath = ShellPath()

        return SitRepCLI(plugin: URL(fileURLWithPath: folder), path: { await shellPath.path() })
    }
}
