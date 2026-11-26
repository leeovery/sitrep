import AppKit
import SitRepCore
import SitRepEdge
import SitRepPanel

/// What shows at the screen's edge, as Lee set it: the notch on the chosen display, or nothing, following each change
/// Lee makes at once and keeping where a drag moves it, the Mac's Reduce motion followed as it changes, and nothing
/// over a full-screen app. The notch takes every board, hidden or not, so it shows the latest once Lee chooses it, and
/// shows the callout a welcome's Done leaves until Lee first points at it.
@MainActor
final class Edge {
    private let preferences: Preferences
    private var settings: EdgeSettings
    private let notch: NotchController
    /// Made only once the callout is first due, so a Mac long past it never has one.
    private var calloutWindow: CalloutWindow?
    private lazy var callout = EdgeCallout(
        preferences, shape: notch, isRight: { [unowned self] in settings.edge == .right }
    ) { [unowned self] in placeCallout($0) }
    private lazy var fullScreen = FullScreenWatch { [unowned self] in Displays.bounds(of: settings) }
    private var observers: [any NSObjectProtocol] = []
    /// The board as last heard, none before the first or with no `watch` to run, and the sessions on it a window holds
    /// that this Mac does not show.
    private var last: LastBoard?
    private var notHere: Set<String> = []

    /// What Lee set, followed as it changes; `jump` jumps to a session, and tells once it answers whether it jumped;
    /// `snoozes` snoozes and wakes a row's asks from its menu, and snoozes the ask the asks panel shows; `answers`
    /// holds and sends the asks panel's answers, and tells the notch of each.
    init(
        _ preferences: Preferences, jump: @escaping (String, @escaping (JumpAnswer) -> Void) -> Void, snoozes: Snoozes,
        answers: Answers
    ) {
        let settings = preferences.edge

        self.preferences = preferences
        self.settings = settings
        notch = Self.notch(preferences, on: Displays.chosen(settings), keys: .real)
        notch.onJump = jump
        notch.onSnooze = { snoozes.snoozeRow($0, showing: $1, $2) }
        notch.onSnoozeAsk = { snoozes.snoozeAsk($0, ask: $1, $2) }
        notch.onWake = { snoozes.wakeRow($0) }
        notch.onAnswer = { answers.hold($0) }
        notch.onUndo = { answers.undo() }
        answers.heard = { [unowned self] in notch.heard($0) }
        notch.onMoved = { [unowned self] in moved($0) }
        fullScreen.onChange = { [unowned self] in show() }
        preferences.onEdge = { [unowned self] in apply($0) }
        listen()
        show()
    }

    /// The notch on `display`, as `preferences` has it: its sections folded as kept, its keys read through `keys`, and
    /// each row's Snooze offering the choices as Lee has them as its menu opens. Apart from `init`, so the tests make it
    /// on no screen, and with no tap.
    static func notch(_ preferences: Preferences, on display: Display, keys: KeysMac) -> NotchController {
        NotchController(
            preferences.edge, on: display, folding: Folding(kept: preferences.savedCard), keys: keys,
            snoozeSettings: { preferences.snooze }
        )
    }

    /// The board as `watch` last printed it, for the notch, pulsing it as Lee set it.
    func show(_ last: LastBoard) {
        self.last = last
        tell(PanelBoard(last, notHere: notHere, pulses: preferences.app.pulses))
    }

    /// The sessions a window holds that this Mac does not show, dimmed at once on the board as last heard, nothing
    /// on it new again.
    func show(notHere: Set<String>) {
        self.notHere = notHere
        if let last {
            tell(PanelBoard(last, notHere: notHere, pulses: preferences.app.pulses).retold)
        }
    }

    /// A drag let the notch go: where it left it lands on the settings as they stand, is kept, and the notch takes
    /// it. A move changes only the edge and the place along it, never what shows nor on which display, so what shows
    /// is left as it is.
    private func moved(_ move: EdgeMove) {
        let settings = move.applied(to: settings)

        preferences.moved(settings)
        place(settings)
    }

    /// A jump's news, whichever surface asked for it: the notch's caption says it while the notch shows.
    func heard(_ news: JumpNews) {
        notch.heard(news)
    }

    /// With no `watch` to run, the notch's head says why.
    func unrun(_ why: String) {
        last = nil
        tell(PanelBoard(unrun: why))
    }

    /// A board to the notch, and the callout beside it as it now rests: an ask moves the notch's front out at once,
    /// where the last one going takes the notch's next frame, which the callout hears of itself.
    private func tell(_ board: PanelBoard) {
        notch.show(board)
        callout.refresh()
    }

    /// What Lee changed in Settings or the menu, at once.
    private func apply(_ settings: EdgeSettings) {
        place(settings)
        fullScreen.changed()
        show()
    }

    /// The settings, to the notch, on the display they choose.
    private func place(_ settings: EdgeSettings) {
        let display = Displays.chosen(settings)

        self.settings = settings
        notch.apply(settings, on: display)
        callout.refresh()
    }

    /// The notch, as Lee chose, unless he chose Nothing, or a full-screen app has the display.
    private func show() {
        notch.isShown = settings.show == .notch && !fullScreen.hasDisplay
        callout.refresh()
    }

    /// The callout's window, made as the callout is first placed.
    private func placeCallout(_ beside: EdgeCallout.Beside?) {
        if beside != nil, calloutWindow == nil {
            calloutWindow = CalloutWindow()
        }
        calloutWindow?.place(beside)
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
                }
            },
        ]
    }
}
