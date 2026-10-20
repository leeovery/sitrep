import AppKit
import SwiftUI

/// The one Settings window, made as it first opens: opening it again brings it forward, on the pane last used.
@MainActor
final class SettingsWindow {
    private let preferences: Preferences
    private let live: LiveBoard
    private let services: SettingsServices
    private var window: NSWindow?

    init(preferences: Preferences, live: LiveBoard, services: SettingsServices) {
        self.preferences = preferences
        self.live = live
        self.services = services
    }

    func show() {
        let window = window ?? made()

        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func made() -> NSWindow {
        Self.window(NSHostingController(rootView: SettingsView(preferences: preferences, live: live, services: services)))
    }

    /// The window, closable and minimisable so the main menu's ⌘W and ⌘M reach it (`AppMenu`).
    static func window(_ content: NSViewController) -> NSWindow {
        let window = NSWindow(contentViewController: content)

        window.title = "SitRep Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 700, height: 540))
        window.contentMinSize = NSSize(width: 620, height: 460)
        window.center()

        return window
    }
}
