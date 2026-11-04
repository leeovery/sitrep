import AppKit
import SitRepCore
import SitRepWindow
import SwiftUI

/// The SitRep window: one, which the app owns, made the first time Lee opens it and kept after it closes. Opening it
/// again brings it forward. It comes forward and takes focus only when Lee opens it, never by itself, as the notch or
/// the strip tells Lee what changed; with no Dock icon, the app activates only then. Three columns: the sidebar, a
/// place's list, and the page beside it, a session's; or the sidebar and a project's page or a session's, filling the
/// window. ⌘, opens the Settings window from it, through the app's menu (`AppMenu`).
@MainActor
final class SitRepWindow: NSObject, NSWindowDelegate {
    private let model: WindowModel
    private lazy var window = make()
    private var focus: SideFocus?
    private var keys: Any?
    /// The list beside the page as the model says.
    private var following: ListFollowing?

    /// `following`, what the app's one `watch` is told the window follows.
    init(plugin: Plugin, works: Works, snoozes: Snoozes, following: Following, preferences: Preferences) {
        let model = WindowModel(
            plugin: plugin, works: works, snoozes: snoozes, following: following, period: preferences.app.foldsAfter
        )

        self.model = model
        preferences.follow { model.period($0.foldsAfter) }
    }

    /// The board as `watch` last printed it.
    func show(_ last: LastBoard) {
        model.show(last)
    }

    /// With no `watch` to run, the head says why.
    func unrun(_ why: String) {
        model.unrun(why)
    }

    /// Lee opens it: shown afresh, on what it opens on; or, where it shows already or was minimised, brought forward as
    /// it was. Opened on a session, "Open in SitRep" from the card or the menu, it lands there, as Lee would go there
    /// himself (`WindowRun.land(_:)`), or opening afresh, opens there. Keyboard focus goes to the list as it opens
    /// afresh or lands, the list folded away or shown already as the model took the change (`ListFollowing`), so focus
    /// finds it as it stands; brought forward as it was, it stays where it was.
    func open(session: String? = nil) {
        let isAfresh = !window.isMiniaturized && !window.isVisible

        if isAfresh {
            model.opened(landing: session)
        } else if let session {
            model.land(session)
        }
        window.comeForward()
        tellVisible(window)
        if isAfresh || session != nil {
            focus?.focusList()
        }
    }

    func windowWillClose(_ notification: Notification) {
        model.closed()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.window(isKey: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        model.window(isKey: false)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        model.minimised()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        model.restored()
        if let window = notification.object as? NSWindow {
            tellVisible(window)
        }
    }

    /// Covered by other windows or on another Space, it reads nothing of the screen; uncovered, it reads it at once.
    func windowDidChangeOcclusionState(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            tellVisible(window)
        }
    }

    /// Whether macOS has the window visible, told to the model: as it changes, and as it comes forward or back from the
    /// Dock, as it may come still covered, by a full-screen app or the screen locked, with no change to come.
    private func tellVisible(_ window: NSWindow) {
        model.window(isVisible: window.occlusionState.contains(.visible))
    }

    private func make() -> ForwardWindow {
        let columns = Self.columns(over: model)
        let split = Self.split(sidebar: columns.sidebar, list: columns.list, page: columns.page)
        let window = Self.window(split)

        window.delegate = self
        window.setFrameAutosaveName("SitRepWindow")
        let focus = SideFocus(
            window: window, sidebar: columns.sidebar.view, list: columns.list.view, page: columns.page.view
        )

        self.focus = focus
        listenForKeys(in: window, focus: focus)
        following = ListFollowing(model: model, list: split.splitViewItems[1], focus: focus)
        return window
    }

    /// The window's three columns over the model: the sidebar, the list beside the page, and the page.
    static func columns(
        over model: WindowModel
    ) -> (sidebar: NSViewController, list: NSViewController, page: NSViewController) {
        let sidebar = side(over: model) { [model] in
            SidebarColumn(places: model.places, root: model.location.root, filter: model.filter)
        }
        let list = side(over: model) { [model] in
            if let list = model.list {
                ListColumn(
                    list: list, picked: model.location.picked?.pick, head: model.head, filter: model.filter,
                    now: model.now
                )
            }
        }
        let page = side(over: model) { [model] in
            PageColumn(page: model.page, now: model.now)
        }

        return (sidebar, list, page)
    }

