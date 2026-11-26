import AppKit
import Carbon.HIToolbox
@testable import SitRep
import SitRepCore
import SitRepEdge
import SitRepMenu
import SitRepPanel
import SitRepTestSupport
import Testing

/// The shortcut's hot key (DESIGN, "Keys"): registered from the shortcut Lee set as SitRep starts, again as he changes
/// it, none while he has cleared it or while Settings records another. No hot key is real here: Carbon is the test's.
@MainActor
@Suite(.backstop)
struct HotKeyTests {
    /// Carbon as the test keeps it: what it holds, and each call made.
    final class CarbonDouble: HotKeyCarbon {
        private(set) var held: KeyChord?
        private(set) var calls: [String] = []
        var refuses = false

        func register(_ chord: KeyChord) -> Bool {
            calls.append("register \(chord.code)")
            held = refuses ? nil : chord
            return !refuses
        }

        func unregister() {
            calls.append("unregister")
            held = nil
        }
    }

    private static let commandK = KeyChord(code: 40, modifiers: .command)

    @Test func itIsRegisteredAsSitRepStarts() {
        let carbon = CarbonDouble(), hotKey = HotKey(carbon, chord: .controlOptionS)

        #expect(carbon.held == .controlOptionS && hotKey.registered == .controlOptionS)
        #expect(carbon.calls == ["register 1"])
    }

    @Test func aShortcutSetReplacesTheOneRegistered() {
        let carbon = CarbonDouble(), hotKey = HotKey(carbon, chord: .controlOptionS)

        hotKey.chord = Self.commandK
        #expect(carbon.held == Self.commandK)
        #expect(carbon.calls == ["register 1", "unregister", "register 40"])
        hotKey.chord = Self.commandK
        #expect(carbon.calls.count == 3)
    }

    /// Cleared, none is registered; cleared at start, none ever was.
    @Test func clearedNoneIsRegistered() {
        let carbon = CarbonDouble(), hotKey = HotKey(carbon, chord: .controlOptionS)

        hotKey.chord = nil
        #expect(carbon.held == nil && hotKey.registered == nil)
        #expect(HotKey(CarbonDouble(), chord: nil).registered == nil)
    }

    /// While Settings records, none is registered, so the shortcut set records rather than opening the panel; the one
    /// set is registered again as it stops.
    @Test func whileSettingsRecordsNoneIsRegistered() {
        let carbon = CarbonDouble(), hotKey = HotKey(carbon, chord: .controlOptionS)

        hotKey.isSuspended = true
        #expect(carbon.held == nil)
        hotKey.chord = Self.commandK
        #expect(carbon.held == nil)
        hotKey.isSuspended = false
        #expect(carbon.held == Self.commandK)
    }

    /// One macOS refuses is not held, and is tried again at the next change.
    @Test func oneMacOSRefusesIsNotHeld() {
        let carbon = CarbonDouble()

        carbon.refuses = true

        let hotKey = HotKey(carbon, chord: .controlOptionS)

        #expect(hotKey.registered == nil && hotKey.isRefused)
        carbon.refuses = false
        hotKey.chord = Self.commandK
        #expect(hotKey.registered == Self.commandK && carbon.calls == ["register 1", "register 40"])
        #expect(!hotKey.isRefused)
    }

    /// What macOS holds is told as it changes, for the notch's tap to let the chord through.
    @Test func whatMacOSHoldsIsToldAsItChanges() {
        let hotKey = HotKey(CarbonDouble(), chord: .controlOptionS)
        var told: [KeyChord?] = []

        hotKey.onRegistered = { told.append($0) }
        hotKey.chord = Self.commandK
        hotKey.isSuspended = true
        hotKey.isSuspended = false
        hotKey.chord = Self.commandK
        #expect(told == [Self.commandK, nil, Self.commandK])
    }

