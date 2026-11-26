import Foundation
@testable import SitRep
import SitRepEdge

extension KeysMac {
    /// A Mac giving no Accessibility leave, so the notch makes no tap and takes no keys.
    static let none = KeysMac(
        isTrusted: { false }, isSecure: { false }, tap: { _, _ in nil }, workspace: NotificationCenter(),
        distributed: NotificationCenter()
    )
}

/// A Mac of the test's own for the notch's keys: whether it gives the leave and holds secure input, the tap it makes,
/// a double through which the test hands keys on as the tap would, and its workspace's and distributed centre's
/// notifications, posted to it alone.
@MainActor
final class KeysWorld {
    var isTrusted = true
    var isSecure = false
    let workspace = NotificationCenter(), distributed = NotificationCenter()
    private(set) var taps: [Tap] = []

    /// A tap that hears no keys: the gate it keeps as the real one does, as it was told, and what it hands the main
    /// thread.
    final class Tap: KeyTapping {
        private(set) var gate = TapGate()
        let heard: @MainActor @Sendable (KeyAction) -> Void
        let offForInput: @MainActor @Sendable () -> Void

        init(
            heard: @escaping @MainActor @Sendable (KeyAction) -> Void,
            offForInput: @escaping @MainActor @Sendable () -> Void
        ) {
            self.heard = heard
            self.offForInput = offForInput
        }

        /// Whether it is meant on, and what it decides each new key by.
        var isOn: Bool { gate.isMeantOn }
        var snapshot: KeySnapshot { gate.snapshot }

        func turn(on isOn: Bool, deciding snapshot: KeySnapshot) {
            _ = gate.turn(on: isOn, deciding: snapshot)
        }

        /// What becomes of a key pressed now, as the real tap decides it.
        func read(_ key: TapKey) -> KeyVerdict {
            gate.read(key).verdict
        }
    }

    var mac: KeysMac {
        KeysMac(isTrusted: { self.isTrusted }, isSecure: { self.isSecure }, tap: { heard, offForInput in
            let tap = Tap(heard: heard, offForInput: offForInput)

            self.taps.append(tap)
            return tap
        }, workspace: workspace, distributed: distributed)
    }
}
