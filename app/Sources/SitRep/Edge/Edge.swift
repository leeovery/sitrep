import AppKit
import SitRepCore
import SitRepEdge
import SitRepPanel

/// What shows at the screen's edge, as Lee set it: the notch or the strip on the chosen display, its settings saved as
/// one value and kept as a drag moves either, the Mac's Reduce motion followed as it changes, and nothing over a
/// full-screen app. Both take every board, so whichever Lee chooses shows it.
@MainActor
final class Edge {
    private let saved = SavedEdgeSettings()
    private var settings: EdgeSettings
    private let notch: NotchController
    private let strip: StripController
    private lazy var fullScreen = FullScreenWatch { [unowned self] in Displays.bounds(of: settings) }
    private var observers: [any NSObjectProtocol] = []

    /// `jump` jumps to a session, and tells once it answers whether it jumped; `isJumping` says whether one runs.
    init(jump: @escaping (String, @escaping (Bool) -> Void) -> Void, isJumping: @escaping () -> Bool) {
        let settings = saved.read(), display = Displays.chosen(settings)

        self.settings = settings
        notch = NotchController(settings, on: display)
        strip = StripController(settings, on: display)
        notch.onJump = jump
        strip.onJump = jump
        notch.isJumping = isJumping
        strip.isJumping = isJumping
        notch.onMoved = { [unowned self] in moved($0) }
        strip.onMoved = { [unowned self] in moved($0) }
        fullScreen.onChange = { [unowned self] in show() }
        listen()
        show()
    }

    /// The board as `watch` last printed it, for the notch and the strip.
    func show(_ last: LastBoard) {
        let board = PanelBoard(last)

        notch.show(board)
        strip.show(board)
    }

    /// A drag let the notch or the strip go: where it left it is saved, and both take it.
    private func moved(_ settings: EdgeSettings) {
        saved.save(settings)
        apply(settings)
    }

    /// With no `watch` to run, the notch's head says why, and the strip's notch at rest.
    func unrun(_ why: String) {
        let board = PanelBoard(unrun: why)

        notch.show(board)
        strip.show(board)
    }

    private func apply(_ settings: EdgeSettings) {
        let display = Displays.chosen(settings)

        self.settings = settings
        notch.apply(settings, on: display)
        strip.apply(settings, on: display)
        fullScreen.changed()
        show()
    }

    /// The notch or the strip, as Lee chose, unless he chose Nothing, or a full-screen app has the display.
    private func show() {
        let shows = !fullScreen.hasDisplay

        notch.isShown = shows && settings.show == .notch
        strip.isShown = shows && settings.show == .strip
    }

    /// The screens changing moves the edge to the display chosen, or the main one where that is gone; the Mac's
    /// Reduce motion changing shows in its next frame.
    private func listen() {
        observers = [
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    if let self {
                        self.apply(self.settings)
                    }
                }
            },
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.notch.wake()
                    self?.strip.wake()
                }
            },
        ]
    }
}
