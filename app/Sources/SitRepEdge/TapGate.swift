/// The tap's own state, on its thread (DESIGN, "Keys"): whether the main thread means it on, what it decides each key
/// by, the keys it took or rewrote that have yet to come up, and whether it is enabled. It listens while it is meant
/// on, and after, until the last of those keys comes up, so a key taken is taken whole though the panel closed under
/// it; meant off, it decides by nothing, so every new key goes through. Each change returns what becomes of the tap,
/// which the tap applies under the same lock, so macOS turning it off meanwhile never leaves it on at rest.
public struct TapGate: Sendable {
    private var reader = KeyReader()
    /// What it decides each new key by: nothing while it is meant off.
    public private(set) var snapshot = KeySnapshot.none
    /// Whether the main thread means it on: the panel out, or one of its menus open.
    public private(set) var isMeantOn = false
    /// Whether the tap is enabled, as the gate last set it or macOS turned it off.
    public private(set) var isEnabled = false

    public init() {}

    /// Whether the tap is to be enabled: while it is meant on, or a key it took or rewrote has yet to come up.
    public var listens: Bool { isMeantOn || reader.hasKeysDown }

    /// The main thread's word: on, deciding by `snapshot`; off, deciding by nothing. The keys down stay down, so their
    /// key-ups go as they went down. True to enable the tap, false to disable it, nil to leave it.
    public mutating func turn(on isOn: Bool, deciding snapshot: KeySnapshot) -> Bool? {
        isMeantOn = isOn
        self.snapshot = isOn ? snapshot : .none
        return settle()
    }

    /// A key heard: what becomes of it, and of the tap, disabled once the last key it took comes up while it is meant
    /// off.
    public mutating func read(_ key: TapKey) -> (verdict: KeyVerdict, enable: Bool?) {
        let verdict = reader.read(key, in: snapshot)

        return (verdict, settle())
    }

    /// macOS turned the tap off, as it was slow to answer or input it can't see started: on again only while it
    /// listens.
    public mutating func turnedOff() -> Bool? {
        isEnabled = false
        return settle()
    }

    private mutating func settle() -> Bool? {
        guard listens != isEnabled else {
            return nil
        }

        isEnabled = listens
        return isEnabled
    }
}
