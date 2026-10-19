import AppKit
import SitRepCore
import SitRepEdge
import SitRepPanel

/// What shows at the screen's edge, as Lee set it: the notch on the chosen display, its settings saved as one value
/// and kept as a drag moves it, the Mac's Reduce motion followed as it changes, and nothing over a full-screen app.
@MainActor
final class Edge {
    private let saved = SavedEdgeSettings()
    private var settings: EdgeSettings
    private let notch: NotchController
    private lazy var fullScreen = FullScreenWatch { [unowned self] in Displays.bounds(of: settings) }
    private var observers: [any NSObjectProtocol] = []

    /// `jump` jumps to a session, and tells once it answers whether it jumped.
    init(jump: @escaping (String, @escaping (Bool) -> Void) -> Void) {
        let settings = saved.read()

        self.settings = settings
        notch = NotchController(settings, on: Displays.chosen(settings))
        notch.onJump = jump
        notch.onMoved = { [unowned self] moved in
            saved.save(moved)
            apply(moved)
        }
        fullScreen.onChange = { [unowned self] in show() }
        listen()
        show()
    }

    /// The board as `watch` last printed it, for the notch.
    func show(_ last: LastBoard) {
        notch.show(PanelBoard(last))
    }

    private func apply(_ settings: EdgeSettings) {
        self.settings = settings
        notch.apply(settings, on: Displays.chosen(settings))
        fullScreen.changed()
        show()
    }

    private func screensChanged() {
        apply(settings)
    }

    /// The notch shows unless Lee chose Nothing, or a full-screen app has its display. Until the strip is built, the
    /// strip chosen shows the notch.
    private func show() {
        notch.isShown = settings.show != .nothing && !fullScreen.hasDisplay
    }

    /// The screens changing moves the notch to the display chosen, or the main one where that is gone; the Mac's
    /// Reduce motion changing shows in its next frame.
    private func listen() {
        observers = [
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.screensChanged() }
            },
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.notch.wake() }
            },
        ]
    }
}
