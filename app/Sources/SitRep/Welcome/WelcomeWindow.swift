import AppKit
import SwiftUI

/// The welcome window (DESIGN, "The welcome window"): one, made as it first opens, which the menu's Welcome… opens at
/// its first step, bringing it forward again where it shows. It opens centred on the Space Lee is on, and otherwise
/// stays on its own (`ForwardWindow`), as About SitRep does. 840 by 540, never resized, black, in the system's frame:
/// its close button and ⌘W close it, however far Lee got, keeping what he set; it neither minimises nor zooms. Its
/// stage plays while it is in front, behind only settling what a change set moving, and what macOS says of the login
/// item and the two leaves is read each time it comes forward.
@MainActor
final class WelcomeWindow: NSObject, NSWindowDelegate {
    private let welcome: WelcomeModel
    private let frame: @MainActor (NSViewController) -> ForwardWindow
    private lazy var window = make()
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

    /// At its first step, whenever it opens; a visit under way goes on.
    func show() {
        welcome.open()
        window.comeForward()
    }

    /// SitRep quitting, which tells a window nothing: one showing closes as its close button would close it, so what
    /// closing does is done.
    func closeIfOpen() {
        if welcome.isVisiting {
            window.close()
        }
    }

    /// Whether SitRep, starting, opens it by itself, as Welcome… opens it: only on a Mac where none has ever closed.
    /// However it closes, quitting included, it is done with, so it never opens by itself again.
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
        let content = NSHostingController(rootView: WelcomeView(welcome: welcome, stage: stage))

        content.sizingOptions = []

        let window = Self.window(frame(content))

        window.delegate = self
        welcome.closeWindow = { [weak window] in window?.close() }
        return window
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
