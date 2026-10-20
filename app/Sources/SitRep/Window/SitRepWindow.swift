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
    private var escape: Any?

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

    /// Lee opens it: shown afresh, on what it opens on; or, where it shows already or was minimised, brought
    /// forward as it was.
    func open() {
        if window.isMiniaturized {
            window.deminiaturize(nil)
        } else if !window.isVisible {
            model.opened()
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
        let window = Self.window(NSHostingController(rootView: WindowView(model: model)))

        window.delegate = self
        window.setFrameAutosaveName("SitRepWindow")
        listenForEscape(in: window)
        return window
    }

    /// The window, over its content, on the Space Lee is on whenever it opens (`comeForward()`). Its toolbar, empty,
    /// gives it the titlebar by which macOS sets the traffic lights in from the sidebar's corner: on macOS 26 inside
    /// its glass, as Finder's. Without one they sit on the glass's corner.
    static func window(_ content: NSViewController) -> NSWindow {
        let window = NSWindow(contentViewController: content)

        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "SitRep"
        window.toolbar = NSToolbar(identifier: "SitRepWindow")
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.setContentSize(WindowStyle.size)
        window.contentMinSize = NSSize(width: 860, height: 520)
        window.center()
        return window
    }

    /// Escape in the window takes back the answer pressed last while it waits, as the drawing's "Esc to undo" says.
    private func listenForEscape(in window: NSWindow) {
        escape = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            guard event.keyCode == Self.escapeKey, event.window === window, let self else {
                return event
            }

            return model.undo() ? nil : event
        }
    }

    private static let escapeKey: UInt16 = 53
}

/// The window's content over its model: the board in the sidebar, the page beside it.
private struct WindowView: View {
    let model: WindowModel

    var body: some View {
        WindowSplit {
            WindowSide(model: model) { now in BoardColumn(listed: model.listed, pick: model.pick, now: now) }
        } page: {
            WindowSide(model: model) { now in PageColumn(page: model.page, now: now) }
        }
    }
}

/// The window's two sides in the system's own split, as Settings' are: the board as its sidebar, which macOS 26 draws
/// as Liquid Glass floating inside the window, its corners following the window's, and earlier macOS in its sidebar
/// material; the page beside it. The sidebar keeps the drawing's width, and has no toggle.
struct WindowSplit<Board: View, Page: View>: View {
    @ViewBuilder let board: Board
    @ViewBuilder let page: Page

    var body: some View {
        NavigationSplitView {
            board
                .navigationSplitViewColumnWidth(WindowStyle.boardWidth)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            page
        }
    }
}

/// A side of the window over its model, at the model's time, or each frame's while a wash or an answer's wait is
/// under way.
private struct WindowSide<Content: View>: View {
    let model: WindowModel
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !model.isMoving)) { frame in
            content(model.isMoving ? max(frame.date, model.now) : model.now)
        }
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
