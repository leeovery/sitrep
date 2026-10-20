import Foundation
import SitRepCore

/// General's card for the Claude plugin SitRep runs (DESIGN, "Settings"): its version, the windows running it, and
/// those that need `/reload-plugins`, as the menu lists them.
public struct PluginCard: Equatable, Sendable {
    public let title: String
    public let line: String
    /// The windows on an old sitrep, which Show lists, a click jumping to each.
    public let reloads: [MenuBoard.Reload]
    /// Every window runs the plugin as it stands: a board read, none needing `/reload-plugins`.
    public let isCurrent: Bool

    /// The plugin as the board last heard says it, run from the folder given. While the board is stale it says so,
    /// and when it was last current, in place of the windows, since they are as `watch` last saw them.
    public init(_ last: LastBoard, folder: String, clock: Date.FormatStyle = .init(date: .omitted, time: .shortened)) {
        let board = last.board
        let version = board?.version

        title = version.map { "sitrep \($0) for Claude Code" } ?? "sitrep for Claude Code"
        guard last.stale == nil else {
            let asOf = last.staleSince.map { " · as of \($0.formatted(clock))" } ?? ""

            line = "From \(folder) · \(MenuBoard.unreadTitle)\(asOf)"
            reloads = []
            isCurrent = false
            return
        }

        reloads = MenuBoard.Reload.windows(of: board)
        isCurrent = board != nil && reloads.isEmpty
        line = "From \(folder) · " + Self.windows(board, version: version, old: reloads.count)
    }

    /// With no plugin to run, it says why.
    public init(unrun why: String) {
        title = "sitrep for Claude Code"
        line = why
        reloads = []
        isCurrent = false
    }

    private static func windows(_ board: Board?, version: String?, old: Int) -> String {
        guard let board else {
            return "looking for the windows running it…"
        }

        let count = board.windows.count
        let windows = "\(count) window\(count == 1 ? "" : "s")"

        return switch (count, old, version) {
        case (0, _, _): "no window runs it"
        case (_, 0, let version?): count == 1 ? "1 window, on \(version)" : "\(windows), all on \(version)"
        case (_, 0, nil): windows
        default: "\(windows), \(old) need\(old == 1 ? "s" : "") /reload-plugins"
        }
    }
}

/// What macOS lets SitRep do to jump: control Ghostty, asked at the first jump, as macOS's own record of it says.
public enum GhosttyLeave: Equatable, Sendable {
    case allowed
    case denied
    /// Not asked yet: macOS asks at the first jump.
    case unasked
    /// macOS answers only while Ghostty runs.
    case unknown

    /// From what macOS answers when asked, without asking Lee, whether SitRep may send Ghostty Apple Events
    /// (`AEDeterminePermissionToAutomateTarget`).
    public init(_ status: Int32) {
        self = switch status {
        case 0: .allowed
        case -1743: .denied // errAEEventNotPermitted
        case -1744: .unasked // errAEEventWouldRequireUserConsent
        default: .unknown // procNotFound, -600, while Ghostty is not running
        }
    }

    /// The line under "Jump to a session's window".
    public var words: String {
        switch self {
        case .allowed: "Control Ghostty · allowed"
        case .denied: "Control Ghostty · not allowed, so no jump reaches it"
        case .unasked: "Control Ghostty · macOS asks at the first jump"
        case .unknown: "Control Ghostty · macOS says only while Ghostty runs"
        }
    }
}
