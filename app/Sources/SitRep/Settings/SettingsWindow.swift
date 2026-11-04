import AppKit
import Observation
import SitRepMenu
import SwiftUI

/// The Settings window (DESIGN, "Settings"), laid out as Xcode 27's: one, made as it first opens, which the menu's
/// Settings…, ⌘, and the SitRep window's foot open, bringing it forward again where it shows. It opens centred in the
/// upper part of the screen on the Space Lee is on, and otherwise stays on its own (`ForwardWindow`); ⌘W or its close
/// button shuts it. The system's sidebar lists the panes; back and forward in the toolbar step through those shown, the
/// pane's name the window's title beside them. What macOS says is read as a pane comes into sight while it is key
/// (`SettingsModel.keys`).
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate, NSToolbarDelegate {
    private let settings: SettingsModel
    private let frame: @MainActor (NSViewController) -> ForwardWindow
    private lazy var window = make()
    /// Back and forward, in one capsule.
    let steps = NSSegmentedControl.steps([("chevron.left", "Back"), ("chevron.right", "Forward")])

    /// 820 by 620 to start, as Paper's boards are.
    nonisolated static let size = CGSize(width: 820, height: 620)
    /// The least size: a column of 476 beside the sidebar's 188 and the column's insets, the narrowest the rows were
    /// proven at, where every row's control keeps its place beside its words, a line wrapping before a control moves.
    nonisolated static let smallest = CGSize(width: 704, height: 440)
    /// The sidebar's glass, as wide as Xcode's.
    static let sidebarWidth: CGFloat = 180

    /// `frame` makes the window round what it shows as it first opens: a seam, as a test never shows one.
    init(
        settings: SettingsModel,
        frame: @escaping @MainActor (NSViewController) -> ForwardWindow = { ForwardWindow(contentViewController: $0) }
    ) {
        self.settings = settings
        self.frame = frame
    }

    func show() {
        window.comeForward()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        settings.keys(true)
    }

    func windowDidResignKey(_ notification: Notification) {
        settings.keys(false)
    }

    private func make() -> ForwardWindow {
        let sidebar = Self.hosting(SettingsSidebar(settings: settings))
        let pane = Self.hosting(SettingsPaneView(settings: settings))
        let window = Self.window(frame(Self.split(sidebar: sidebar, pane: pane)), toolbar: toolbar())

        window.delegate = self
        steps.target = self
        steps.action = #selector(step(_:))
        follow(in: window)
        return window
    }

    /// The window's title and back and forward, as the pane shown changes, and each time after.
    private func follow(in window: NSWindow) {
        let history = withObservationTracking { [settings] in settings.history } onChange: { [weak self, weak window] in
            Task { @MainActor in
                if let window {
                    self?.follow(in: window)
                }
            }
        }

        window.title = history.shown.title
        steps.setEnabled(history.canGoBack, forSegment: Self.back)
        steps.setEnabled(history.canGoForward, forSegment: Self.forward)
    }

    @objc private func step(_ control: NSSegmentedControl) {
        if control.selectedSegment == Self.back {
            settings.goBack()
        } else {
            settings.goForward()
        }
    }

    /// The system's sidebar beside the pane: on macOS 26, Liquid Glass floating inside the window, as Xcode's. It keeps
    /// its width and never collapses, as there is no toggle to bring it back.
    static func split(sidebar: NSViewController, pane: NSViewController) -> NSSplitViewController {
        let split = NSSplitViewController()
        let list = NSSplitViewItem(sidebarWithViewController: sidebar)

        list.canCollapse = false
        list.canCollapseFromWindowResize = false
        list.minimumThickness = sidebarWidth
        list.maximumThickness = sidebarWidth
        split.splitViewItems = [list, NSSplitViewItem(viewController: pane)]
        return split
    }

    /// The window: titled with the pane's name, which its unified toolbar shows beside back and forward; it can be
    /// minimised and resized, down to its least size; its colours the system's own, as it follows the Mac's appearance.
    static func window(_ window: ForwardWindow, toolbar: NSToolbar) -> ForwardWindow {
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.setContentSize(size)
        window.contentMinSize = smallest
        window.center()
        return window
    }

    /// A side of the window, sized by the split alone.
    private static func hosting(_ view: some View) -> NSViewController {
        let hosting = NSHostingController(rootView: view)

        hosting.sizingOptions = []
        return hosting
    }

    // MARK: The toolbar

    private static let stepsItem = NSToolbarItem.Identifier("SettingsSteps")
    private static let back = 0
    private static let forward = 1

    /// Back and forward past the sidebar, at the toolbar's lead, and nothing to customise, so a right-click on it offers
    /// no Customize Toolbar.
    private func toolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "SettingsWindow")

        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconOnly
        return toolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator, Self.stepsItem]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard identifier == Self.stepsItem else {
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: identifier)

        item.view = steps
        item.label = "Back/Forward"
        item.isNavigational = true
        item.autovalidates = false
        return item
    }
}
