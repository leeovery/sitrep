import AppKit
@testable import SitRep
import SitRepMenu
import SitRepTestSupport
import SwiftUI
import Testing

/// The Settings window, made, never shown: one, brought forward on the Space Lee is on; 820 by 620 to start, down to
/// its least size; its close button and ⌘W shut it; the pane's name its title, and back and forward in its toolbar
/// stepping through the panes shown.
@MainActor
@Suite(.backstop)
struct SettingsWindowTests {
    /// The window and its Settings, its frame a recorded one, which never orders front.
    @MainActor
    private struct Made {
        let settings: SettingsModel
        let window: SettingsWindow
        let recorded: RecordedWindow

        init() async {
            let recorded = RecordedWindow.made()

            self.recorded = recorded
            settings = await Hosted.settings()
            window = SettingsWindow(settings: settings) { content in
                recorded.contentViewController = content
                return recorded
            }
            window.show()
        }
    }

    /// Opened again, the same window comes forward again, on the Space Lee is on, as About SitRep does.
    @Test func itIsOneWindowBroughtForwardEachTimeItOpens() async {
        let made = await Made()

        made.window.show()
        #expect(made.recorded.steps == [
            .orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true),
            .orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true),
        ])
    }

    @Test func itOpensAt820By620AndShrinksNoSmallerThanItsLeastSize() async {
        let window = await Made().recorded

        #expect(window.contentRect(forFrameRect: window.frame).size == CGSize(width: 820, height: 620))
        #expect(window.contentMinSize == SettingsWindow.smallest)
        #expect(window.styleMask.isSuperset(of: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]))
        #expect(!window.isReleasedWhenClosed)
    }

    @Test func itClosesByItsButtonAndTheMainMenusCommandW() async {
        let window = await Made().recorded

        #expect(window.validateMenuItem(NSMenuItem(title: "", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "")))
    }

    /// It goes to the Space Lee is on only as SitRep brings it forward (`ForwardWindowTests`).
    @Test func itStaysOnItsOwnSpaceTillSitRepBringsItForward() {
        let window = SettingsWindow.window(RecordedWindow.made(), toolbar: NSToolbar())

        #expect(!window.collectionBehavior.contains(.moveToActiveSpace))
    }

    /// The system's sidebar beside the pane, 180 wide, never collapsing.
    @Test func itsSidebarIsTheSystemsAt180() {
        let split = SettingsWindow.split(sidebar: NSViewController.with(NSView()), pane: NSViewController.with(NSView()))
        let sidebar = split.splitViewItems[0]

        #expect(sidebar.behavior == .sidebar)
        #expect(!sidebar.canCollapse && !sidebar.canCollapseFromWindowResize)
        #expect(sidebar.minimumThickness == 180 && sidebar.maximumThickness == 180)
    }

    @Test func itsTitleIsThePaneShownAndFollowsAsLeeTurns() async {
        let made = await Made()

        #expect(made.recorded.title == "General")
        made.settings.turn(to: .claudeCode)
        await until(turns: 100) { made.recorded.title == "Claude Code" }
        made.settings.goBack()
        await until(turns: 100) { made.recorded.title == "General" }
    }

    /// Back and forward lead the toolbar past the sidebar, before the title, as Xcode's do, with nothing to customise.
    @Test func backAndForwardLeadTheToolbarPastTheSidebar() async throws {
        let toolbar = try #require(await Made().recorded.toolbar)
        let steps = try #require(toolbar.items.last)

        #expect(toolbar.items.map(\.itemIdentifier).first == .sidebarTrackingSeparator)
        #expect(steps.isNavigational)
        #expect((steps as? NSToolbarItemGroup)?.subitems.map(\.label) == ["Back", "Forward"])
        #expect(!toolbar.allowsUserCustomization)
    }

    /// Each greyed where there is no pane to step to; a press steps, pressed as AppKit presses a side, through its
    /// menu form, as the toolbar's overflow shows it.
    @Test func backAndForwardStepThroughThePanesShown() async throws {
        let made = await Made()
        let steps = made.window.steps
        let enabled = { steps.subitems.map(\.isEnabled) }
        let press = { (side: Int) in
            let menu = try #require(steps.subitems[side].menuFormRepresentation)

            NSApplication.shared.sendAction(try #require(menu.action), to: menu.target, from: menu)
        }

        #expect(enabled() == [false, false])
        made.settings.turn(to: .edge)
        await until(turns: 100) { enabled() == [true, false] }
        try press(0)
        #expect(made.settings.pane == .general)
        await until(turns: 100) { enabled() == [false, true] }
        try press(1)
        #expect(made.settings.pane == .edge)
    }

    /// A press with no side selected, as VoiceOver or the keyboard can send a momentary control, steps nowhere.
    @Test func aPressWithNoSideSelectedStepsNowhere() async throws {
        let made = await Made()
        let steps = made.window.steps

        made.settings.turn(to: .edge)
        made.settings.goBack()
        steps.selectedIndex = -1
        NSApplication.shared.sendAction(try #require(steps.action), to: steps.target, from: steps)
        #expect(made.settings.pane == .general)
    }

    /// ⌘[ and ⌘], the Go menu's, step back and forward as the toolbar does, each only where it has a pane to step to;
    /// any other item stays enabled.
    @Test func theGoMenusBackAndForwardStepThroughThePanesShown() async {
        let made = await Made()
        let item = { (action: Selector) in NSMenuItem(title: "", action: action, keyEquivalent: "") }
        let back = item(#selector(SettingsWindow.goBack(_:)))
        let forward = item(#selector(SettingsWindow.goForward(_:)))

        #expect(!made.window.validateMenuItem(back) && !made.window.validateMenuItem(forward))
        made.settings.turn(to: .edge)
        #expect(made.window.validateMenuItem(back) && !made.window.validateMenuItem(forward))
        made.window.goBack(back)
        #expect(made.settings.pane == .general)
        #expect(!made.window.validateMenuItem(back) && made.window.validateMenuItem(forward))
        made.window.goForward(forward)
        #expect(made.settings.pane == .edge)
        #expect(made.window.validateMenuItem(item(#selector(NSWindow.performClose(_:)))))
    }

    /// What macOS says is read as the window keys, as it comes forward.
    @Test func itReadsWhatMacOSSaysAsItKeys() async {
        let made = await Made()

        made.recorded.delegate?.windowDidBecomeKey?(Notification(name: NSWindow.didBecomeKeyNotification))
        #expect(made.settings.reading != nil)
    }
}

/// The sidebar as the window hosts it: the system's list of the four panes, the one shown selected.
@MainActor
@Suite(.backstop)
struct SettingsSidebarTests {
    @Test func itListsTheFourPanesTheOneShownSelected() async throws {
        let settings = await Hosted.settings()

        settings.turn(to: .notifications)

        let hosted = Hosted(SettingsSidebar(settings: settings), size: CGSize(width: 180, height: 620))
        let list = try #require(hosted.all(NSTableView.self).first)

        #expect(list.numberOfRows == SettingsPane.allCases.count)
        #expect(list.selectedRow == SettingsPane.allCases.firstIndex(of: .notifications))
    }
}

/// Claude Code's pane as the window draws it: the windows behind, each with Show, then Copy; none of it while every
/// window is current.
@MainActor
@Suite(.backstop)
struct ClaudeCodePaneViewTests {
    private static func hosted(needsReload: Bool) async -> Hosted {
        let settings = await Hosted.settings(live: Hosted.live(needsReload: needsReload))

        return Hosted(Hosted.content(.claudeCode, settings), size: CGSize(width: 632, height: 620))
    }

    @Test func eachWindowBehindIsARowWithShowAndThenCopy() async {
        let hosted = await Self.hosted(needsReload: true)

        // two windows' Show, then Copy
        #expect(hosted.buttons().count == 3)
    }

    @Test func withEveryWindowCurrentThePluginsRowIsThePane() async {
        #expect(await Self.hosted(needsReload: false).buttons().isEmpty)
    }
}
