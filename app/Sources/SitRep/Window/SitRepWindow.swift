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
        let window = Self.window(NSHostingView(rootView: WindowView(model: model)))

        window.delegate = self
        window.setFrameAutosaveName("SitRepWindow")
        listenForEscape(in: window)
        return window
    }

    /// The window, over its content, on the Space Lee is on whenever it opens (`comeForward()`).
    static func window(_ content: NSView) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: WindowStyle.size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )

        window.title = "SitRep"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = .moveToActiveSpace
        window.minSize = NSSize(width: 860, height: 520)
        window.contentView = content
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

/// The window's content over its model, drawn every frame only while a wash or an answer's wait is under way.
private struct WindowView: View {
    let model: WindowModel

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !model.isMoving)) { frame in
            WindowContent(
                listed: model.listed, page: model.page, pick: model.pick,
                now: model.isMoving ? max(frame.date, model.now) : model.now
            )
        }
        .environment(\.windowActions, model.actions)
        .environment(\.pressedJump, model.jumping.pressed)
        .environment(\.reducesWindowMotion, model.reducesMotion)
        .ignoresSafeArea()
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
