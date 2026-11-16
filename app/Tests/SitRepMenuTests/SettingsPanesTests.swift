import Foundation
@testable import SitRepCore
import SitRepEdge
@testable import SitRepMenu
import SitRepTestSupport
import Testing

/// The Settings window's four panes, top to bottom in its sidebar, each with its name and symbol (DESIGN, "Settings").
struct SettingsPaneTests {
    @Test func thePanesAreGeneralEdgeNotificationsAndClaudeCode() {
        #expect(SettingsPane.allCases.map(\.title) == ["General", "Edge", "Notifications", "Claude Code"])
        #expect(SettingsPane.allCases.map(\.symbol) == [
            "gearshape", "rectangle.leadingthird.inset.filled", "bell", "terminal",
        ])
    }
}

/// Back and forward step through the panes shown, as Xcode's do.
struct PaneHistoryTests {
    @Test func itOpensWithNowhereToStep() {
        let history = PaneHistory(.edge)

        #expect(history.shown == .edge)
        #expect(!history.canGoBack && !history.canGoForward)
    }

    @Test func backAndForwardStepThroughThePanesShown() {
        var history = PaneHistory(.general)

        history.show(.edge)
        history.show(.claudeCode)
        history.goBack()
        #expect(history.shown == .edge)
        history.goBack()
        #expect(history.shown == .general)
        #expect(!history.canGoBack && history.canGoForward)
        history.goForward()
        history.goForward()
        #expect(history.shown == .claudeCode)
        #expect(history.canGoBack && !history.canGoForward)
    }

    /// As a browser's: a pane picked after going back drops what was ahead.
    @Test func aPaneTurnedToAfterGoingBackDropsWhatWasAhead() {
        var history = PaneHistory(.general)

        history.show(.edge)
        history.goBack()
        history.show(.notifications)
        #expect(!history.canGoForward)
        history.goBack()
        #expect(history.shown == .general)
    }

    /// The pane shown picked again is no step.
    @Test func thePaneShownTurnedToAgainChangesNothing() {
        var history = PaneHistory(.general)

        history.show(.general)
        #expect(history == PaneHistory(.general))
    }

    @Test func pastEitherEndAStepGoesNowhere() {
        var history = PaneHistory(.edge)

        history.goBack()
        history.goForward()
        #expect(history == PaneHistory(.edge))
    }
}

/// Claude Code: the plugin's row, and while some windows run an older plugin, a row for each with Show, their number
/// the sidebar's count.
struct ClaudeCodePaneTests {
    private static let clone = PluginStanding.running(.folder("~/Code/sitrep"), folder: "/Users/me/Code/sitrep")
    private static let windows = [
        WatchLine.Window(writer: "w1", session: "sr-boot", name: "The installer", project: "Litware", version: "0.1.0", needsReload: true),
        WatchLine.Window(writer: "w2", session: "sr-diff", name: "Diff", project: "Relecloud", version: "0.2.0", needsReload: false),
        WatchLine.Window(writer: "w3", session: "sr-plan", name: "Plan the launch", project: "Humongous", version: nil, needsReload: true),
    ]

    private static func pane(_ windows: [WatchLine.Window]) -> ClaudeCodePane {
        ClaudeCodePane(heard([.line(Watched.line(windows: windows))]), plugin: clone)
    }

    /// Each its session over its project and the version it runs, its project alone from a window too old to say, in
    /// `watch`'s order; Show jumps to its session.
    @Test func eachWindowBehindIsARowOfItsSessionOverItsProjectAndVersion() {
        let reloads = Self.pane(Self.windows).reloads

        #expect(reloads.map(\.name) == ["The installer", "Plan the launch"])
        #expect(reloads.map(\.line) == ["Litware · 0.1.0", "Humongous"])
        #expect(reloads.map(\.session) == ["sr-boot", "sr-plan"])
    }

    /// With every window current, the plugin's row is the pane.
    @Test func withEveryWindowCurrentThereAreNoRows() {
        let pane = Self.pane([Self.windows[1]])

        #expect(pane.reloads.isEmpty)
        #expect(pane.plugin.side == .fine("Up to date"))
    }

