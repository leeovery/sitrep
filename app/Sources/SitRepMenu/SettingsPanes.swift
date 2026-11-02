import SitRepCore
import SitRepEdge

/// The Settings window's panes, as its sidebar lists them, top to bottom (DESIGN, "Settings").
public enum SettingsPane: String, Codable, CaseIterable, Sendable, Identifiable {
    case general, edge, notifications, claudeCode

    public var id: Self { self }

    /// Its name, in the sidebar and as the window's title.
    public var title: String {
        switch self {
        case .general: "General"
        case .edge: "Edge"
        case .notifications: "Notifications"
        case .claudeCode: "Claude Code"
        }
    }

    /// Its SF Symbol in the sidebar, each there from macOS 14: Edge's a screen with a third of it lit at its leading
    /// edge, where the notch and the strip stand.
    public var symbol: String {
        switch self {
        case .general: "gearshape"
        case .edge: "rectangle.leadingthird.inset.filled"
        case .notifications: "bell"
        case .claudeCode: "terminal"
        }
    }
}

/// The panes the window has shown, as back and forward in its toolbar step through them, as Xcode's do: turning to a
/// pane from the sidebar drops whatever forward held.
public struct PaneHistory: Equatable, Sendable {
    public private(set) var shown: SettingsPane
    private var behind: [SettingsPane] = []
    private var ahead: [SettingsPane] = []

    public init(_ shown: SettingsPane) {
        self.shown = shown
    }

    public var canGoBack: Bool { !behind.isEmpty }
    public var canGoForward: Bool { !ahead.isEmpty }

    /// Turned to a pane; to the one shown, nothing changes.
    public mutating func show(_ pane: SettingsPane) {
        guard pane != shown else {
            return
        }

        behind.append(shown)
        ahead = []
        shown = pane
    }

    public mutating func goBack() {
        guard let pane = behind.popLast() else {
            return
        }

        ahead.append(shown)
        shown = pane
    }

    public mutating func goForward() {
        guard let pane = ahead.popLast() else {
            return
        }

        behind.append(shown)
        shown = pane
    }
}

/// The Claude Code pane (DESIGN, "Settings"): the plugin's row, and while some windows run an older plugin than
/// SitRep's, Needs /reload-plugins, each such window a row with Show, as the menu lists them (`WindowsBehind`).
public struct ClaudeCodePane: Equatable, Sendable {
    public let plugin: SettingsRow
    /// The windows behind, the longest attached first, as `watch` lists them; none while every window is current.
    public let reloads: [Reload]

    public static let reloadTitle = MenuBoard.reloadTitle
    /// What Copy puts on the pasteboard, which Lee types in each window behind.
    public static let command = "/reload-plugins"

    /// A window on an older plugin: its session over its project and the version it runs, and the session Show jumps
    /// to, as the menu's item for it does.
    public struct Reload: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// "SitRep · 0.3.0"; its project alone from a window too old to say its version.
        public let line: String
        public let session: String

        init(_ window: Board.Window) {
            id = window.writer
            name = window.name
            line = ([window.project] + [window.version].compactMap(\.self)).joined(separator: " · ")
            session = window.session
        }
    }

    /// The plugin SitRep runs, nil while it looks, and the board `watch` last printed.
    public init(_ last: LastBoard, plugin: PluginStanding?) {
        self.plugin = .plugin(last, plugin: plugin)
        reloads = WindowsBehind(last.board).windows.map(Reload.init)
    }
}

/// A row of the Settings window's sidebar: its pane, and the count on its right, nil for none.
public struct SettingsSidebarRow: Equatable, Sendable, Identifiable {
    public let pane: SettingsPane
    public let count: Int?

    public var id: SettingsPane { pane }

    /// The four panes, Claude Code alone counting, and only while some windows are behind on the plugin, as System
    /// Settings counts its updates.
    public static func rows(_ behind: WindowsBehind) -> [SettingsSidebarRow] {
        SettingsPane.allCases.map { pane in
            SettingsSidebarRow(pane: pane, count: pane == .claudeCode && !behind.isEmpty ? behind.count : nil)
        }
    }
}

/// The pane the Settings window last showed, which it opens on, saved on its own so a turn to a pane touches nothing
/// else Lee sets. Read leniently: a pane by its name; General the first time, or for a name no pane has.
public struct SettingsWindowSettings: SavedValue {
    public static let key = "settingsWindow"

    public var pane = SettingsPane.general

    public init() {}

    public init(pane: SettingsPane) {
        self.pane = pane
    }

    public init(from decoder: any Decoder) {
        let defaults = SettingsWindowSettings()
        guard let given = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = defaults
            return
        }

        pane = given.value(.pane, or: defaults.pane)
    }
}
