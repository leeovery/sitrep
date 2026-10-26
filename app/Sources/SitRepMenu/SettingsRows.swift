import Foundation
import SitRepCore
import SitRepPanel
import SitRepRelay

/// A row of Settings' Notifications and General cards as it stands (DESIGN, "Settings"): its label, the line under it,
/// and what sits in the controls' column. A dot when it's fine, a button when it's Lee's: all well, the row says so
/// with a green dot and a word, and nothing to press; when something wants Lee, its line says what is wrong and a push
/// button takes him to the fix.
public struct SettingsRow: Equatable, Sendable {
    public let label: String
    public let line: String?
    public let side: Side

    /// What sits in the controls' column.
    public enum Side: Equatable, Sendable {
        /// Nothing: SitRep is still asking, or has nothing Lee can do about it.
        case none
        /// All well: a green dot and its word.
        case fine(String)
        /// Something only Lee can do, and where the button takes him.
        case button(String, Fix)
        /// The switch, greyed while it can't take effect.
        case toggle(isEnabled: Bool)
        /// "Show Windows", listing the windows on an older plugin, a click jumping to each.
        case windows([MenuBoard.Reload])
    }

    /// Where a row's button takes Lee.
    public enum Fix: Equatable, Sendable {
        /// SitRep's own page in System Settings › Notifications.
        case notifications
        /// Privacy & Security › Automation, where SitRep's leave for Ghostty is.
        case automation
        /// macOS's own prompt for the leave to control Ghostty, before macOS has asked.
        case allowGhostty
        /// General › Login Items, where macOS waits on Lee's approval.
        case loginItems
    }

    public init(label: String, line: String?, side: Side) {
        self.label = label
        self.line = line
        self.side = side
    }
}

extension SettingsRow {
    private static let pluginLabel = "Claude Code plugin"
    private static let pluginLine = "Puts each Claude Code session on the board"
    private static let looking = "Looking for Claude Code's sitrep plugin…"

    /// The plugin SitRep runs, as SitRep found it, nil while it looks, and the board `watch` last printed: up to date
    /// while every window runs it; the windows on an older one listed; or what went wrong, in the menu's words, with
    /// no dot. SitRep looks again after trouble by itself, so no button.
    public static func plugin(_ last: LastBoard, plugin: PluginStanding?) -> SettingsRow {
        switch plugin {
        case nil:
            SettingsRow(label: pluginLabel, line: looking, side: .none)
        case let .trouble(trouble, _):
            SettingsRow(label: pluginLabel, line: trouble.line, side: .none)
        case .running:
            running(last)
        }
    }

    private static func running(_ last: LastBoard) -> SettingsRow {
        if let stale = last.stale {
            return SettingsRow(label: pluginLabel, line: "\(MenuBoard.unreadTitle): \(stale)", side: .none)
        }
        guard let board = last.board else {
            return SettingsRow(label: pluginLabel, line: pluginLine, side: .none)
        }

        let reloads = MenuBoard.Reload.windows(of: board)

        guard !reloads.isEmpty else {
            return SettingsRow(label: pluginLabel, line: pluginLine, side: .fine("Up to date"))
        }

        return SettingsRow(label: pluginLabel, line: behind(board), side: .windows(reloads))
    }

    /// "Updated to 0.2.0. 3 windows run 0.1.0 until /reload-plugins": the version they run where they share one.
    private static func behind(_ board: Board) -> String {
        let old = board.windows.filter(\.needsReload)
        let shared = Set(old.map(\.version)).count == 1 ? old.first?.version : nil
        let updated = board.version.map { "Updated to \($0). " } ?? ""
        let windows = old.count == 1 ? "1 window runs" : "\(old.count) windows run"

        return "\(updated)\(windows) \(shared ?? "an older version") until /reload-plugins"
    }

