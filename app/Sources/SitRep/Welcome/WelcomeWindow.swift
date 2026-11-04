import AppKit
import SwiftUI

/// The welcome window (DESIGN, "The welcome window"): made afresh each time it opens, which the menu's Show Welcome
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
    /// The window while it shows, let go as it closes, so no focus a visit leaves, AppKit's or SwiftUI's, comes back
    /// with the next.
    private var shown: Shown?

    /// `frame` makes the window round what it shows as it opens: a seam, as a test never shows one.
    init(
        welcome: WelcomeModel,
        frame: @escaping @MainActor (NSViewController) -> ForwardWindow = { ForwardWindow(contentViewController: $0) }
    ) {
        self.welcome = welcome
        self.frame = frame
    }

    /// SitRep's edge on the stage of the window showing: internal only for the tests, which read what it hosts.
    var stage: StageEdge? { shown?.stage }

    /// At its first step, whenever it opens, with focus on nothing; a visit under way goes on, focus where it was while
    /// the control holding it stays at the first step.
    func show() {
        welcome.open()
        guard let shown else {
            open()
            return
        }

        shown.window.comeForward()
    }

    /// SitRep quitting, which tells a window nothing: one showing closes as its close button would close it, so what
    /// closing does is done.
    func closeIfOpen() {
        shown?.window.close()
    }

    /// Whether SitRep, starting, opens it by itself, as Show Welcome Window opens it: only on a Mac where none has ever
    /// closed. However it closes, quitting included, it is done with, so it never opens by itself again.
    static func opensAtStart(_ preferences: Preferences) -> Bool {
        !preferences.welcomed
    }

    /// Keyed, as it opened or as it went behind with focus on nothing, focus is put on nothing again, where AppKit,
    /// keying a window, may have given it to a control. Focus Lee gave a control stays: no key moves it while the
    /// window is behind.
    func windowDidBecomeKey(_ notification: Notification) {
        guard let shown, Self.isFrom(shown, notification) else {
            return
        }

        welcome.readLogin()
        welcome.readLeaves()
        shown.stage.standing = .inFront
        if shown.isOnNothing {
            Self.focusNothing(in: shown.window)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let shown, Self.isFrom(shown, notification) else {
            return
        }

        self.shown?.isOnNothing = shown.window.firstResponder === shown.window
        shown.stage.standing = .behind
    }

    func windowWillClose(_ notification: Notification) {
        guard let shown, Self.isFrom(shown, notification) else {
            return
        }

        let window = shown.window

        shown.stage.stop()
        self.shown = nil
        welcome.close()
        // Skip setup and Done close it from inside its hosting view's handling of the press, which goes on after the
        // close: the window, and the view with it, kept until the next turn
        DispatchQueue.main.async {
            withExtendedLifetime(window) {}
        }
    }

    private static func isFrom(_ shown: Shown, _ notification: Notification) -> Bool {
        (notification.object as? NSWindow) === shown.window
    }

    private func open() {
        let shown = make()

        self.shown = shown
        shown.window.comeForward()
        Self.focusNothing(in: shown.window)
    }

    private func make() -> Shown {
        let stage = StageEdge(
            size: WelcomeStyle.stage, menuBar: WelcomeStyle.stageMenuBar, preferences: welcome.preferences
        )
        let content = WelcomeHosting(rootView: WelcomeView(welcome: welcome, stage: stage))

        content.sizingOptions = []

        let window = Self.window(frame(content))

        window.delegate = self
        welcome.closeWindow = { [weak window] in window?.close() }
        return Shown(window: window, stage: stage)
    }

    /// Keyboard focus on nothing: the window itself first responder, which draws no ring. AppKit, as the window orders
    /// in with the Mac's Keyboard navigation on, gives focus to the first of its key views, Skip setup at the first step.
    private static func focusNothing(in window: NSWindow) {
        // the window, not its content: with the hosting view first responder, SwiftUI focused its first control, its
        // ring drawn as the window keyed (4 November 2026); from the window, Tab still enters the controls and Return
        // still presses Continue
        window.makeFirstResponder(nil)
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

/// A window showing, and its stage.
private struct Shown {
    let window: ForwardWindow
    let stage: StageEdge
    /// Focus on nothing as it opened, or as it last went behind.
    var isOnNothing = true
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
