import AppKit
import SitRepCore
import SitRepWindow
import SwiftUI

/// The SitRep window: one, which the app owns, made the first time Lee opens it and kept after it closes. Opening it
/// again brings it forward. It comes forward and takes focus only when Lee opens it, never by itself, as the notch or
/// the strip tells Lee what changed; with no Dock icon, the app activates only then.
@MainActor
final class SitRepWindow: NSObject, NSWindowDelegate {
    private let model: WindowModel
    private lazy var window = make()
    private var focus: SideFocus?
    private var keys: Any?

    init(plugin: Plugin, works: Works) {
        model = WindowModel(plugin: plugin, works: works)
    }

    /// The board as `watch` last printed it.
    func show(_ last: LastBoard) {
        model.show(last)
    }

    /// With no `watch` to run, the head says why.
    func unrun(_ why: String) {
        model.unrun(why)
    }

    /// Lee opens it: shown afresh, on what it opens on, keyboard focus on the list; or, where it shows already or was
    /// minimised, brought forward as it was.
    func open() {
        let isAfresh = !window.isMiniaturized && !window.isVisible

        if window.isMiniaturized {
            window.deminiaturize(nil)
        } else if isAfresh {
            model.opened()
        }
        window.comeForward()
        if isAfresh {
            focus?.focusList()
        }
    }

    func windowWillClose(_ notification: Notification) {
        model.closed()
    }

    func windowDidMiniaturize(_ notification: Notification) {
        model.minimised()
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        model.restored()
    }

    private func make() -> NSWindow {
        let sidebar = Self.side(over: model) { [model] in
            BoardColumn(
                listed: model.listed, pick: model.pick, sidebar: model.sidebar, filter: model.filter, now: model.now
            )
        }
        let page = Self.side(over: model) { [model] in PageColumn(page: model.page, now: model.now) }
        let window = Self.window(Self.split(sidebar: sidebar, page: page))

        window.delegate = self
        window.setFrameAutosaveName("SitRepWindow")
        let focus = SideFocus(window: window, sidebar: sidebar.view, page: page.view)

        self.focus = focus
        listenForKeys(in: window, focus: focus)
        return window
    }

    /// The window's two sides in macOS's own split: the board as its sidebar, which macOS 26 draws as Liquid Glass
    /// floating inside the window, its corners following the window's, and earlier macOS in its sidebar material; the
    /// page beside it. The sidebar keeps the drawing's width, and never collapses, as there is no toggle to bring it
    /// back: SwiftUI's `NavigationSplitView`, as Settings has, pins neither.
    static func split(sidebar: NSViewController, page: NSViewController) -> NSSplitViewController {
        let split = NSSplitViewController()
        let board = NSSplitViewItem(sidebarWithViewController: sidebar)

        board.canCollapse = false
        board.canCollapseFromWindowResize = false
        board.minimumThickness = WindowStyle.boardWidth
        board.maximumThickness = WindowStyle.boardWidth
        split.splitViewItems = [board, NSSplitViewItem(viewController: page)]
        return split
    }

    /// The window, over its split, on the Space Lee is on whenever it opens (`comeForward()`). Its toolbar, empty,
    /// gives it the titlebar by which macOS sets the traffic lights in from the sidebar's corner: on macOS 26 inside
    /// its glass, as Finder's. Without one they sit on the glass's corner.
    static func window(_ content: NSViewController) -> NSWindow {
        let window = NSWindow(contentViewController: content)

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
        window.collectionBehavior.insert(.moveToActiveSpace)
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

/// Keyboard focus moved by a key, through AppKit's key views: ⌘F into the sidebar's Filter field, from anywhere;
/// Return on the sidebar's list into the page, to its first control, which with the Mac's Keyboard navigation off has
/// none; Escape in the page back to the list. Tab and the arrows keep the Mac's own order. In the Filter field Return
/// and Escape are the field's own (`FilterField`).
@MainActor
struct SideFocus {
    let window: NSWindow
    let sidebar: NSView
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

    /// Focus on the list, as the window opens afresh, where AppKit would give it to the first of its key views, the
    /// Filter field above the list. The list is laid out first, as SwiftUI makes its table only then.
    func focusList() {
        window.contentView?.layoutSubtreeIfNeeded()
        window.makeFirstResponder(list ?? sidebar)
    }

    /// The move this key makes from where focus is, made; false where it makes none.
    func move(_ event: NSEvent) -> Bool {
        if Self.isFind(event) {
            return filterField.map { window.makeFirstResponder($0) } ?? false
        }
        guard event.modifierFlags.isDisjoint(with: Self.modifiers), let focus else {
            return false
        }

        if [Self.return, Self.enter].contains(event.keyCode), list.map(focus.isDescendant(of:)) == true {
            window.selectKeyView(following: page)
            return self.focus?.isDescendant(of: page) == true
        }
        if event.keyCode == Self.escape, focus.isDescendant(of: page) {
            return window.makeFirstResponder(list ?? sidebar)
        }
        return false
    }

    private var focus: NSView? { window.firstResponder as? NSView }
    /// The sidebar's list, as SwiftUI hosts it in AppKit's table.
    private var list: NSView? { sidebar.descendant(NSTableView.self) }
    private var filterField: NSView? { sidebar.descendant(NSSearchField.self) }

    /// ⌘F, whatever Caps Lock says.
    private static func isFind(_ event: NSEvent) -> Bool {
        event.modifierFlags.intersection(modifiers) == .command && event.charactersIgnoringModifiers?.lowercased() == "f"
    }

    /// The keys a shortcut is made with; Caps Lock, the Fn key and the keypad's are none of them.
    private static let modifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    static let `return`: UInt16 = 36
    static let enter: UInt16 = 76
    static let escape: UInt16 = 53
}

private extension NSView {
    /// The first view of this kind inside it, depth first: the sidebar's list, as SwiftUI hosts it in AppKit's table.
    func descendant<View: NSView>(_ kind: View.Type) -> View? {
        for view in subviews {
            if let found = view as? View ?? view.descendant(kind) {
                return found
            }
        }
        return nil
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
            .environment(\.reducesWindowMotion, model.reducesMotion)
            .environment(\.colorScheme, .dark)
    }
}

extension NSWindow {
    /// Brought forward on the Space Lee is on, and keyed: the window moves to that Space as it orders front, which
    /// `.moveToActiveSpace` asks for, before SitRep activates, so the activation finds a window of SitRep's where Lee
    /// is and takes him to no other Space. Activated first, macOS went to the Space the window was last on.
    func comeForward() {
        makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
