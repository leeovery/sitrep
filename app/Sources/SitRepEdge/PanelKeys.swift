import CoreGraphics

/// A key of the panel's set (DESIGN, "Keys"), pressed alone, `⌘Z` aside: what it means wherever it applies.
public enum PanelKey: Equatable, Sendable {
    /// `↑` or `k`, and `↓` or `j`: the lit row, or a menu's highlight, moved.
    case up, down
    /// `←` and `→`: a step along the line out from the notch, the asks panel beside the list and its asks beyond,
    /// out or back by the notch's edge.
    case left, right
    /// `⏎`, Return or keypad Enter: as `o`.
    case enter
    case escape
    /// `o`: the lit row's window jumped to, or, on the asks panel, Open in Claude.
    case open
    /// `z`: a snooze, or a wake.
    case snooze
    /// `s`: Snoozed folded or unfolded.
    case fold
    /// `x`: the ask shown ignored.
    case ignore
    /// `1` to `9`.
    case digit(Int)
    /// `⌘Z`: the answer the asks panel is sending taken back, as its Undo.
    case undo

    /// Whether held, it acts again at each repeat, as a Mac menu's arrows do: any other's repeats are dropped, so a
    /// held digit answers once.
    var repeats: Bool {
        switch self {
        case .up, .down, .left, .right: true
        case .enter, .escape, .open, .snooze, .fold, .ignore, .digit, .undo: false
        }
    }

    /// Whether it jumps, `o` or `⏎`, so the keys typed after it are the window's it jumps to.
    var jumps: Bool { self == .open || self == .enter }
}

/// The keys read by their codes, whatever the layout: the arrows, Return, keypad Enter and Esc.
public enum KeyCode {
    public static let enter: UInt16 = 36, keypadEnter: UInt16 = 76, escape: UInt16 = 53
    public static let left: UInt16 = 123, right: UInt16 = 124, down: UInt16 = 125, up: UInt16 = 126
    /// The keys macOS sends with Fn of themselves: the arrows, Home, End, Page Up, Page Down, Forward Delete and Help.
    static let carriesFn: Set<UInt16> = [left, right, down, up, 115, 119, 116, 121, 117, 114]
    /// F1 to F20.
    static let functionKeys: Set<UInt16> = [
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90,
    ]
}

/// The shortcut's hot key as the tap reads a key: its code, and the modifiers held with it, of Shift, ⌘, ⌃ and ⌥.
public struct TapChord: Equatable, Sendable {
    public var code: UInt16
    public var flags: CGEventFlags

    public init(code: UInt16, flags: CGEventFlags) {
        self.code = code
        self.flags = flags
    }
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
    /// types, a letter's case aside, as Caps Lock types it; none with Shift, ⌘, ⌃, ⌥ or Fn held, which make it another
    /// key. An arrow's own flags, Fn and the keypad's, are no modifier.
    var panelKey: PanelKey? {
        guard flags.isDisjoint(with: Self.modifiers), !holdsFn else {
            return nil
        }

        return Self.byCode[code] ?? Self.byTyping[typed.lowercased()]
    }

    /// Whether it is a chord for the window in front: ⌘, ⌃, ⌥ or Fn held with it, or a function key, which is one
    /// alone. Shift alone types.
    var isChord: Bool {
        !flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate]) || holdsFn
            || KeyCode.functionKeys.contains(code)
    }

    /// Whether it is this chord: its key, and these modifiers held with it, and no others, Caps Lock and Fn aside.
    func isChord(_ chord: TapChord) -> Bool {
        code == chord.code && flags.intersection(Self.modifiers) == chord.flags
    }

    /// Fn held with a key that doesn't carry it of itself, as the arrows and the keys over them do, and that isn't read
    /// by its code: fn-Return on a laptop's keyboard sends keypad Enter with Fn, and is Return still.
    private var holdsFn: Bool {
        flags.contains(.maskSecondaryFn) && !KeyCode.carriesFn.contains(code) && Self.byCode[code] == nil
    }

    /// The key of the panel's set it is, `⌘Z` among them where the panel `undoes`: ⌘ alone held with the key that
    /// types z, Caps Lock aside.
    func panelKey(undoes: Bool) -> PanelKey? {
        let isUndo = flags.intersection(Self.modifiers) == .maskCommand && typed.lowercased() == "z"

        return undoes && isUndo ? .undo : panelKey
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
    /// The panel holds them, in its hold of this number: every key of the set is its, and `⌘Z` too where it `undoes`,
    /// as the asks panel does while its sending line shows and through the beat after it goes; any other ends the
    /// hold. But where it `takesAll`, as the shortcut's hold does, any other is taken too, doing nothing, and only a
    /// chord ends it, going through. The shortcut's `hotKey` goes through and ends nothing, for macOS to hand SitRep,
    /// so it alone acts on it.
    case panel(hold: Int, undoes: Bool = false, takesAll: Bool = false, hotKey: TapChord? = nil)
    /// One of the notch's menus is open: a snooze menu shown on its own, of this many choices, whose digits, `z`, `k`
    /// and `j` the tap takes; or, with none, the row's menu, which keeps AppKit's keys alone.
    case menu(choices: Int?)
}

/// What a key the tap takes, or lets go by, does, handed to the main thread.
public enum KeyAction: Equatable, Sendable {
    /// A key of the set while the panel holds the keys; where it `ends` the hold of this number, as `o` and `⏎` do, the
    /// panel follows, holding none after it, as the tap does from it on. `again` as a held key repeats.
    case panel(PanelKey, ends: Int? = nil, again: Bool = false)
    /// A key the panel doesn't take, in the hold of this number: the panel holds none until the pointer moves again,
    /// or, the shortcut's hold, closes.
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
/// here at once, as `o` and `⏎` do, which jump, so the keys typed after them go through though the main thread has yet
/// to hear of it, the action handed on saying so for the panel to follow; but for either while `⌘Z` is the panel's,
/// where it can't jump, which leaves the hold its `⌘Z`. `⏎` in a menu is AppKit's, which the menu's snapshot keeps.
/// The shortcut's hold takes every key pressed alone, so only a chord ends it. The shortcut's own chord goes through,
/// ending nothing, whatever holds the keys.
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

    /// Whether a key it took or rewrote has yet to come up.
    var hasKeysDown: Bool { !down.isEmpty }

    /// The keys it took or rewrote forgotten: their repeats and key-ups go through from now.
    mutating func forgetKeysDown() {
        down = [:]
    }

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
            .take(key.panelKey.flatMap { $0.repeats && holds(snapshot) ? .panel($0, again: true) : nil })
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
        case let .panel(hold, undoes, takesAll, hotKey):
            guard hold != ended, !(hotKey.map(key.isChord) ?? false) else {
                return .pass
            }
            guard let panelKey = key.panelKey(undoes: undoes) else {
                if takesAll, !key.isChord {
                    return .take(nil)
                }
                ended = hold
                return .letGo(hold: hold)
            }
            guard panelKey.jumps, !undoes else {
                return .take(.panel(panelKey))
            }

            ended = hold
            return .take(.panel(panelKey, ends: hold))
        }
    }

    private func holds(_ snapshot: KeySnapshot) -> Bool {
        guard case let .panel(hold, _, _, _) = snapshot else {
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

extension KeySnapshot {
    /// The same, the panel's hold passing the shortcut's chord, `hotKey`, through.
    public func passing(_ hotKey: TapChord?) -> KeySnapshot {
        guard case let .panel(hold, undoes, takesAll, _) = self else {
            return self
        }

        return .panel(hold: hold, undoes: undoes, takesAll: takesAll, hotKey: hotKey)
    }
}
