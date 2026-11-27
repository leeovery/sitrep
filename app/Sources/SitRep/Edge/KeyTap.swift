import AppKit
import Carbon.HIToolbox
import os
import SitRepEdge

/// The notch's tap on the keys, as the notch's keys turn it on and off and tell it what to decide by.
protocol KeyTapping: AnyObject {
    /// On while the panel is out or one of its menus is open, deciding each key by `snapshot`; off at rest, deciding
    /// by nothing, once the keys it took have come up (`TapGate`).
    func turn(on isOn: Bool, deciding snapshot: KeySnapshot)
}

/// What the notch's keys read of the Mac and make on it (DESIGN, "Keys"): whether macOS gives SitRep the
/// Accessibility leave, whether a window holds secure input, the tap, and the notifications that say when the screens
/// sleep or the session goes to another user, the workspace's, and when the screen locks or the screen saver starts,
/// the distributed centre's.
/// Given whole, so the tests make no tap and hear only their own.
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
    var workspace: NotificationCenter
    var distributed: NotificationCenter

    static let real = KeysMac(
        isTrusted: { AXIsProcessTrusted() }, isSecure: { IsSecureEventInputEnabled() },
        tap: { KeyTap(heard: $0, offForInput: $1) }, workspace: NSWorkspace.shared.notificationCenter,
        distributed: DistributedNotificationCenter.default()
    )
}

/// A Quartz event tap on the keys, a shell round `TapGate`: at the head of the session's events, on a thread of its
/// own with its own run loop, it decides each key there from the snapshot the main thread last gave it, and hands what
/// the key does to the main thread's run loop in its common modes, so it runs while a menu tracks. It never waits on
/// the main thread. A key taken goes nowhere; one rewritten goes on as the arrow it stands for. macOS turning it off, as
/// it is slow to answer or as input it can't see starts, turns it on again while it listens, the second telling the
/// main thread.
final class KeyTap: KeyTapping, @unchecked Sendable {
    private let box: TapBox
    private let port: CFMachPort
    private let thread: TapThread

    init?(
        heard: @escaping @MainActor @Sendable (KeyAction) -> Void,
        offForInput: @escaping @MainActor @Sendable () -> Void
    ) {
        let box = TapBox(heard: heard, offForInput: offForInput)
        let keys = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue)
        // the box lives as long as the thread whose callbacks read it, which lets it go as it ends
        let held = Unmanaged.passRetained(box)

        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: keys,
            callback: { _, type, event, box in
                box.map { Unmanaged<TapBox>.fromOpaque($0).takeUnretainedValue().tapped(type, event) }
                    ?? Unmanaged.passUnretained(event)
            },
            userInfo: held.toOpaque()
        ) else {
            held.release()
            return nil
        }

        // made enabled; disabled before it is scheduled, until the gate first turns it on
        CGEvent.tapEnable(tap: port, enable: false)
        box.port = port
        self.box = box
        self.port = port
        thread = TapThread(source: CFMachPortCreateRunLoopSource(nil, port, 0), holding: held)
    }

    deinit {
        CGEvent.tapEnable(tap: port, enable: false)
        CFMachPortInvalidate(port)
        thread.stop()
    }

    func turn(on isOn: Bool, deciding snapshot: KeySnapshot) {
        box.turn(on: isOn, deciding: snapshot)
    }

    /// The arrow of this code in a key's place, as Quartz makes one, with its modifiers, its time and its repeat, and
    /// the Fn and keypad flags an arrow key carries, so the menu reads it as any arrow; none where Quartz makes none.
    static func arrow(_ code: UInt16, for event: CGEvent, isDown: Bool) -> CGEvent? {
        guard let arrow = CGEvent(keyboardEventSource: CGEventSource(event: event), virtualKey: code, keyDown: isDown)
        else {
            return nil
        }

        arrow.flags = event.flags.union([.maskNumericPad, .maskSecondaryFn])
        arrow.timestamp = event.timestamp
        arrow.setIntegerValueField(.keyboardEventAutorepeat, value: event.getIntegerValueField(.keyboardEventAutorepeat))
        return arrow
    }
}

