import AppKit
@testable import SitRep
import SitRepMenu
import SwiftUI
import Testing

/// The Settings window, made, never shown: one, brought forward on the Space Lee is on; 820 by 620 to start, down to
/// its least size; its close button and ⌘W shut it; the pane's name its title, and back and forward in its toolbar
/// stepping through the panes shown.
@MainActor
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

        /// What the window shows once the change to the pane has been heard, on the main actor's next turn.
        func settled() async {
            await Task.yield()
            await Task.yield()
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
        await made.settled()
        #expect(made.recorded.title == "Claude Code")
        made.settings.goBack()
        await made.settled()
        #expect(made.recorded.title == "General")
    }

    /// Back and forward lead the toolbar past the sidebar, before the title, as Xcode's do, with nothing to customise.
    @Test func backAndForwardLeadTheToolbarPastTheSidebar() async throws {
        let toolbar = try #require(await Made().recorded.toolbar)
        let steps = try #require(toolbar.items.last)

        #expect(toolbar.items.map(\.itemIdentifier).first == .sidebarTrackingSeparator)
        #expect(steps.isNavigational)
        #expect(steps.view is NSSegmentedControl)
        #expect(!toolbar.allowsUserCustomization)
    }

    /// Each greyed where there is no pane to step to; a press steps. A momentary control holds the segment pressed only
    /// while a click sends its action, so a press is sent from a control holding it.
    @Test func backAndForwardStepThroughThePanesShown() async {
        let made = await Made()
        let steps = made.window.steps
        let press = { (segment: Int) in
            let pressed = NSSegmentedControl(labels: ["", ""], trackingMode: .selectOne, target: nil, action: nil)

            pressed.selectedSegment = segment
            _ = pressed.sendAction(steps.action, to: steps.target)
        }

        #expect(!steps.isEnabled(forSegment: 0) && !steps.isEnabled(forSegment: 1))
        made.settings.turn(to: .edge)
        await made.settled()
        #expect(steps.isEnabled(forSegment: 0) && !steps.isEnabled(forSegment: 1))
        press(0)
        await made.settled()
        #expect(made.settings.pane == .general)
        #expect(!steps.isEnabled(forSegment: 0) && steps.isEnabled(forSegment: 1))
        press(1)
        #expect(made.settings.pane == .edge)
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
