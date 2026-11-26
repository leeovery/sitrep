import Foundation
@testable import SitRepEdge
@testable import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import Testing

/// The shortcut as saved under "app" (DESIGN, "Keys"): ⌃⌥S by default; a chord Lee set read back; a cleared one saved
/// as cleared, so it never comes back as the default; anything else read as the default.
@Suite(.backstop)
struct SavedShortcutTests {
    private static func saved(_ json: String) -> Shortcut {
        let defaults = MemoryDefaults()

        defaults.set(Data(json.utf8), forKey: "app")
        return SavedSettings<AppSettings>(defaults).read().shortcut
    }

    private static func roundTrip(_ shortcut: Shortcut) -> Shortcut {
        let defaults = MemoryDefaults()
        var settings = AppSettings()

        settings.shortcut = shortcut
        SavedSettings(defaults).save(settings)
        return SavedSettings<AppSettings>(defaults).read().shortcut
    }

    @Test func itIsControlOptionSByDefault() {
        #expect(SavedSettings<AppSettings>(MemoryDefaults()).read().shortcut == Shortcut(.controlOptionS))
        #expect(KeyChord.controlOptionS == KeyChord(code: 1, modifiers: [.control, .option]))
        #expect(Self.saved(#"{"notifiesNewAsks":true}"#) == .standard)
    }

    @Test func aChordSetIsReadBack() {
        let commandShiftK = Shortcut(KeyChord(code: 40, modifiers: [.command, .shift]))

        #expect(Self.roundTrip(commandShiftK) == commandShiftK)
        #expect(Self.saved(#"{"shortcut":{"code":40,"modifiers":768}}"#) == commandShiftK)
    }

    /// Cleared, it is saved as cleared, not left out, so it never reads back as the default.
    @Test func aClearedShortcutIsSavedAsClearedAndReadBackSo() throws {
        let defaults = MemoryDefaults()
        var settings = AppSettings()

        settings.shortcut = .cleared
        SavedSettings(defaults).save(settings)

        let saved = try #require(defaults.data(forKey: "app"))
        let json = try #require(try JSONSerialization.jsonObject(with: saved) as? [String: Any])

        #expect(json["shortcut"] as? [String: Bool] == ["cleared": true])
        #expect(SavedSettings<AppSettings>(defaults).read().shortcut.chord == nil)
    }

    @Test(arguments: [
        #"{"shortcut":"⌃⌥S"}"#, #"{"shortcut":{"code":1}}"#, #"{"shortcut":{"cleared":"yes"}}"#,
        #"{"shortcut":{"code":"S","modifiers":6144}}"#, #"{"shortcut":null}"#,
    ])
    func anUnreadableShortcutReadsAsTheDefault(_ json: String) {
        #expect(Self.saved(json) == .standard)
    }
}

/// A chord in the Mac's glyphs, as its menus show a key equivalent: ⌃⌥⇧⌘ in that order, then the key.
@Suite(.backstop)
struct KeyChordTests {
    @Test func theModifiersStandInTheMacsOrder() {
        #expect(ChordModifiers([.command, .shift, .option, .control]).glyphs == "⌃⌥⇧⌘")
        #expect(KeyChord.controlOptionS.glyphs { _ in "s" } == "⌃⌥S")
    }

    /// A key that types no character is named as the menus name it, whatever the layout says.
    @Test(arguments: [
        (UInt16(36), "⌘↩"), (49, "⌘Space"), (122, "⌘F1"), (111, "⌘F12"), (126, "⌘↑"), (53, "⌘⎋"),
    ])
    func aKeyThatTypesNoCharacterIsNamedAsTheMenusNameIt(code: UInt16, glyphs: String) {
        #expect(KeyChord(code: code, modifiers: .command).glyphs { _ in "?" } == glyphs)
    }