    @Test func copyPutsTheCommandEachWindowNeeds() {
        #expect(ClaudeCodePane.command == "/reload-plugins")
        #expect(ClaudeCodePane.reloadTitle == "Needs /reload-plugins")
    }
}

/// The windows behind on the plugin, read once for the menu, the plugin's row, the pane and the sidebar's count.
struct WindowsBehindTests {
    private static let windows = [
        WatchLine.Window(writer: "w1", session: "sr-boot", name: "The installer", project: "Litware", version: "0.1.0", needsReload: true),
        WatchLine.Window(writer: "w2", session: "sr-diff", name: "Diff", project: "Relecloud", version: "0.2.0", needsReload: false),
        WatchLine.Window(writer: "w3", session: "sr-plan", name: "Plan the launch", project: "Humongous", version: nil, needsReload: true),
    ]

    @Test func theyAreTheWindowsThatNeedReloadingInWatchsOrder() {
        let behind = WindowsBehind(heard([.line(Watched.line(windows: Self.windows))]).board)

        #expect(behind.windows.map(\.writer) == ["w1", "w3"])
        #expect(behind.count == 2)
    }

    @Test func beforeAnyBoardThereAreNone() {
        #expect(WindowsBehind(nil).isEmpty)
    }

    /// The menu's Needs /reload-plugins, the plugin's row and the pane all list the same windows.
    @Test func theMenuThePluginsRowAndThePaneAgree() {
        let last = heard([.line(Watched.line(windows: Self.windows))])
        let clone = PluginStanding.running(.folder("~/Code/sitrep"), folder: "/Users/me/Code/sitrep")

        #expect(MenuBoard(last).reloads.map(\.session) == ["sr-boot", "sr-plan"])
        #expect(ClaudeCodePane(last, plugin: clone).reloads.map(\.session) == ["sr-boot", "sr-plan"])
        #expect(SettingsRow.plugin(last, plugin: clone).line?.hasPrefix("Updated to 0.2.0. 2 windows run") == true)
    }
}

/// The sidebar's rows: the four panes, Claude Code alone counting the windows behind, and only while there are some.
struct SettingsSidebarRowTests {
    private static func behind(_ count: Int) -> WindowsBehind {
        let windows = (0 ..< count).map { place in
            WatchLine.Window(writer: "w\(place)", session: "sr-\(place)", name: "S", project: "P", version: "0.1.0", needsReload: true)
        }

        return WindowsBehind(heard([.line(Watched.line(windows: windows))]).board)
    }

    @Test func claudeCodeAloneCountsTheWindowsBehind() {
        let rows = SettingsSidebarRow.rows(Self.behind(3))

        #expect(rows.map(\.pane) == SettingsPane.allCases)
        #expect(rows.map(\.count) == [nil, nil, nil, 3])
    }

    @Test func withNoneBehindNoRowCounts() {
        #expect(SettingsSidebarRow.rows(Self.behind(0)).allSatisfy { $0.count == nil })
    }
}

/// The pane the Settings window last showed, saved on its own and read leniently.
struct SettingsWindowSettingsTests {
    /// General the first time; then the pane by its name; General for a name no pane has.
    @Test(arguments: [
        (nil, SettingsPane.general), ("claudeCode", .claudeCode), ("edge", .edge), ("notifications", .notifications),
        ("general", .general), ("gone", .general),
    ])
    func itReadsThePaneByItsName(saved: String?, pane: SettingsPane) {
        let defaults = MemoryDefaults()

        if let saved {
            defaults.set(Data(#"{"pane":"\#(saved)"}"#.utf8), forKey: SettingsWindowSettings.key)
        }
        #expect(SavedSettings<SettingsWindowSettings>(defaults).read().pane == pane)
    }

    /// Under a key of its own, so nothing else Lee sets is saved again as he turns to a pane.
    @Test func itIsSavedUnderAKeyOfItsOwn() {
        let defaults = MemoryDefaults()

        SavedSettings(defaults).save(SettingsWindowSettings(pane: .edge))
        #expect(Set(defaults.dictionaryRepresentation().keys) == ["settingsWindow"])
        #expect(SavedSettings<SettingsWindowSettings>(defaults).read().pane == .edge)
    }
}