    /// The window's three columns in macOS's own split: the sidebar, which macOS 26 draws as Liquid Glass floating
    /// inside the window, its corners following the window's, and earlier macOS in its sidebar material; the list
    /// beside the page, in the split's content list; and the page. The sidebar and the list keep the drawing's widths;
    /// the sidebar never collapses, as there is no toggle to bring it back, and the list only as the page fills the
    /// window (`fold(_:isFullPage:)`), never by a drag or the window narrowing: SwiftUI's `NavigationSplitView` pins
    /// neither.
    static func split(sidebar: NSViewController, list: NSViewController, page: NSViewController) -> NSSplitViewController {
        let split = NSSplitViewController()
        let board = NSSplitViewItem(sidebarWithViewController: sidebar)
        let listed = NSSplitViewItem(contentListWithViewController: list)

        for (item, width) in [(board, WindowStyle.boardWidth), (listed, WindowStyle.listWidth)] {
            item.canCollapse = false
            item.canCollapseFromWindowResize = false
            item.minimumThickness = width
            item.maximumThickness = width
        }
        split.splitViewItems = [board, listed, NSSplitViewItem(viewController: page)]
        return split
    }

    /// The list folded away, or shown, at once: a project's page and a session's fill the window.
    static func fold(_ list: NSSplitViewItem, isFullPage: Bool) {
        if list.isCollapsed != isFullPage {
            list.isCollapsed = isFullPage
        }
    }

    /// The window, over its split, brought to the Space Lee is on whenever it opens and otherwise left on its own
    /// (`ForwardWindow`). Its toolbar, empty, gives it the titlebar by which macOS sets the traffic lights in from the
    /// sidebar's corner: on macOS 26 inside its glass, as Finder's. Without one they sit on the glass's corner.
    static func window(_ content: NSViewController) -> ForwardWindow {
        let window = ForwardWindow(contentViewController: content)

        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "SitRep"
        window.toolbar = Self.toolbar()
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.setContentSize(WindowStyle.size)
        window.contentMinSize = WindowStyle.smallest
        window.center()
        return window
    }

    /// A side of the window over the model, sized by the split alone.
    private static func side<Content: View>(
        over model: WindowModel, @ViewBuilder _ content: @escaping () -> Content
    ) -> NSViewController {
        let hosting = NSHostingController(rootView: WindowSide(model: model, content: content))

        hosting.sizingOptions = []
        return hosting
    }

    /// The toolbar, empty, and with nothing to customise, so a right-click on the titlebar offers no Customize
    /// Toolbar.
    private static func toolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "SitRepWindow")

        toolbar.allowsUserCustomization = false
        return toolbar
    }

    /// The window's keys, before what has focus hears them (`SideFocus.take`).
    private func listenForKeys(in window: NSWindow, focus: SideFocus) {
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            guard event.window === window, let self else {
                return event
            }
            return focus.take(event, undo: model.undo) ? nil : event
        }
    }
}

/// Keyboard focus moved by a key across the window's three regions, through AppKit's key views: ⌘F into the sidebar's
/// Filter field, from anywhere; Return a region to the right, from the sidebar into the list beside the page, or with
/// none, as the page fills the window, into the page, and from the list into the page, to its first control, which with
/// the Mac's Keyboard navigation off has none, so Return there leaves focus where it is; Escape a region to the left,
/// from the page back to the list, or with none to the sidebar's, and from the list to the sidebar's. Tab and the
/// arrows keep the Mac's own order. In the Filter field Return and Escape are the field's own (`FilterField`).
@MainActor
struct SideFocus {
    let window: NSWindow
    let sidebar: NSView
    /// The list beside the page, in the split's content list, folded away while the page fills the window.
    let list: NSView
    let page: NSView

    /// A key in the window, taken before what has focus hears it: Escape takes back the answer pressed last while it
    /// waits, as the drawing's "Esc to undo" says, wherever focus is, the Filter field too; with none waiting, the
    /// move the key makes. Whether it was taken.
    func take(_ event: NSEvent, undo: () -> Bool) -> Bool {
        if event.keyCode == Self.escape, undo() {
            return true
        }
        return move(event)
    }

    /// Focus on the list beside the page, or with none on the sidebar's, as the window opens afresh or lands on a
    /// session, where AppKit would give it to the first of its key views, the Filter field. The window is laid out
    /// first, as SwiftUI makes a list's table only then.
    func focusList() {
        window.contentView?.layoutSubtreeIfNeeded()
        window.makeFirstResponder(placeList ?? sidebarList ?? sidebar)
    }

