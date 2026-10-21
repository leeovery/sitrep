import AppKit
import SitRepCore
import SitRepWindow
import SwiftUI

/// The SitRep window: one, which the app owns, made the first time Lee opens it and kept after it closes. Opening it
/// again brings it forward. It comes forward and takes focus only when Lee opens it, never by itself, as the notch or
/// the strip tells Lee what changed; with no Dock icon, the app activates only then. Its page is a session, a project,
/// or Settings, which `settings` draws.
@MainActor
final class SitRepWindow: NSObject, NSWindowDelegate {
    private let model: WindowModel
    private let settings: () -> SettingsPage
    private lazy var window = make()
    private var keys: Any?

    init(plugin: Plugin, works: Works, settings: @escaping () -> SettingsPage) {
        model = WindowModel(plugin: plugin, works: works)
        self.settings = settings
    }

    /// The board as `watch` last printed it.
    func show(_ last: LastBoard) {
        model.show(last)
    }

    /// With no `watch` to run, the head says why.
    func unrun(_ why: String) {
        model.unrun(why)
    }

    /// Lee opens it: shown afresh, on the pick given or else on what it opens on; or, where it shows already or was
    /// minimised, brought forward as it was, turned to the pick given.
    func open(on pick: Pick? = nil) {
        if !window.isVisible, !window.isMiniaturized {
            model.opened(on: pick)
        } else if let pick {
            model.pick(pick)
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.comeForward()
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
            BoardColumn(listed: model.listed, pick: model.pick, now: model.now)
        }
        let page = Self.side(over: model) { [model, settings] in
            PageColumn(page: model.page, now: model.now, settings: settings)
        }
        let window = Self.window(Self.split(sidebar: sidebar, page: page))

        window.delegate = self
        window.setFrameAutosaveName("SitRepWindow")
        listenForKeys(in: window, focus: SideFocus(window: window, sidebar: sidebar.view, page: page.view))
        return window
    }

    /// The window's two sides in macOS's own split: the board as its sidebar, which macOS 26 draws as Liquid Glass
    /// floating inside the window, its corners following the window's, and earlier macOS in its sidebar material; the
    /// page beside it. The sidebar keeps the drawing's width, and never collapses, as there is no toggle to bring it
    /// back: SwiftUI's `NavigationSplitView` pins neither.
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

    /// Escape in the window takes back the answer pressed last while it waits, as the drawing's "Esc to undo" says;
    /// with none waiting, it and Return move keyboard focus between the two sides (`SideFocus`).
    private func listenForKeys(in window: NSWindow, focus: SideFocus) {
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            guard event.window === window, let self else {
                return event
            }
            if event.keyCode == SideFocus.escape, model.undo() {
                return nil
            }
            return focus.move(event) ? nil : event
        }
    }
}

/// Keyboard focus moved between the window's two sides by a key, through AppKit's key views: Return on the sidebar's
/// list into the page, to its first control, which with the Mac's Keyboard navigation off has none; Escape in the page
/// back to the list that holds the pick, the board's or Settings' at its foot. Tab and the arrows keep the Mac's own
/// order.
@MainActor
struct SideFocus {
    let window: NSWindow
    let sidebar: NSView
    let page: NSView

    /// The move this key makes from where focus is, made; false where it makes none.
    func move(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift]),
              let focus = window.firstResponder as? NSView
        else {
            return false
        }

        if [Self.return, Self.enter].contains(event.keyCode), focus.isDescendant(of: sidebar) {
            window.selectKeyView(following: page)
            return (window.firstResponder as? NSView)?.isDescendant(of: page) == true
        }
        if event.keyCode == Self.escape, focus.isDescendant(of: page) {
            return window.makeFirstResponder(picked ?? sidebar)
        }
        return false
    }

    /// The sidebar's list holding the pick, as SwiftUI hosts each in AppKit's table; the first, with nothing picked.
    private var picked: NSTableView? {
        let lists = sidebar.descendants(NSTableView.self)

        return lists.first { $0.selectedRow >= 0 } ?? lists.first
    }

    static let `return`: UInt16 = 36
    static let enter: UInt16 = 76
    static let escape: UInt16 = 53
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