    /// The bits Carbon takes are Carbon's own.
    @Test func theModifiersAreCarbons() {
        #expect(ChordModifiers.command.rawValue == UInt32(cmdKey) && ChordModifiers.shift.rawValue == UInt32(shiftKey))
        #expect(ChordModifiers.option.rawValue == UInt32(optionKey))
        #expect(ChordModifiers.control.rawValue == UInt32(controlKey))
        #expect(KeyChord.controlOptionS.code == UInt16(kVK_ANSI_S) && KeyChord.escape == UInt16(kVK_Escape))
    }

    /// AppKit's modifiers read as Carbon's bits, a key as its code and those.
    @Test func appKitsModifiersReadAsCarbons() {
        #expect(ChordModifiers([.command, .shift, .capsLock, .function]) == [.command, .shift])
        #expect(ChordModifiers([.control, .option]) == [.control, .option])
    }
}

/// What the shortcut opens, as SitRep routes it: the notch's panel while the notch shows, which is only at Notch with
/// no full-screen app on its display; else the menu bar item's menu.
@MainActor
@Suite(.backstop)
struct ShortcutOpensTests {
    @Test(arguments: [
        (EdgeSettings.Show.notch, false, false), (.notch, true, true), (.nothing, false, true), (.nothing, true, true),
    ])
    func theMenuOpensUnlessTheNotchShows(show: EdgeSettings.Show, underFullScreen: Bool, opensMenu: Bool) {
        let notch = NotchController(
            EdgeSettings(), on: NotchAsksWindowTests.display, folding: Folding(), keys: KeysWorld().mac
        ) { SnoozeSettings() }
        var menus = 0

        defer { notch.window.close() }
        notch.isShown = Edge.showsNotch(show, underFullScreen: underFullScreen)
        Shortcut.press(notch: notch.summon, menu: { menus += 1 })
        #expect(menus == (opensMenu ? 1 : 0))
        #expect(notch.run.isOut == !opensMenu)
    }
}

/// The recorder's field as it records: first responder, it records, letting the hot key go; it lets go as it resigns,
/// as its window goes to the back, as it leaves its window, or at a click off it, the hot key registered again; and it
/// is out of the key-view loop, so Tab never starts it.
@MainActor
@Suite(.backstop)
struct ShortcutFieldTests {
    private static func recording() -> (ShortcutFieldView, NSWindow, () -> [Bool]) {
        var suspended: [Bool] = []
        var services = Hosted.services()

        services.suspendShortcut = { suspended.append($0) }

        let settings = SettingsModel(preferences: Preferences(MemoryDefaults()), live: LiveBoard(), services: services)
        let field = ShortcutFieldView(), window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 300, height: 100), styleMask: [.titled], backing: .buffered,
            defer: true
        )

        window.isReleasedWhenClosed = false
        field.actions = ShortcutFieldView.Actions(settings)
        field.frame = CGRect(x: 10, y: 10, width: ShortcutFieldView.width, height: 22)
        window.contentView?.addSubview(field)
        window.makeFirstResponder(field)
        return (field, window, { suspended })
    }

    @Test func resigningItLetsGo() {
        let (_, window, suspended) = Self.recording()

        defer { window.close() }
        #expect(suspended() == [true])
        window.makeFirstResponder(nil)
        #expect(suspended() == [true, false])
    }

    @Test func itsWindowGoingToTheBackLetsGo() {
        let (_, window, suspended) = Self.recording()

        defer { window.close() }
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: window)
        #expect(suspended() == [true, false])
    }

    @Test func leavingItsWindowLetsGo() {
        let (field, window, suspended) = Self.recording()

        defer { window.close() }
        field.removeFromSuperview()
        #expect(suspended() == [true, false])
    }

    /// A click off it, as on a switch, which takes no focus, lets go; one on it records on.
    @Test func aClickOffItLetsGo() {
        let (field, window, suspended) = Self.recording()

        defer { window.close() }
        field.clicked(at: CGPoint(x: 20, y: 20), in: window)
        #expect(suspended() == [true])
        field.clicked(at: CGPoint(x: 250, y: 80), in: window)
        #expect(suspended() == [true, false])
    }

    @Test func itIsOutOfTheKeyViewLoop() {
        #expect(!ShortcutFieldView().canBecomeKeyView)
    }
}

