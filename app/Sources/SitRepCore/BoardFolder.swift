import Foundation

/// The board's folder, sitrep's, found as core's `rootOf` finds it: `$XDG_STATE_HOME/sitrep` where that names a folder
/// from the root, else `$HOME/.local/state/sitrep`, `home` where `HOME` names none. The app's environment is the one
/// its CLI's `watch` runs with, so a file SitRep writes there sits by the board SitRep shows.
public enum BoardFolder {
    public static func url(environment: [String: String], home: URL) -> URL {
        let absolute = { (key: String) in environment[key].flatMap { $0.hasPrefix("/") ? URL(filePath: $0) : nil } }
        let state = absolute("XDG_STATE_HOME") ?? (absolute("HOME") ?? home).appending(path: ".local/state")

        return state.appending(path: "sitrep")
    }
}