    /// Keyboard focus is on the list beside the page.
    var isOnTheList: Bool {
        focus?.isDescendant(of: list) ?? false
    }

    /// The list that held focus, gone, folded away as the page fills the window or emptied to its one line: focus to
    /// the sidebar's list, as Escape from the list takes it, so the keys still reach a list.
    func keepOffTheList() {
        window.contentView?.layoutSubtreeIfNeeded()
        if placeList == nil {
            window.makeFirstResponder(sidebarList ?? sidebar)
        }
    }

    /// The move this key makes from where focus is, made; false where it makes none.
    func move(_ event: NSEvent) -> Bool {
        if Self.isFind(event) {
            return filterField.map { window.makeFirstResponder($0) } ?? false
        }
        guard event.modifierFlags.isDisjoint(with: Self.modifiers), let focus else {
            return false
        }

        if [Self.return, Self.enter].contains(event.keyCode) {
            return rightward(from: focus)
        }
        if event.keyCode == Self.escape {
            return leftward(from: focus)
        }
        return false
    }

    /// Return: from the sidebar, but its Filter field, into the list, or with none into the page; from the list into
    /// the page.
    private func rightward(from focus: NSView) -> Bool {
        if focus.isDescendant(of: sidebar), !isInField(focus) {
            if let placeList {
                window.makeFirstResponder(placeList)
            } else {
                intoThePage()
            }
            return true
        }
        if focus.isDescendant(of: list) {
            intoThePage()
            return true
        }
        return false
    }

    /// Escape: from the page back to the list, or with none to the sidebar's; from the list to the sidebar's.
    private func leftward(from focus: NSView) -> Bool {
        if focus.isDescendant(of: page) {
            return window.makeFirstResponder(placeList ?? sidebarList ?? sidebar)
        }
        if focus.isDescendant(of: list) {
            return window.makeFirstResponder(sidebarList ?? sidebar)
        }
        return false
    }

    /// Focus to the page's first control, where it has one; else it stays where it is. The next key view after the
    /// page is looked up before focus moves, as one outside the page means the page has none to take it.
    private func intoThePage() {
        if let first = page.nextValidKeyView, first.isDescendant(of: page) {
            window.makeFirstResponder(first)
        }
    }

    private var focus: NSView? { window.firstResponder as? NSView }
    private var filterField: NSView? { sidebar.descendants(NSSearchField.self).first }

    /// The sidebar's list, and the list beside the page while it shows, each as SwiftUI hosts it in AppKit's table,
    /// with nothing picked too.
    private var sidebarList: NSView? { sidebar.descendants(NSTableView.self).first }
    private var placeList: NSView? { list.isHiddenOrHasHiddenAncestor ? nil : list.descendants(NSTableView.self).first }

    /// Focus in the Filter field, its field editor inside it, where Return is the field's own.
    private func isInField(_ focus: NSView) -> Bool {
        filterField.map(focus.isDescendant(of:)) ?? false
    }

    /// ⌘F, whatever Caps Lock says.
    private static func isFind(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection(modifiers) == .command
            && event.charactersIgnoringModifiers?.lowercased() == "f"
    }

    /// The keys a shortcut is made with; Caps Lock, the Fn key and the keypad's are none of them.
    private static let modifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    nonisolated static let `return`: UInt16 = 36
    nonisolated static let enter: UInt16 = 76
    nonisolated static let escape: UInt16 = 53
}

private extension NSView {
    /// The views of this kind inside it, depth first, not looking inside one found.
    func descendants<View: NSView>(_ kind: View.Type) -> [View] {
        subviews.flatMap { view in (view as? View).map { [$0] } ?? view.descendants(kind) }
    }
}

/// A side of the window over its model, at the model's time. What moves by the frame, a wash or an answer's wait
/// draining, draws its own frames (`Framed`), so the side is drawn again only as the model changes.
private struct WindowSide<Content: View>: View {
    let model: WindowModel
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.windowActions, model.actions)
            .environment(\.pressedJump, model.jumping.pressed)
            .environment(\.wakeCalendar, model.calendar)
            .environment(\.reducesWindowMotion, model.reducesMotion)
            .environment(\.colorScheme, .dark)
    }
}