/// The tap's thread, its run loop running the tap's source until the tap is gone, then letting the box go. Stopped
/// before it first runs, it never does.
private final class TapThread: @unchecked Sendable {
    private let source: CFRunLoopSource
    private let box: Unmanaged<TapBox>
    /// The thread's run loop once it runs, and whether the tap is gone.
    private let state = OSAllocatedUnfairLock(uncheckedState: (loop: CFRunLoop?.none, isStopped: false))

    init(source: CFRunLoopSource, holding box: Unmanaged<TapBox>) {
        self.source = source
        self.box = box

        let thread = Thread { [self] in
            if start(on: CFRunLoopGetCurrent()) {
                CFRunLoopRun()
            }
            self.box.release()
        }

        thread.name = "SitRep keys"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// The source scheduled on the thread's run loop, unless the tap is gone already: whether to run it.
    private func start(on loop: CFRunLoop) -> Bool {
        state.withLockUnchecked { state in
            guard !state.isStopped else {
                return false
            }

            state.loop = loop
            CFRunLoopAddSource(loop, source, .commonModes)
            return true
        }
    }

    /// The tap gone: its source taken off the thread's run loop, and the loop stopped, so the thread ends.
    func stop() {
        state.withLockUnchecked { state in
            state.isStopped = true
            if let loop = state.loop {
                CFRunLoopRemoveSource(loop, source, .commonModes)
                CFRunLoopStop(loop)
            }
        }
    }
}

/// What the tap's thread shares with the main thread: the gate, under one lock the main thread holds only to turn the
/// tap on or off, inside which the tap is enabled or disabled as the gate says.
private final class TapBox: @unchecked Sendable {
    private let gate = OSAllocatedUnfairLock(initialState: TapGate())
    private let heard: @MainActor @Sendable (KeyAction) -> Void
    private let offForInput: @MainActor @Sendable () -> Void
    /// Set once, before the tap is scheduled.
    var port: CFMachPort?

    init(
        heard: @escaping @MainActor @Sendable (KeyAction) -> Void,
        offForInput: @escaping @MainActor @Sendable () -> Void
    ) {
        self.heard = heard
        self.offForInput = offForInput
    }

    func turn(on isOn: Bool, deciding snapshot: KeySnapshot) {
        gate.withLock { gate in
            enable(gate.turn(on: isOn, deciding: snapshot))
        }
    }

    /// An event on the tap's thread: a key decided, and what it does handed on; the tap turned on again where macOS
    /// turned it off while it listens.
    func tapped(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout:
            gate.withLock { enable($0.turnedOff()) }
        case .tapDisabledByUserInput:
            gate.withLock { enable($0.turnedOff()) }
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
        let verdict = gate.withLock { gate in
            let read = gate.read(key)

            enable(read.enable)
            return read.verdict
        }

        if let action = verdict.action {
            hand { [heard] in heard(action) }
        }
        switch verdict {
        case .pass, .letGo:
            return Unmanaged.passUnretained(event)
        case .take:
            return nil
        case let .rewrite(to: code):
            // handed back retained, as macOS releases what a tap returns in a key's place
            return KeyTap.arrow(code, for: event, isDown: isDown).map { Unmanaged.passRetained($0) }
                ?? Unmanaged.passUnretained(event)
        }
    }

    /// The tap enabled or disabled as the gate says, inside its lock.
    private func enable(_ enable: Bool?) {
        if let enable, let port {
            CGEvent.tapEnable(tap: port, enable: enable)
        }
    }

    /// Work for the main thread, run in its common modes, so a menu's tracking takes it too.
    private func hand(_ work: @escaping @MainActor @Sendable () -> Void) {
        let main = CFRunLoopGetMain()

        CFRunLoopPerformBlock(main, CFRunLoopMode.commonModes.rawValue) { MainActor.assumeIsolated(work) }
        CFRunLoopWakeUp(main)
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