    /// Open at login, from the login item's real status, nil before it is read: the switch, or, while macOS waits on
    /// Lee's approval, the way to it.
    public static func login(_ login: LoginItem?) -> SettingsRow {
        guard let login, login.needsApproval else {
            return SettingsRow(label: "Open at login", line: nil, side: .toggle(isEnabled: login != nil))
        }

        return SettingsRow(
            label: "Open at login", line: "Waiting for your approval in System Settings › Login Items",
            side: .button("Login Items Settings…", .loginItems)
        )
    }

    private static let ghosttyLabel = "Bring a session's Ghostty window to the front"

    /// The leave to control Ghostty, worded as macOS words a permission, by what SitRep can do with it; nil before
    /// macOS is asked.
    public static func ghostty(_ leave: GhosttyLeave?) -> SettingsRow {
        switch leave {
        case .allowed:
            SettingsRow(label: ghosttyLabel, line: "So a click on a session jumps to it", side: .fine("Allowed"))
        case .denied:
            SettingsRow(
                label: ghosttyLabel, line: "Not allowed, so a click on a session can't reach its window",
                side: .button("Open System Settings…", .automation)
            )
        case .unasked:
            SettingsRow(
                label: ghosttyLabel, line: "Not asked yet: macOS asks at the first jump",
                side: .button("Allow…", .allowGhostty)
            )
        case .unknown:
            SettingsRow(label: ghosttyLabel, line: "macOS says only while Ghostty runs", side: .none)
        case nil:
            SettingsRow(label: ghosttyLabel, line: "So a click on a session jumps to it", side: .none)
        }
    }

    /// Notify me of a new ask: the switch keeps what Lee left it at, but greys while macOS stops SitRep's
    /// notifications, its line saying what tells him instead, for what shows at the edge.
    public static func notify(_ leave: NoticeLeave?, show: EdgeSettings.Show) -> SettingsRow {
        let label = "Notify me of a new ask"

        guard leave?.stops == true else {
            return SettingsRow(label: label, line: "Silent; a click on it jumps to the session", side: .toggle(isEnabled: true))
        }

        let instead = switch show {
        case .notch: "the notch swells and lights"
        case .strip: "the strip flashes"
        case .nothing: "the menu bar's light comes on"
        }

        return SettingsRow(label: label, line: "Can't while macOS stops it; \(instead) instead", side: .toggle(isEnabled: false))
    }

    /// What macOS lets SitRep do with notifications, as its own settings say, nil before they are read, with the way
    /// to SitRep's page in System Settings once macOS has asked; before, the switch going on asks.
    public static func allowed(_ leave: NoticeLeave?) -> SettingsRow {
        let settings = SettingsRow.Side.button("Notification Settings…", .notifications)
        let place = "in System Settings › Notifications"

        return switch leave {
        case nil:
            SettingsRow(label: "Notifications in macOS", line: nil, side: .none)
        case .unasked:
            SettingsRow(label: "Not asked by macOS yet", line: "macOS asks once Notify me of a new ask is on", side: .none)
        case .denied:
            SettingsRow(label: "Not allowed by macOS", line: "Turn SitRep on \(place)", side: settings)
        case .allowed(.none):
            SettingsRow(label: "Not shown by macOS", line: "Choose banners \(place)", side: settings)
        case .provisional:
            SettingsRow(label: "Allowed by macOS", line: "Quietly, in Notification Center", side: settings)
        case .allowed(.banners):
            SettingsRow(label: "Allowed by macOS", line: "As banners, \(place)", side: settings)
        case .allowed(.alerts):
            SettingsRow(label: "Allowed by macOS", line: "As alerts, \(place)", side: settings)
        }
    }
}

extension NoticeLeave {
    /// macOS shows none of SitRep's notifications: not allowed, or allowed with neither banners nor alerts.
    var stops: Bool {
        self == .denied || self == .allowed(.none)
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
}

extension PluginSource {
    /// Where the plugin comes from: `~/Code/sitrep`, `GitHub, leeovery/sitrep`.
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

    /// The two in a line: the plugin row's, and the notch's, the strip's and the window's with no plugin to run.
    public var line: String { "\(title). \(detail)" }
}
