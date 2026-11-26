import AppKit
import SitRepEdge

/// The notch's keys on the Mac (DESIGN, "Keys"): the tap, made as the panel opens where macOS gives the leave, so a
/// leave given while SitRep runs works from the next open, and let go at an open without it; on while the panel is out
/// or one of its menus is open, and only with the leave; whether the Mac lets the panel take keys, read as the panel
/// opens, as the pointer moves on it, and as macOS turns the tap off for input it can't see; and what the tap decides
/// each key by, told it as it changes. A snooze menu shown on its own takes its digits and `z` here; every other key the
/// tap hands on goes to the panel. The screens sleeping, the screen locking, the session going to another user, or a
/// window taking secure input, as the lock screen's password field and a sudo prompt do, let go of the keys.
@MainActor
final class NotchKeys {
    /// A key of the set while the panel holds the keys, and a key it doesn't take, in the hold of this number.
    var onKey: (PanelKey) -> Void = { _ in }
    var onLetGo: (Int) -> Void = { _ in }
    /// The screens slept, the screen locked, the session went to another user, or a window took secure input: the
    /// panel is to hold the keys no more, so what is typed after goes to the window in front.
    var onAway: () -> Void = {}

    private let mac: KeysMac
    /// Internal only for the tests, which read what it was told.
    private(set) var tap: (any KeyTapping)?
    /// Whether macOS gave the leave as the panel last opened.
    private var isTrusted = false
    /// Whether a window held secure input when last read.
    private var isSecure = false
    private var isOut = false
    /// What the panel holds, as the run last had it.
    private var held = KeySnapshot.none
    /// While one of the notch's menus is open, what the tap decides by: a snooze menu's choices, or the row's menu.
    private var menu: KeySnapshot?
    /// A snooze menu shown on its own, until it closes or a key chose from it or closed it.
    private var snoozeMenu: SnoozeMenu?
    /// The shortcut's hot key as macOS holds it, which the panel's hold lets through for macOS to hand SitRep, so the
    /// shortcut pressed again closes the panel by the hot key alone.
    var hotKey: TapChord? {
        didSet { tell() }
    }

    /// Held only so they leave their centres as the keys go.
    private var observers: Observers?

    /// What the distributed centre posts as the screen locks, which posts nothing to the workspace where the display
    /// stays awake, as at ⌃⌘Q or a hot corner.
    static let screenIsLocked = Notification.Name("com.apple.screenIsLocked")

    init(_ mac: KeysMac) {
        self.mac = mac

        let away = [
            (mac.workspace, NSWorkspace.screensDidSleepNotification),
            (mac.workspace, NSWorkspace.sessionDidResignActiveNotification), (mac.distributed, Self.screenIsLocked),
        ]

        observers = Observers(away.map { centre, name in
            (centre, centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onAway() }
            })
        })
    }

    /// Whether the Mac lets the panel take keys: the leave given as it opened, its tap made, and no window holding
    /// secure input.
    var allowed: Bool { tap != nil && isTrusted && !isSecure }

    /// The panel out or not, and what it holds: as it opens, the Mac read (`willOpen`).
    func follow(isOut: Bool, holding held: KeySnapshot) {
        if isOut, !self.isOut {
            willOpen()
        }
        self.isOut = isOut
        self.held = held
        tell()
    }

    /// The panel about to open: the leave and secure input read, the tap made where the leave is given and there is
    /// none yet, and let go where it is gone. The shortcut reads them before the panel opens, so the panel knows as it
    /// opens whether it may hold the keys.
    func willOpen() {
        isTrusted = mac.isTrusted()
        isSecure = mac.isSecure()
        if !isTrusted {
            tap = nil
        } else if tap == nil {
            tap = mac.tap({ [weak self] in self?.heard($0) }, { [weak self] in self?.readSecureInput() })
        }
    }

    /// The pointer moved while the panel is out: secure input read again.
    func pointerMoved() {
        if isOut {
            readSecureInput()
        }
    }

    /// A snooze menu about to show on its own: its digits and `z` the tap's until it closes.
    func shows(_ menu: SnoozeMenu) {
        snoozeMenu = menu
        self.menu = .menu(choices: menu.choiceItems.count)
        tell()
    }

    /// The row's menu about to show, which keeps AppKit's keys alone.
    func showsRowMenu() {
        menu = .menu(choices: nil)
        tell()
    }

    func menuClosed() {
        snoozeMenu = nil
        menu = nil
        tell()
    }

    /// Secure input read again: newly on, the keys let go.
    private func readSecureInput() {
        let was = isSecure

        isSecure = mac.isSecure()
        if isSecure, !was {
            onAway()
        }
    }

    /// The tap told whether it is on, only with the leave, and what it decides by: a menu's keys while one is open,
    /// else what the panel holds, passing the hot key; off, it decides by nothing.
    private func tell() {
        tap?.turn(on: isTrusted && (isOut || menu != nil), deciding: menu ?? held.passing(hotKey))
    }

    /// What the tap handed on. A snooze menu takes one choice or close alone, though more were handed on before the
    /// main thread woke.
    private func heard(_ action: KeyAction) {
        switch action {
        case let .panel(key): onKey(key)
        case let .letGo(hold): onLetGo(hold)
        case let .choose(number): takeSnoozeMenu()?.choose(number: number)
        case .closeMenu: takeSnoozeMenu()?.cancelTracking()
        }
    }

    private func takeSnoozeMenu() -> SnoozeMenu? {
        defer { snoozeMenu = nil }
        return snoozeMenu
    }
}

/// Observers, each in its centre, which leave it as they go.
private final class Observers {
    private let observers: [(NotificationCenter, any NSObjectProtocol)]

    init(_ observers: [(NotificationCenter, any NSObjectProtocol)]) {
        self.observers = observers
    }

    deinit {
        for (centre, observer) in observers {
            centre.removeObserver(observer)
        }
    }
}
