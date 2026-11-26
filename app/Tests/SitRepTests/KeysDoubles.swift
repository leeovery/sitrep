@testable import SitRep
import SitRepEdge

extension KeysMac {
    /// A Mac giving no Accessibility leave, so the notch makes no tap and takes no keys.
    static let none = KeysMac(isTrusted: { false }, isSecure: { false }, tap: { _, _ in nil })
}

/// A Mac of the test's own for the notch's keys: whether it gives the leave and holds secure input, and the tap it
/// makes, a double recording what it was told, through which the test hands keys on as the tap would.
@MainActor
final class KeysWorld {
    var isTrusted = true
    var isSecure = false
    private(set) var taps: [Tap] = []

    /// A tap that hears no keys: what it was told, and what it hands the main thread.
    final class Tap: KeyTapping {
        var isOn = false
        private(set) var snapshots: [KeySnapshot] = []
        let heard: @MainActor @Sendable (KeyAction) -> Void
        let offForInput: @MainActor @Sendable () -> Void

        init(
            heard: @escaping @MainActor @Sendable (KeyAction) -> Void,
            offForInput: @escaping @MainActor @Sendable () -> Void
        ) {
            self.heard = heard
            self.offForInput = offForInput
        }

        var snapshot: KeySnapshot? { snapshots.last }

        func publish(_ snapshot: KeySnapshot) {
            snapshots.append(snapshot)
        }
    }

    var mac: KeysMac {
        KeysMac(isTrusted: { self.isTrusted }, isSecure: { self.isSecure }) { heard, offForInput in
            let tap = Tap(heard: heard, offForInput: offForInput)

            self.taps.append(tap)
            return tap
        }
    }
}
