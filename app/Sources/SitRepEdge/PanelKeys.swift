import CoreGraphics

/// A key of the panel's set (DESIGN, "Keys"), pressed alone: what it means wherever it applies.
public enum PanelKey: Equatable, Sendable {
    /// `↑` or `k`, and `↓` or `j`: the lit row, or a menu's highlight, moved.
    case up, down
    /// `←` and `→`: the asks panel's asks paged.
    case left, right
    /// `⏎`, Return or keypad Enter: a closer look.
    case enter
    case escape
    /// `o`: the lit row's window jumped to.
    case open
    /// `z`: a snooze, or a wake.
    case snooze
    /// `s`: Snoozed folded or unfolded.
    case fold
    /// `x`: the ask shown ignored.
    case ignore
    /// `1` to `9`.
    case digit(Int)

    /// Whether held, it acts again at each repeat, as a Mac menu's arrows do: any other's repeats are dropped, so a
    /// held digit answers once.
    var repeats: Bool {
        switch self {
        case .up, .down, .left, .right: true
        case .enter, .escape, .open, .snooze, .fold, .ignore, .digit: false
        }
    }
}

/// The keys read by their codes, whatever the layout: the arrows, Return, keypad Enter and Esc.
public enum KeyCode {
    public static let enter: UInt16 = 36, keypadEnter: UInt16 = 76, escape: UInt16 = 53
    public static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126
}

/// A key as the tap reads it off Quartz: its code, what it types on the current layout, the modifiers held, and
/// whether it goes down, repeats as it is held, or comes up.
public struct TapKey: Equatable, Sendable {
    public enum Stroke: Equatable, Sendable {
        case down, again, up
    }

    public var code: UInt16
    public var typed: String
    public var flags: CGEventFlags
    public var stroke: Stroke

    public init(code: UInt16, typed: String = "", flags: CGEventFlags = [], stroke: Stroke = .down) {
        self.code = code
        self.typed = typed
        self.flags = flags
        self.stroke = stroke
    }

    /// The key of the panel's set it is: by its code for the arrows, Return, keypad Enter and Esc, else by what it
    /// types, a letter's case aside, as Caps Lock types it; none with Shift, ⌘, ⌃ or ⌥ held, which make it another
    /// key. An arrow's own flags, Fn and the keypad's, are no modifier.
    var panelKey: PanelKey? {
        guard flags.isDisjoint(with: Self.modifiers) else {
            return nil
        }

        return Self.byCode[code] ?? Self.byTyping[typed.lowercased()]
    }

    private static let modifiers: CGEventFlags = [.maskShift, .maskCommand, .maskControl, .maskAlternate]

    private static let byCode: [UInt16: PanelKey] = [
        KeyCode.up: .up, KeyCode.down: .down, KeyCode.left: .left, KeyCode.right: .right,
        KeyCode.enter: .enter, KeyCode.keypadEnter: .enter, KeyCode.escape: .escape,
    ]

    private static let byTyping: [String: PanelKey] = [
        "k": .up, "j": .down, "o": .open, "z": .snooze, "s": .fold, "x": .ignore,
    ].merging((1 ... 9).map { ("\($0)", PanelKey.digit($0)) }) { $1 }
}

/// What the main thread last published for the tap to decide each key by, kept small (DESIGN, "Keys").
public enum KeySnapshot: Equatable, Sendable {
    /// Nothing holds the keys: each goes through.
    case none
    /// The panel holds them, in its hold of this number: every key of the set is its, and any other ends the hold.
    case panel(hold: Int)
    /// One of the notch's menus is open: a snooze menu shown on its own, of this many choices, whose digits, `z`, `k`
    /// and `j` the tap takes; or, with none, the row's menu, which keeps AppKit's keys alone.
    case menu(choices: Int?)
}

/// What a key the tap takes, or lets go by, does, handed to the main thread.
public enum KeyAction: Equatable, Sendable {
    /// A key of the set while the panel holds the keys.
    case panel(PanelKey)
    /// A key the panel doesn't take, in the hold of this number: the panel holds none until the pointer moves again.
    case letGo(hold: Int)
    /// A snooze menu's choice of this number, from 1.
    case choose(Int)
    /// `z` in a snooze menu: its tracking ended.
    case closeMenu
}

