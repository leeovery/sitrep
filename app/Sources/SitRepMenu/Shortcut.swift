import CoreGraphics
import SitRepEdge
import SitRepPanel

/// The modifiers held with a key, by Carbon's bits for them (`cmdKey`, `shiftKey`, `optionKey`, `controlKey`), as
/// `RegisterEventHotKey` takes them.
public struct ChordModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let command = Self(rawValue: 1 << 8)
    public static let shift = Self(rawValue: 1 << 9)
    public static let option = Self(rawValue: 1 << 11)
    public static let control = Self(rawValue: 1 << 12)
    public static let all: Self = [.command, .shift, .option, .control]

    /// Whether macOS takes it for a hot key and typing never would: ⌘ or ⌃ held. macOS 15 refuses a hot key of ⌥ or
    /// ⌥⇧ alone, and a key with none is typing.
    public var makesAShortcut: Bool { !isDisjoint(with: [.command, .control]) }

    /// In the Mac's glyphs and its order: ⌃⌥⇧⌘.
    public var glyphs: String {
        [(Self.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .filter { contains($0.0) }.map(\.1).joined()
    }
}

/// A hot key: a key by its code, whatever the layout, and the modifiers held with it.
public struct KeyChord: Codable, Hashable, Sendable {
    public var code: UInt16
    public var modifiers: ChordModifiers

    public init(code: UInt16, modifiers: ChordModifiers) {
        self.code = code
        self.modifiers = modifiers
    }

    /// As the notch's tap reads a key.
    public var tapChord: TapChord {
        let flags: [(ChordModifiers, CGEventFlags)] = [
            (.command, .maskCommand), (.shift, .maskShift), (.option, .maskAlternate), (.control, .maskControl),
        ]

        return TapChord(
            code: code, flags: flags.reduce(into: []) { if modifiers.contains($1.0) { $0.insert($1.1) } }
        )
    }

    /// ⌃⌥S, the shortcut until Lee sets another: S's code, `kVK_ANSI_S`.
    public static let controlOptionS = KeyChord(code: 1, modifiers: [.control, .option])

    /// The code of Esc, `kVK_Escape`, which cancels a recording.
    public static let escape: UInt16 = 53

    /// In the Mac's glyphs, as its menus show a key equivalent: the modifiers, then the key, named by `naming` where it
    /// types a character (`keyName`).
    public func glyphs(naming: (UInt16) -> String?) -> String {
        modifiers.glyphs + (Self.keyName(code) ?? naming(code)?.uppercased() ?? "#\(code)")
    }

    /// A key that types no character, by the name the Mac's menus give it, by its code (`kVK_…`): Return, Tab, Space,
    /// Delete, Esc, the function keys, the arrows and the keys over them; nil for a key that types one, which the
    /// layout names.
    public static func keyName(_ code: UInt16) -> String? {
        names[code]
    }

    private static let names: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 76: "⌤", 117: "⌦", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑", 114: "Help",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19",
        90: "F20",
    ]
}

/// The shortcut as Lee set it (DESIGN, "Keys"), saved under "app" as `shortcut`: a chord, ⌃⌥S until he sets another,
/// or none where he cleared it, which is saved as cleared, `{"cleared":true}`, so it never reads back as the default. A
/// value that is neither reads as the default, as every setting is read leniently, as does a chord with neither ⌘ nor
/// ⌃, which would take a key from typing everywhere; modifiers past the four are passed over.
public struct Shortcut: Codable, Equatable, Sendable {
    public var chord: KeyChord?

    public init(_ chord: KeyChord?) {
        self.chord = chord
    }

    public static let byDefault = Shortcut(.controlOptionS)
    public static let cleared = Shortcut(nil)

    public init(from decoder: any Decoder) throws {
        let saved = try decoder.container(keyedBy: CodingKeys.self)

        guard !saved.value(.cleared, or: false) else {
            chord = nil
            return
        }

        var chord = try KeyChord(from: decoder)

        chord.modifiers.formIntersection(.all)
        guard chord.modifiers.makesAShortcut else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "No ⌘ or ⌃"))
        }

        self.chord = chord
    }

    public func encode(to encoder: any Encoder) throws {
        guard let chord else {
            var saved = encoder.container(keyedBy: CodingKeys.self)

            return try saved.encode(true, forKey: .cleared)
        }

        try chord.encode(to: encoder)
    }

    private enum CodingKeys: String, CodingKey {
        case cleared
    }
}

/// Settings' Shortcut recorder (DESIGN, "Keys"), as macOS's Keyboard Shortcuts settings record one: a click starts it
/// recording, the modifiers held showing in its prompt's place as they are pressed; the next key with ⌘ or ⌃ is taken;
/// one with neither is refused, its row's line saying so, and it records on; `esc` alone, or a click away, cancels it.
public struct ShortcutRecorder: Equatable, Sendable {
    public private(set) var isRecording = false
    /// Whether it refused the last key, until it takes one or stops.
    public private(set) var isRefused = false
    /// The modifiers held while it records.
    public private(set) var held: ChordModifiers = []

    public init() {}

    public static let prompt = "Type shortcut"
    public static let none = "Record shortcut"
    public static let refusal = "Use ⌘ or ⌃"
    public static let macOSRefusal = "macOS refused this shortcut; another app may use it"

    /// What its field shows, and whether it is a prompt, in the placeholder's grey: while it records, the modifiers
    /// held, else its prompt; else the shortcut, or with none, what a click does.
    public struct Field: Equatable, Sendable {
        public let text: String
        public let isPrompt: Bool
    }

    public mutating func record() {
        self = ShortcutRecorder()
        isRecording = true
    }

    /// The modifiers held changed while it records.
    public mutating func hold(_ modifiers: ChordModifiers) {
        if isRecording {
            held = modifiers
        }
    }

    /// A key pressed while it records: the chord to save, where it takes it. `esc` alone cancels it; a key with neither
    /// ⌘ nor ⌃ is refused.
    public mutating func press(_ chord: KeyChord) -> KeyChord? {
        guard isRecording else {
            return nil
        }
        guard chord != KeyChord(code: KeyChord.escape, modifiers: []) else {
            stop()
            return nil
        }
        guard chord.modifiers.makesAShortcut else {
            isRefused = true
            return nil
        }

        stop()
        return chord
    }

    public mutating func stop() {
        self = ShortcutRecorder()
    }

    /// Its field, over the shortcut `saved`, each key that types a character named by `naming`.
    public func field(_ saved: KeyChord?, naming: (UInt16) -> String?) -> Field {
        guard !isRecording else {
            return held.isEmpty ? Field(text: Self.prompt, isPrompt: true) : Field(text: held.glyphs, isPrompt: false)
        }

        guard let saved else {
            return Field(text: Self.none, isPrompt: true)
        }

        return Field(text: saved.glyphs(naming: naming), isPrompt: false)
    }

    /// Its row's line: what the shortcut opens, as Show is set; while a refused key stands, why; and while macOS
    /// refuses the shortcut set, as it refuses one another app holds, that, the shortcut still shown.
    public func line(_ show: EdgeSettings.Show, macOSRefuses: Bool = false) -> String {
        guard !isRefused else {
            return Self.refusal
        }
        guard isRecording || !macOSRefuses else {
            return Self.macOSRefusal
        }

        switch show {
        case .notch: return "Opens the notch's panel holding the keys"
        case .nothing: return "Opens the menu bar's menu"
        }
    }
}
