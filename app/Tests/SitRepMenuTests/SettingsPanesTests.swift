import Foundation
@testable import SitRepCore
import SitRepLines
@testable import SitRepMenu
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
    private static let clone = PluginStanding.running(.folder("~/Code/sitrep"), folder: "/Users/lee/Code/sitrep")
    private static let windows = [
        Watched.window("w1", session: "sr-boot", name: "The bootstrap", project: "Kit", version: "0.1.0", needsReload: true),
        Watched.window("w2", session: "sr-diff", name: "Diff", project: "Mint", version: "0.2.0", needsReload: false),
        Watched.window("w3", session: "sr-plan", name: "Plan the tool", project: "Terrace", version: nil, needsReload: true),
    ]

    private static func pane(_ windows: [String]) -> ClaudeCodePane {
        ClaudeCodePane(heard([.line(Watched.line(windows: windows))]), plugin: clone)
    }

    /// Each its session over its project and the version it runs, its project alone from a window too old to say, in
    /// `watch`'s order; Show jumps to its session.
    @Test func eachWindowBehindIsARowOfItsSessionOverItsProjectAndVersion() {
        let reloads = Self.pane(Self.windows).reloads

        #expect(reloads.map(\.name) == ["The bootstrap", "Plan the tool"])
        #expect(reloads.map(\.line) == ["Kit · 0.1.0", "Terrace"])
        #expect(reloads.map(\.session) == ["sr-boot", "sr-plan"])
        #expect(Self.pane(Self.windows).behind == 2)
    }

    /// With every window current, the plugin's row is the pane, and the sidebar counts nothing.
    @Test func withEveryWindowCurrentThereAreNoRowsAndNoCount() {
        let pane = Self.pane([Self.windows[1]])

        #expect(pane.reloads.isEmpty)
        #expect(pane.behind == 0)
        #expect(pane.plugin.side == .fine("Up to date"))
    }

    @Test func beforeAnyBoardThereIsNothingBehind() {
        #expect(ClaudeCodePane(LastBoard(), plugin: nil).behind == 0)
    }

    @Test func copyPutsTheCommandEachWindowNeeds() {
        #expect(ClaudeCodePane.command == "/reload-plugins")
        #expect(ClaudeCodePane.reloadTitle == "Needs /reload-plugins")
    }
}
