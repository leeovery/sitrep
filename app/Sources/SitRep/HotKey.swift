import Carbon.HIToolbox
import os
import SitRepCore
import SitRepMenu

extension Shortcut {
    /// The shortcut pressed (DESIGN, "Keys"): the notch's panel, where the notch takes it while it shows; else the menu
    /// bar item's menu, as under Nothing or with a full-screen app hiding the notch.
    @MainActor
    static func press(notch: () -> Bool, menu: () -> Void) {
        if !notch() {
            menu()
        }
    }
}

/// Carbon's hot key, as the shortcut's hot key registers it and lets it go: given whole, so the tests register none.
@MainActor
protocol HotKeyCarbon: AnyObject {
    /// Whether macOS took it.
    func register(_ chord: KeyChord) -> Bool
    func unregister()
}

/// The shortcut's hot key (DESIGN, "Keys"): one macOS keeps, needing no leave, registered from the shortcut Lee set at
/// launch and again as he changes it, and none while he has cleared it, or while Settings records another, so pressing
/// the one set records it rather than opening the panel.
@MainActor
final class HotKey {
    /// The shortcut Lee set; nil, cleared.
    var chord: KeyChord? {
        didSet { settle() }
    }

    /// While Settings records a shortcut.
    var isSuspended = false {
        didSet { settle() }
    }

    /// What macOS holds now, told to `onRegistered` as it changes.
    private(set) var registered: KeyChord? {
        didSet {
            if registered != oldValue {
                onRegistered(registered)
            }
        }
    }

    /// Whether macOS refused the shortcut set, as it refuses one another app holds.
    private(set) var isRefused = false
    var onRegistered: (KeyChord?) -> Void = { _ in }
    private let carbon: any HotKeyCarbon

    init(_ carbon: any HotKeyCarbon, chord: KeyChord?) {
        self.carbon = carbon
        self.chord = chord
        settle()
    }

    /// What macOS holds made what it should: the one registered let go, and the one wanted registered, where macOS
    /// takes it; one it refused is tried again at the next change.
    private func settle() {
        let wanted = isSuspended ? nil : chord

        if wanted != registered {
            if registered != nil {
                carbon.unregister()
            }
            registered = wanted.flatMap { carbon.register($0) ? $0 : nil }
        }
        isRefused = wanted != nil && registered == nil
    }
}

/// Carbon's hot key on the application's event target, which hears it on the main thread wherever the keyboard is,
/// with no leave: one at a time, its press told to `pressed`.
@MainActor
final class CarbonHotKey: HotKeyCarbon {
    private let box: Pressed
    private var handler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private let logger = Logger(sitrep: "keys")

    /// SitRep's signature on its hot key, `SRsc`.
    private static let id = EventHotKeyID(signature: 0x5352_7363, id: 1)

    init(pressed: @escaping @MainActor () -> Void) {
        box = Pressed(pressed)

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, box in
                guard let box else {
                    return OSStatus(eventNotHandledErr)
                }

                let pressed = Unmanaged<Pressed>.fromOpaque(box).takeUnretainedValue()

                MainActor.assumeIsolated { pressed.press() }
                return noErr
            },
            1, &spec, Unmanaged.passUnretained(box).toOpaque(), &handler
        )

        if status != noErr {
            logger.error("The shortcut's handler was not installed: \(status, privacy: .public)")
        }
    }

    isolated deinit {
        unregister()
        if let handler {
            RemoveEventHandler(handler)
        }
    }

    func register(_ chord: KeyChord) -> Bool {
        let status = RegisterEventHotKey(
            UInt32(chord.code), chord.modifiers.rawValue, Self.id, GetApplicationEventTarget(), 0, &hotKey
        )

        guard status == noErr else {
            logger.error("macOS refused the shortcut: \(status, privacy: .public)")
            hotKey = nil
            return false
        }

        return true
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        hotKey = nil
    }

    /// What a press tells, held where Carbon's handler can find it.
    private final class Pressed {
        let press: @MainActor () -> Void

        init(_ press: @escaping @MainActor () -> Void) {
            self.press = press
        }
    }
}