    /// Carbon's bits, as `RegisterEventHotKey` takes them.
    @Test func theModifiersAreCarbonsBits() {
        #expect(ChordModifiers.command.rawValue == 0x100 && ChordModifiers.shift.rawValue == 0x200)
        #expect(ChordModifiers.option.rawValue == 0x800 && ChordModifiers.control.rawValue == 0x1000)
    }
}

/// Settings' Shortcut recorder (DESIGN, "Keys"): it shows the shortcut, records from a click, takes the next key with
/// ⌘ or ⌃, refuses one with neither, saying so, and is cancelled by `esc` alone.
@Suite(.backstop)
struct ShortcutRecorderTests {
    private static let naming: @Sendable (UInt16) -> String? = { [1: "s", 40: "k", 0: "a"][$0] }
    private static let commandK = KeyChord(code: 40, modifiers: .command)

    @Test func atRestItShowsTheShortcutOrWhatAClickDoes() {
        let recorder = ShortcutRecorder()

        #expect(recorder.field(.controlOptionS, naming: Self.naming) == .init(text: "⌃⌥S", isPrompt: false))
        #expect(recorder.field(nil, naming: Self.naming) == .init(text: "Record shortcut", isPrompt: true))
    }

    /// Recording, it prompts, and shows the modifiers held as they are pressed.
    @Test func recordingItPromptsAndShowsTheModifiersHeld() {
        var recorder = ShortcutRecorder()

        recorder.record()
        #expect(recorder.isRecording)
        #expect(recorder.field(.controlOptionS, naming: Self.naming) == .init(text: "Type shortcut", isPrompt: true))
        recorder.hold([.control, .shift])
        #expect(recorder.field(.controlOptionS, naming: Self.naming) == .init(text: "⌃⇧", isPrompt: false))
    }

    @Test(arguments: [ChordModifiers.command, .control, [.command, .option], [.control, .shift]])
    func itTakesTheNextKeyWithCommandOrControl(_ modifiers: ChordModifiers) {
        var recorder = ShortcutRecorder()
        let chord = KeyChord(code: 40, modifiers: modifiers)

        recorder.record()
        #expect(recorder.press(chord) == chord)
        #expect(!recorder.isRecording)
    }

    /// A key with neither ⌘ nor ⌃ is refused, the row's line saying why, and it records on.
    @Test(arguments: [ChordModifiers(), .option, [.option, .shift], .shift])
    func itRefusesAKeyWithNeitherCommandNorControl(_ modifiers: ChordModifiers) {
        var recorder = ShortcutRecorder()

        recorder.record()
        #expect(recorder.press(KeyChord(code: 0, modifiers: modifiers)) == nil)
        #expect(recorder.isRecording && recorder.isRefused)
        #expect(recorder.line(.notch) == "Use ⌘ or ⌃")
        #expect(recorder.press(Self.commandK) == Self.commandK)
        #expect(recorder.line(.notch) == "Opens the notch's panel holding the keys")
    }

    /// `esc` alone cancels; with ⌘ or ⌃ it is a shortcut like any other.
    @Test func escAloneCancels() {
        var recorder = ShortcutRecorder()

        recorder.record()
        #expect(recorder.press(KeyChord(code: KeyChord.escape, modifiers: [])) == nil)
        #expect(!recorder.isRecording && !recorder.isRefused)

        let controlEsc = KeyChord(code: KeyChord.escape, modifiers: .control)

        recorder.record()
        #expect(recorder.press(controlEsc) == controlEsc)
    }

    /// Stopped, as a click away stops it, it records nothing more.
    @Test func stoppedItTakesNothing() {
        var recorder = ShortcutRecorder()

        recorder.record()
        recorder.hold(.command)
        recorder.stop()
        #expect(!recorder.isRecording && recorder.held.isEmpty)
        #expect(recorder.press(Self.commandK) == nil)
    }

    @Test func itsLineSaysWhatTheShortcutOpens() {
        let recorder = ShortcutRecorder()

        #expect(recorder.line(.notch) == "Opens the notch's panel holding the keys")
        #expect(recorder.line(.nothing) == "Opens the menu bar's menu")
    }
}
