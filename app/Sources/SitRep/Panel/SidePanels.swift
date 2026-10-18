import AppKit
import SitRepPanel

/// The panel on the display in the form Lee chose to show, the notch or the strip; the other waits hidden. Both take
/// the menu's news, so whichever he chooses shows it, and the dials and the Mac's Reduce motion as they change.
@MainActor
final class SidePanels {
    private let dials: PanelDials
    private let notch: PanelController
    private let strip: StripController
    private var reduceMotion: (any NSObjectProtocol)?

    init(dials: PanelDials) {
        self.dials = dials
        notch = PanelController(dials: dials)
        strip = StripController(dials: dials)
        dials.onChange = { [unowned self] in retune() }
        reduceMotion = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.retune() }
        }
        show()
    }

    /// Whether anything needs Lee: for the spike, a toggle in the menu. On, it is a new ask for the strip; off, every
    /// ask a window holds is answered.
    var needsLee: Bool {
        get { notch.needsLee }
        set {
            notch.needsLee = newValue
            if newValue {
                strip.newAsk()
            } else {
                strip.answerAll()
            }
        }
    }

    /// A new ask, as the menu simulates one: the notch swells, and on the strip a needs you moves in.
    func newAsk() {
        notch.newAsk()
        strip.newAsk()
    }

    /// Both forms take what changed from their next frame, and the one chosen shows.
    private func retune() {
        notch.retune()
        strip.retune()
        show()
    }

    private func show() {
        notch.isShown = dials.show == .notch
        strip.isShown = dials.show == .strip
    }
}
