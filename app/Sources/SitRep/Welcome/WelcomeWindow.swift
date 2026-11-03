import AppKit
import SwiftUI

/// The welcome window (DESIGN, "The welcome window"): one, made as it first opens, which the menu's Show Welcome
/// Window opens at its first step, bringing it forward again where it shows. It opens centred on the Space Lee is on,
/// and otherwise stays on its own (`ForwardWindow`), as About SitRep does. 840 by 540, never resized, black, in the
/// system's frame: its close button and ⌘W close it, however far Lee got, keeping what he set; it neither minimises
/// nor zooms. Its stage plays while it is in front, behind only settling what a change set moving, and what macOS says
/// of the login item and the two leaves is read each time it comes forward. Keyboard focus is on nothing as it opens,
/// as in the Mac's own setup assistants, and Return presses Continue; Tab takes it into the controls in reading order.
@MainActor
final class WelcomeWindow: NSObject, NSWindowDelegate {
    private let welcome: WelcomeModel
    private let frame: @MainActor (NSViewController) -> ForwardWindow
    private lazy var window = make()
    private var focusWatch: NSKeyValueObservation?
    /// Focus being put on nothing, which the watch on focus hears too.
    private var isFocusingNothing = false
    /// SitRep's edge on the stage: internal only for the tests, which read what it hosts.
    private(set) lazy var stage = StageEdge(
        size: WelcomeStyle.stage, menuBar: WelcomeStyle.stageMenuBar, preferences: welcome.preferences
    )

    /// `frame` makes the window round what it shows as it first opens: a seam, as a test never shows one.
    init(
        welcome: WelcomeModel,
        frame: @escaping @MainActor (NSViewController) -> ForwardWindow = { ForwardWindow(contentViewController: $0) }
    ) {
        self.welcome = welcome
        self.frame = frame
    }

    /// At its first step, whenever it opens, with focus on nothing; a visit under way goes on.
    func show() {
        let opens = !window.isVisible

        welcome.open()
        window.comeForward()
        if opens {
            focusNothing(in: window)
        }
    }

    /// SitRep quitting, which tells a window nothing: one showing closes as its close button would close it, so what
    /// closing does is done.
    func closeIfOpen() {
        if welcome.isVisiting {
            window.close()
        }
    }

    /// Whether SitRep, starting, opens it by itself, as Show Welcome Window opens it: only on a Mac where none has ever
    /// closed. However it closes, quitting included, it is done with, so it never opens by itself again.
    static func opensAtStart(_ preferences: Preferences) -> Bool {
        !preferences.welcomed
    }

    func windowDidBecomeKey(_ notification: Notification) {
        welcome.readLogin()
        welcome.readLeaves()
        stage.standing = .inFront
    }

    func windowDidResignKey(_ notification: Notification) {
        stage.standing = .behind
    }

    func windowWillClose(_ notification: Notification) {
        stage.stop()
        welcome.close()
    }

    private func make() -> ForwardWindow {
        let content = WelcomeHosting(rootView: WelcomeView(welcome: welcome, stage: stage))

        content.sizingOptions = []

        let window = Self.window(frame(content))

        window.delegate = self
        welcome.closeWindow = { [weak window] in window?.close() }
        focusWatch = window.observe(\.firstResponder) { [weak self] window, _ in
            MainActor.assumeIsolated {
                if window.firstResponder === window {
                    self?.focusNothing(in: window)
                }
            }
        }
        return window
    }

    /// Keyboard focus on the window's content, which draws no ring, and from which Tab and Shift-Tab go to the first
    /// and the last of its controls. AppKit, as the window orders in with the Mac's Keyboard navigation on, gives focus
    /// to the first of its key views, Skip setup at the first step; and where the control holding focus goes with its
    /// step, AppKit leaves the window itself first responder.
    private func focusNothing(in window: NSWindow) {
        guard !isFocusingNothing, let content = window.contentView else {
            return
        }

        isFocusingNothing = true
        window.makeFirstResponder(content)
        isFocusingNothing = false
    }

    /// The window: titled, so it has the system's frame and close button, its content running under a clear title bar
    /// and showing no title; closable alone, so the main menu's ⌘W reaches it (`AppMenu`); black, and dark, whatever
    /// the Mac's appearance.
    static func window(_ window: ForwardWindow) -> ForwardWindow {
        window.title = "Welcome to SitRep"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.setContentSize(WelcomeStyle.size)
        window.center()
        return window
    }
}

/// The welcome's content, its window's key view loop worked out afresh after each layout, so Tab follows the step's
/// controls. SwiftUI's buttons join the loop through key views of its own, which come and go with a step unseen by
/// AppKit's own recalculation as views change: in a window made offscreen, back, enabled at step 2, stayed out of
/// Tab's reach.
private final class WelcomeHosting: NSHostingController<WelcomeView> {
    override func viewDidLayout() {
        super.viewDidLayout()
        view.window?.recalculateKeyViewLoop()
    }
}
