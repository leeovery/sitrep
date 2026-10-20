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

    init(sitrep: SitRepCLI?, works: Works) {
        model = WindowModel(sitrep: sitrep, works: works)
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
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
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
        window.minSize = NSSize(width: 860, height: 520)
        window.contentView = NSHostingView(rootView: WindowView(model: model))
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("SitRepWindow")
        listenForEscape(in: window)
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
        .environment(\.isJumping, model.isJumping)
        .environment(\.reducesWindowMotion, model.reducesMotion)
        .ignoresSafeArea()
    }
}
