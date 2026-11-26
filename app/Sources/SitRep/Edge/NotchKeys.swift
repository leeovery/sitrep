import AppKit
import SitRepEdge

/// The notch's keys on the Mac (DESIGN, "Keys"): the tap, made as the panel opens where macOS gives the leave, so a
/// leave given while SitRep runs works from the next open, and on while the panel is out or one of its menus is open;
/// whether the Mac lets the panel take keys, read as the panel opens, as the pointer moves on it, and as macOS turns the
/// tap off for input it can't see; and what the tap decides each key by, published as it changes. A snooze menu shown
/// on its own takes its digits and `z` here; every other key the tap hands on goes to the panel.
@MainActor
final class NotchKeys {
    /// A key of the set while the panel holds the keys, and a key it doesn't take, in the hold of this number.
    var onKey: (PanelKey) -> Void = { _ in }
    var onLetGo: (Int) -> Void = { _ in }

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
    /// A snooze menu shown on its own, while it is.
    private var snoozeMenu: SnoozeMenu?

    init(_ mac: KeysMac) {
        self.mac = mac
    }

    /// Whether the Mac lets the panel take keys: the leave given as it opened, its tap made, and no window holding
    /// secure input.
    var allowed: Bool { tap != nil && isTrusted && !isSecure }

    /// The panel out or not, and what it holds: as it opens, the leave and secure input read, and the tap made where
    /// the leave is given and there is none yet.
    func follow(isOut: Bool, holding held: KeySnapshot) {
        if isOut, !self.isOut {
            isTrusted = mac.isTrusted()
            isSecure = mac.isSecure()
            if isTrusted, tap == nil {
                tap = mac.tap({ [weak self] in self?.heard($0) }, { [weak self] in self?.readSecureInput() })
            }
        }
        self.isOut = isOut
        self.held = held
        publish()
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
        publish()
    }

    /// The row's menu about to show, which keeps AppKit's keys alone.
    func showsRowMenu() {
        menu = .menu(choices: nil)
        publish()
    }

    func menuClosed() {
        snoozeMenu = nil
        menu = nil
        publish()
    }

    private func readSecureInput() {
        isSecure = mac.isSecure()
    }

    private func publish() {
        tap?.isOn = isOut || menu != nil
        tap?.publish(menu ?? held)
    }

    private func heard(_ action: KeyAction) {
        switch action {
        case let .panel(key): onKey(key)
        case let .letGo(hold): onLetGo(hold)
        case let .choose(number): snoozeMenu?.choose(number: number)
        case .closeMenu: snoozeMenu?.cancelTracking()
        }
    }
}
