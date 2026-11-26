import ApplicationServices
import Carbon.HIToolbox
import os
import SitRepEdge

/// The notch's tap on the keys, as the notch's keys turn it on and off and tell it what to decide by.
protocol KeyTapping: AnyObject {
    /// On while the panel is out or one of its menus is open; at rest it hears nothing.
    var isOn: Bool { get set }
    /// What it decides each key by from now on.
    func publish(_ snapshot: KeySnapshot)
}

/// What the notch's keys read of the Mac and make on it (DESIGN, "Keys"): whether macOS gives SitRep the
/// Accessibility leave, whether a window holds secure input, and the tap. Given whole, so the tests make no tap.
@MainActor
struct KeysMac {
    var isTrusted: () -> Bool
    var isSecure: () -> Bool
    /// The tap, handing each key's action to `heard`, and telling `offForInput` each time macOS turns it off as input
    /// it can't see starts; none where macOS makes none, as without the leave.
    var tap: (
        _ heard: @escaping @MainActor @Sendable (KeyAction) -> Void,
        _ offForInput: @escaping @MainActor @Sendable () -> Void
    ) -> (any KeyTapping)?

    static let real = KeysMac(
        isTrusted: { AXIsProcessTrusted() }, isSecure: { IsSecureEventInputEnabled() },
        tap: { KeyTap(heard: $0, offForInput: $1) }
    )
}

/// A Quartz event tap on the keys, a shell round `KeyReader`: at the head of the session's events, on a thread of its
/// own with its own run loop, it decides each key there from the snapshot the main thread last published, and hands
/// what the key does to the main thread's run loop in its common modes, so it runs while a menu tracks. It never waits
/// on the main thread. A key taken goes nowhere; one rewritten goes on as the arrow it stands for. macOS turning it off,
/// as it is slow to answer or as input it can't see starts, turns it on again, the second telling the main thread.
final class KeyTap: KeyTapping, @unchecked Sendable {
    private let box: TapBox
    private let port: CFMachPort

    init?(
        heard: @escaping @MainActor @Sendable (KeyAction) -> Void,
        offForInput: @escaping @MainActor @Sendable () -> Void
    ) {
        let box = TapBox(heard: heard, offForInput: offForInput)
        let keys = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue)

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: keys,
            callback: { _, type, event, box in
                box.map { Unmanaged<TapBox>.fromOpaque($0).takeUnretainedValue().tapped(type, event) }
                    ?? Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(box).toOpaque()
        ) else {
            return nil
        }

        self.box = box
        self.port = port
        box.port = port
        CGEvent.tapEnable(tap: port, enable: false)
        Self.listen(to: port)
    }

    deinit {
        CGEvent.tapEnable(tap: port, enable: false)
        // with its source gone, the run loop has none left, and its thread ends
        CFMachPortInvalidate(port)
    }

    var isOn = false {
        didSet {
            guard isOn != oldValue else {
                return
            }

            box.turn(on: isOn)
            CGEvent.tapEnable(tap: port, enable: isOn)
        }
    }

    func publish(_ snapshot: KeySnapshot) {
        box.publish(snapshot)
    }

    /// The tap's events heard on a thread of its own, its run loop running until the tap is gone.
    private static func listen(to port: CFMachPort) {
        let source = Source(CFMachPortCreateRunLoopSource(nil, port, 0))
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source.source, .commonModes)
            CFRunLoopRun()
        }

        thread.name = "SitRep keys"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// The tap's run loop source, handed to its thread once, before it runs.
    private struct Source: @unchecked Sendable {
        let source: CFRunLoopSource

        init(_ source: CFRunLoopSource) {
            self.source = source
        }
    }
}

/// What the tap's thread shares with the main thread: the snapshot published and the reader deciding by it, under one
/// lock the main thread holds only to publish, and whether the tap is meant to be on.
private final class TapBox: @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let heard: @MainActor @Sendable (KeyAction) -> Void
    private let offForInput: @MainActor @Sendable () -> Void
    /// Set once, before the tap is first on.
    var port: CFMachPort?

    private struct State: Sendable {
        var snapshot = KeySnapshot.none
        var reader = KeyReader()
        var isOn = false
    }

    init(
        heard: @escaping @MainActor @Sendable (KeyAction) -> Void,
        offForInput: @escaping @MainActor @Sendable () -> Void
    ) {
        self.heard = heard
        self.offForInput = offForInput
    }

    func publish(_ snapshot: KeySnapshot) {
        state.withLock { $0.snapshot = snapshot }
    }

    /// On or off; turned on, it starts afresh, a key-up missed while it was off forgotten.
    func turn(on isOn: Bool) {
        state.withLock { state in
            if isOn, !state.isOn {
                state.reader = KeyReader()
            }
            state.isOn = isOn
        }
    }

    /// An event on the tap's thread: a key decided, and what it does handed on; the tap turned on again where macOS
    /// turned it off while it is meant to be on.
    func tapped(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout:
            turnOnAgain()
        case .tapDisabledByUserInput:
            turnOnAgain()
            hand(offForInput)
        case .keyDown, .keyUp:
            return key(event, isDown: type == .keyDown)
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func key(_ event: CGEvent, isDown: Bool) -> Unmanaged<CGEvent>? {
        let key = TapKey(event, isDown: isDown)
        let verdict = state.withLock { $0.reader.read(key, in: $0.snapshot) }

        if let action = verdict.action {
            hand { [heard] in heard(action) }
        }
        switch verdict {
        case .pass, .letGo: return Unmanaged.passUnretained(event)
        case .take: return nil
        case let .rewrite(to: code): return Self.arrow(code, for: event, isDown: isDown)
        }
    }

    private func turnOnAgain() {
        if let port, state.withLock({ $0.isOn }) {
            CGEvent.tapEnable(tap: port, enable: true)
        }
    }

    /// Work for the main thread, run in its common modes, so a menu's tracking takes it too.
    private func hand(_ work: @escaping @MainActor @Sendable () -> Void) {
        let main = CFRunLoopGetMain()

        CFRunLoopPerformBlock(main, CFRunLoopMode.commonModes.rawValue) { MainActor.assumeIsolated(work) }
        CFRunLoopWakeUp(main)
    }

    /// The arrow of this code in a key's place, as Quartz makes one, with its modifiers, its time and its repeat, and
    /// the Fn and keypad flags an arrow key carries, so the menu reads it as any arrow; the key itself, where Quartz
    /// makes none. Handed back retained, as macOS releases what a tap returns.
    private static func arrow(_ code: UInt16, for event: CGEvent, isDown: Bool) -> Unmanaged<CGEvent>? {
        guard let arrow = CGEvent(keyboardEventSource: CGEventSource(event: event), virtualKey: code, keyDown: isDown)
        else {
            return Unmanaged.passUnretained(event)
        }

        arrow.flags = event.flags.union([.maskNumericPad, .maskSecondaryFn])
        arrow.timestamp = event.timestamp
        arrow.setIntegerValueField(.keyboardEventAutorepeat, value: event.getIntegerValueField(.keyboardEventAutorepeat))
        return Unmanaged.passRetained(arrow)
    }
}

extension TapKey {
    /// A key as Quartz's event has it: its code, what it types on the current layout, its modifiers, and whether it
    /// goes down, repeats, or comes up.
    init(_ event: CGEvent, isDown: Bool) {
        var units = [UniChar](repeating: 0, count: 4)
        var length = 0

        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)

        let repeats = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        self.init(
            code: UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode)),
            typed: String(utf16CodeUnits: units, count: length), flags: event.flags,
            stroke: isDown ? repeats ? .again : .down : .up
        )
    }
}
