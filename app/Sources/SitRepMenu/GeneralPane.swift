import Foundation
import SitRepCore

/// General's card for the Claude plugin SitRep runs (DESIGN, "Settings"): where it comes from, its version, the
/// windows running it, and those that need `/reload-plugins`, as the menu lists them; or the trouble SitRep met
/// seeing to it.
public struct PluginCard: Equatable, Sendable {
    private static let looking = "Looking for Claude Code's sitrep plugin…"

    public let title: String
    public let line: String
    /// The windows on an old sitrep, which Show lists, a click jumping to each.
    public let reloads: [MenuBoard.Reload]
    /// Every window runs the plugin as it stands: a board read, none needing `/reload-plugins`.
    public let isCurrent: Bool

    /// The plugin as the board last heard says it, and as SitRep found it, nil while it looks. While the board is
    /// stale it says so, and when it was last current, in place of the windows, since they are as `watch` last saw
    /// them.
    public init(
        _ last: LastBoard, plugin: PluginStanding?, clock: Date.FormatStyle = .init(date: .omitted, time: .shortened)
    ) {
        let board = last.board
        let version = board?.version

        title = version.map { "sitrep \($0) for Claude Code" } ?? "sitrep for Claude Code"
        switch plugin {
        case let .running(source, _):
            reloads = last.stale == nil ? MenuBoard.Reload.windows(of: board) : []
            line = "\(source.words) · " + Self.windows(last, version: version, old: reloads.count, clock: clock)
            isCurrent = last.stale == nil && board != nil && reloads.isEmpty
        case let .trouble(trouble, _):
            reloads = []
            line = trouble.line
            isCurrent = false
        case nil:
            reloads = []
            line = Self.looking
            isCurrent = false
        }
    }

    private static func windows(_ last: LastBoard, version: String?, old: Int, clock: Date.FormatStyle) -> String {
        guard last.stale == nil else {
            return MenuBoard.unreadTitle + (last.staleSince.map { " · as of \($0.formatted(clock))" } ?? "")
        }
        guard let board = last.board else {
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

extension PluginSource {
    /// Where the card says the plugin comes from.
    public var words: String {
        self == .own ? "Installed by SitRep" : "From \(place)"
    }

    /// The place itself: `~/Code/sitrep`, `GitHub, leeovery/sitrep`.
    public var place: String {
        switch self {
        case .own: "SitRep's own copy"
        case let .folder(folder): folder
        case let .github(repo): "GitHub, \(repo)"
        case let .other(source): source
        }
    }
}

extension PluginTrouble {
    /// What went wrong, as the menu's speak-up heads it.
    public var title: String {
        switch self {
        case .noClaude: "SitRep can't find Claude Code"
        case .uncarried: "This SitRep carries no plugin"
        case .unfound: "SitRep can't find the sitrep plugin"
        case .failed: "SitRep couldn't set up its plugin"
        }
    }

    /// What to do about it, or what failed.
    public var detail: String {
        switch self {
        case .noClaude: "Install Claude Code, and SitRep will find it."
        case .uncarried: "Build it with app/build."
        case let .unfound(source): "Claude Code has it from \(source.place), where SitRep can't read it."
        case let .failed(why): why
        }
    }

    /// The two in a line: the card's, and the notch's, the strip's and the window's with no plugin to run.
    public var line: String { "\(title). \(detail)" }
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