/// What becomes of a key: it goes through, to the window in front or the menu; it goes through and the panel lets go
/// of the keys, in the hold of this number; it is taken, going nowhere, doing what it does, if anything; or it goes
/// through as another key.
public enum KeyVerdict: Equatable, Sendable {
    case pass
    case letGo(hold: Int)
    case take(KeyAction?)
    case rewrite(to: UInt16)

    /// What the main thread is handed.
    public var action: KeyAction? {
        switch self {
        case let .take(action): action
        case let .letGo(hold): .letGo(hold: hold)
        case .pass, .rewrite: nil
        }
    }
}

/// How the tap decides each key, on its own thread, from the snapshot the main thread last published (DESIGN, "Keys").
/// A key taken is taken whole: its repeats and its key-up go as it went down, taken or rewritten, whatever the snapshot
/// says by then. Only `↑` `↓`, `k` `j`, `←` and `→` act again as they repeat. A key the panel doesn't take ends its hold
/// here at once, so the keys typed after it go through though the main thread has yet to hear of it.
public struct KeyReader: Sendable {
    /// How a key down went, which its repeats and its key-up follow.
    private enum Went: Sendable {
        case taken
        case rewritten(UInt16)
    }

    /// The keys down that went other than through, by their codes.
    private var down: [UInt16: Went] = [:]
    /// The hold a key the panel doesn't take ended.
    private var ended: Int?

    public init() {}

    public mutating func read(_ key: TapKey, in snapshot: KeySnapshot) -> KeyVerdict {
        switch key.stroke {
        case .down: pressed(key, in: snapshot)
        case .again: repeated(key, in: snapshot)
        case .up: lifted(key)
        }
    }

    private mutating func pressed(_ key: TapKey, in snapshot: KeySnapshot) -> KeyVerdict {
        let verdict = fresh(key, in: snapshot)

        switch verdict {
        case .take: down[key.code] = .taken
        case let .rewrite(code): down[key.code] = .rewritten(code)
        case .pass, .letGo: down[key.code] = nil
        }
        return verdict
    }

    private func repeated(_ key: TapKey, in snapshot: KeySnapshot) -> KeyVerdict {
        switch down[key.code] {
        case nil:
            .pass
        case let .rewritten(code)?:
            .rewrite(to: code)
        case .taken?:
            .take(key.panelKey.flatMap { $0.repeats && holds(snapshot) ? .panel($0) : nil })
        }
    }

    private mutating func lifted(_ key: TapKey) -> KeyVerdict {
        switch down.removeValue(forKey: key.code) {
        case nil: .pass
        case let .rewritten(code)?: .rewrite(to: code)
        case .taken?: .take(nil)
        }
    }

    private mutating func fresh(_ key: TapKey, in snapshot: KeySnapshot) -> KeyVerdict {
        switch snapshot {
        case .none, .menu(choices: nil):
            return .pass
        case let .menu(choices?):
            return Self.menu(key, of: choices)
        case let .panel(hold):
            guard hold != ended else {
                return .pass
            }
            guard let panelKey = key.panelKey else {
                ended = hold
                return .letGo(hold: hold)
            }

            return .take(.panel(panelKey))
        }
    }

    private func holds(_ snapshot: KeySnapshot) -> Bool {
        guard case let .panel(hold) = snapshot else {
            return false
        }

        return hold != ended
    }

    /// In a snooze menu shown on its own: a digit chooses its choice, doing nothing past its last; `z` ends its
    /// tracking; `k` and `j` go on as `↑` and `↓`. Its arrows, Return and Esc are AppKit's own, as is every other key.
    private static func menu(_ key: TapKey, of choices: Int) -> KeyVerdict {
        switch key.panelKey {
        case .up? where key.code != KeyCode.up: .rewrite(to: KeyCode.up)
        case .down? where key.code != KeyCode.down: .rewrite(to: KeyCode.down)
        case .snooze?: .take(.closeMenu)
        case let .digit(number)?: .take(number <= choices ? .choose(number) : nil)
        default: .pass
        }
    }
}