/// Settings' Shortcut recorder as the window keeps it: a click records, letting the hot key go; a key it takes saved,
/// and the hot key registered again; one refused leaving it recording; `esc` cancelling; the clear button saving none.
@MainActor
@Suite(.backstop)
struct ShortcutSettingsTests {
    private static let commandK = KeyChord(code: 40, modifiers: .command)

    /// Settings over a Mac whose hot key's suspensions are kept in `suspended`, its shortcut saved in `defaults`.
    private static func settings(
        _ defaults: UserDefaults = MemoryDefaults(), suspended: @escaping (Bool) -> Void
    ) -> SettingsModel {
        var services = Hosted.services()

        services.suspendShortcut = suspended
        return SettingsModel(preferences: Preferences(defaults), live: LiveBoard(), services: services)
    }

    @Test func recordingLetsTheHotKeyGoAndTakingAKeySavesIt() {
        let defaults = MemoryDefaults()
        var suspended: [Bool] = []
        let settings = Self.settings(defaults) { suspended.append($0) }

        settings.recordShortcut()
        #expect(suspended == [true])
        #expect(settings.pressForShortcut(Self.commandK) == false)
        #expect(suspended == [true, false])
        #expect(SavedSettings<AppSettings>(defaults).read().shortcut == Shortcut(Self.commandK))
    }

    /// The hot key is told of the new shortcut before it is registered again, so the one registered is the new one.
    @Test func theNewShortcutIsToldBeforeTheHotKeyIsRegisteredAgain() {
        var told: [String] = []
        let settings = Self.settings { told.append("suspended \($0)") }

        settings.preferences.onShortcut = { told.append("chord \($0?.code ?? 0)") }
        settings.recordShortcut()
        _ = settings.pressForShortcut(Self.commandK)
        #expect(told == ["suspended true", "chord 40", "suspended false"])
    }

    @Test func aKeyRefusedLeavesItRecordingSayingWhy() {
        var suspended: [Bool] = []
        let settings = Self.settings { suspended.append($0) }

        settings.recordShortcut()
        #expect(settings.pressForShortcut(KeyChord(code: 0, modifiers: .option)) == true)
        #expect(settings.recorder.isRecording && settings.recorder.line(.notch) == "Use ⌘ or ⌃")
        #expect(suspended == [true])
        #expect(settings.preferences.app.shortcut == .standard)
    }

    @Test func escOrAClickAwayCancelsKeepingTheShortcut() {
        var suspended: [Bool] = []
        let settings = Self.settings { suspended.append($0) }

        settings.recordShortcut()
        #expect(settings.pressForShortcut(KeyChord(code: KeyChord.escape, modifiers: [])) == false)
        settings.recordShortcut()
        settings.cancelShortcut()
        #expect(suspended == [true, false, true, false])
        #expect(settings.preferences.app.shortcut == .standard)
    }

    /// macOS refusing the shortcut set, the row's line says so as recording stops, and as the pane comes into sight.
    @Test func macOSRefusingTheShortcutIsRead() async {
        var refuses = false
        var services = Hosted.services()

        services.shortcutRefused = { refuses }

        let settings = SettingsModel(preferences: Preferences(MemoryDefaults()), live: LiveBoard(), services: services)

        settings.recordShortcut()
        refuses = true
        _ = settings.pressForShortcut(Self.commandK)
        #expect(settings.macOSRefusesShortcut)
        refuses = false
        await settings.read()
        #expect(!settings.macOSRefusesShortcut)
    }

    @Test func theClearButtonSavesNone() {
        let defaults = MemoryDefaults()
        var chords: [KeyChord?] = []
        let settings = Self.settings(defaults) { _ in }

        settings.preferences.onShortcut = { chords.append($0) }
        settings.clearShortcut()
        #expect(chords == [nil])
        #expect(SavedSettings<AppSettings>(defaults).read().shortcut == .cleared)
    }
}
