import CoreGraphics
import SitRepEdge
import SitRepTestSupport
import Testing

/// How the tap decides each key (DESIGN, "Keys"): while the panel holds the keys every key of the set is taken, matched
/// by what it types on the layout, the arrows, Return, keypad Enter and Esc by their codes, and pressed alone; any
/// other goes through and ends the hold, as `o` and `⏎` end it as they are taken, but while `⌘Z` is the panel's; a key
/// taken is taken whole, its repeats acting again only for the arrows and `k` `j`, its key-up going nowhere; in a
/// snooze menu on its own, digits choose, `z` closes and `k` `j` go on as arrows; `⌘Z` is the one key taken with a
/// modifier, while the asks panel's sending line shows; with nothing holding, or the row's menu open, every key goes
/// through.
@Suite(.backstop)
struct KeyReaderTests {
    private static let holding = KeySnapshot.panel(hold: 1)

    /// A key typing `typed`, at QWERTY's code for it where it has one.
    private static func typing(
        _ typed: String, _ flags: CGEventFlags = [], _ stroke: TapKey.Stroke = .down
    ) -> TapKey {
        TapKey(code: qwerty[typed.lowercased()] ?? 0x32, typed: typed, flags: flags, stroke: stroke)
    }

    /// An arrow, Return, Enter or Esc, with what it types, an arrow its Fn and keypad flags.
    private static func code(_ code: UInt16, _ stroke: TapKey.Stroke = .down, flags: CGEventFlags = []) -> TapKey {
        let arrows = [KeyCode.up, KeyCode.down, KeyCode.left, KeyCode.right]
        let own: CGEventFlags = arrows.contains(code) ? [.maskSecondaryFn, .maskNumericPad] : []

        return TapKey(code: code, typed: "\u{1E}", flags: own.union(flags), stroke: stroke)
    }

    /// The key that jumps, `o` or Return.
    private static func jumping(_ key: PanelKey) -> TapKey {
        key == .open ? typing("o") : code(KeyCode.enter)
    }

    private static let qwerty: [String: UInt16] = [
        "k": 40, "j": 38, "o": 31, "z": 6, "s": 1, "x": 7, "a": 0, "t": 17, "0": 29,
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
    ]

    // MARK: The panel's keys

    @Test(arguments: [
        ("k", PanelKey.up), ("j", .down), ("z", .snooze), ("s", .fold), ("x", .ignore),
        ("1", .digit(1)), ("5", .digit(5)), ("9", .digit(9)),
    ])
    func eachLetterAndDigitOfTheSetIsTakenWhileThePanelHoldsTheKeys(_ typed: String, _ key: PanelKey) {
        var reader = KeyReader()

        #expect(reader.read(Self.typing(typed), in: Self.holding) == .take(.panel(key)))
    }

    /// `←` and `→` are read as they are, whichever edge the notch is on: the run tells out from back.
    @Test(arguments: [
        (KeyCode.up, KeyAction.panel(.up)), (KeyCode.down, .panel(.down)), (KeyCode.left, .panel(.left)),
        (KeyCode.right, .panel(.right)), (KeyCode.enter, .panel(.enter, ends: 1)),
        (KeyCode.keypadEnter, .panel(.enter, ends: 1)), (KeyCode.escape, .panel(.escape)),
    ])
    func theArrowsReturnEnterAndEscAreReadByTheirCodes(_ code: UInt16, _ action: KeyAction) {
        var reader = KeyReader()

        #expect(reader.read(Self.code(code), in: Self.holding) == .take(action))
    }

    /// On another layout a key is what it types: `k` where QWERTY has `t`, and QWERTY's `k` typing `t`.
    @Test func aKeyIsWhatItTypesOnTheLayoutNotWhereItSits() {
        var reader = KeyReader()

        #expect(reader.read(TapKey(code: 17, typed: "k"), in: Self.holding) == .take(.panel(.up)))
        #expect(reader.read(TapKey(code: 40, typed: "t"), in: Self.holding) == .letGo(hold: 1))
    }

    /// Caps Lock types an upper case letter, which is the same key.
    @Test func capsLockLeavesALetterTheSameKey() {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("Z", .maskAlphaShift), in: Self.holding) == .take(.panel(.snooze)))
    }

    @Test(arguments: [CGEventFlags.maskShift, .maskCommand, .maskControl, .maskAlternate])
    func aModifierHeldMakesItAnotherKeyWhichGoesThroughAndLetsGo(_ modifier: CGEventFlags) {
        var letter = KeyReader(), arrow = KeyReader()

        #expect(letter.read(Self.typing("z", modifier), in: Self.holding) == .letGo(hold: 1))
        #expect(arrow.read(Self.code(KeyCode.down, flags: modifier), in: Self.holding) == .letGo(hold: 1))
    }

    @Test(arguments: ["a", "0"])
    func aKeyOutsideTheSetGoesThroughAndLetsGo(_ typed: String) {
        var reader = KeyReader()

        #expect(reader.read(Self.typing(typed), in: Self.holding) == .letGo(hold: 1))
    }

    /// Typing into the window in front with the pointer left on the panel goes on there from its first key the panel
    /// doesn't take, though the main thread has yet to hear of it: `o` after `h` is no jump.
    @Test func afterAKeyLetsGoTheKeysOfThatHoldGoThroughAndTheNextHoldTakesThem() {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("a"), in: Self.holding) == .letGo(hold: 1))
        #expect(reader.read(Self.typing("o"), in: Self.holding) == .pass)
        #expect(reader.read(Self.typing("a"), in: Self.holding) == .pass)
        #expect(reader.read(Self.typing("o"), in: .panel(hold: 2)) == .take(.panel(.open, ends: 2)))
    }

    /// `o` and `⏎` end their hold as they are taken, under either hold: they jump, so a key typed after one, before the
    /// main thread has heard of it, goes to the window jumped to. What it hands on says which hold it ended, for the
    /// panel to follow.
    @Test(arguments: [PanelKey.open, .enter], [false, true])
    func oAndReturnEndTheirHoldAsTheyAreTaken(_ panelKey: PanelKey, takesAll: Bool) {
        let key = Self.jumping(panelKey)
        var reader = KeyReader(), lifted = key

        lifted.stroke = .up
        #expect(reader.read(key, in: .panel(hold: 1, takesAll: takesAll)) == .take(.panel(panelKey, ends: 1)))
        #expect(reader.read(Self.typing("k"), in: .panel(hold: 1, takesAll: takesAll)) == .pass)
        #expect(reader.read(lifted, in: .panel(hold: 1, takesAll: takesAll)) == .take(nil))
        #expect(reader.read(key, in: .panel(hold: 2, takesAll: takesAll)) == .take(.panel(panelKey, ends: 2)))
    }

    @Test(arguments: [KeySnapshot.none, .menu(choices: nil)])
    func withNothingHoldingOrTheRowsMenuEveryKeyGoesThrough(_ snapshot: KeySnapshot) {
        var reader = KeyReader()
        let keys = ["k", "z", "1", "a"].map { Self.typing($0) } + [Self.code(KeyCode.escape), Self.code(KeyCode.down)]

        for key in keys {
            #expect(reader.read(key, in: snapshot) == .pass)
            #expect(reader.read(TapKey(code: key.code, typed: key.typed, stroke: .up), in: snapshot) == .pass)
        }
    }

    // MARK: Repeats and key-ups

    @Test(arguments: [
        (Self.typing("k"), PanelKey.up), (Self.typing("j"), .down), (Self.code(KeyCode.up), .up),
        (Self.code(KeyCode.down), .down), (Self.code(KeyCode.left), .left), (Self.code(KeyCode.right), .right),
    ])
    func aHeldArrowOrKOrJActsAgainAsItRepeats(_ key: TapKey, _ panelKey: PanelKey) {
        var reader = KeyReader(), held = key

        #expect(reader.read(key, in: Self.holding) == .take(.panel(panelKey)))
        held.stroke = .again
        #expect(reader.read(held, in: Self.holding) == .take(.panel(panelKey)))
        #expect(reader.read(held, in: Self.holding) == .take(.panel(panelKey)))
    }

    @Test(arguments: [Self.typing("z"), Self.typing("1"), Self.typing("o"), Self.code(KeyCode.enter)])
    func anyOtherTakenKeysRepeatsAreDropped(_ key: TapKey) {
        var reader = KeyReader(), held = key

        #expect(reader.read(key, in: Self.holding) != .pass)
        held.stroke = .again
        #expect(reader.read(held, in: Self.holding) == .take(nil))
    }

    /// A key taken is taken whole: its key-up goes nowhere, though the hold ended since, as `esc` closing the panel
    /// ends it; a key that went through comes up through, though a hold began since.
    @Test func aTakenKeysKeyUpGoesNowhereAndAKeyThatWentThroughComesUpThrough() {
        var reader = KeyReader()

        #expect(reader.read(Self.code(KeyCode.escape), in: Self.holding) == .take(.panel(.escape)))
        #expect(reader.read(Self.code(KeyCode.escape, .up), in: .none) == .take(nil))
        #expect(reader.read(Self.code(KeyCode.escape, .up), in: .none) == .pass)

        #expect(reader.read(Self.typing("o"), in: .none) == .pass)
        #expect(reader.read(Self.typing("o", [], .up), in: Self.holding) == .pass)
    }

    /// A held arrow whose hold ended, as the pointer moved off, repeats into nothing; a key that went through repeats
    /// through though a hold began.
    @Test func aRepeatFollowsHowItsKeyWentDown() {
        var reader = KeyReader()

        #expect(reader.read(Self.code(KeyCode.down), in: Self.holding) == .take(.panel(.down)))
        #expect(reader.read(Self.code(KeyCode.down, .again), in: .none) == .take(nil))

        #expect(reader.read(Self.typing("j"), in: .none) == .pass)
        #expect(reader.read(Self.typing("j", [], .again), in: Self.holding) == .pass)
    }

    // MARK: ⌘Z

    private static let undoing = KeySnapshot.panel(hold: 1, undoes: true)

    /// `⌘Z` is the one key the panel takes with a modifier, only while the asks panel's sending line shows, Caps Lock
    /// or none: its Undo.
    @Test(arguments: ["z", "Z"])
    func commandZIsTheSendingLinesUndoWhileItShows(_ typed: String) {
        var reader = KeyReader()
        let flags: CGEventFlags = typed == "Z" ? [.maskCommand, .maskAlphaShift] : .maskCommand

        #expect(reader.read(Self.typing(typed, flags), in: Self.undoing) == .take(.panel(.undo)))
    }

    /// With no sending line, `⌘Z` is another key: it goes through, to the window in front, and lets go.
    @Test func withNoSendingLineCommandZGoesThroughAndLetsGo() {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("z", .maskCommand), in: Self.holding) == .letGo(hold: 1))
    }

    /// Only ⌘ alone makes `z` Undo: Shift, ⌃ or ⌥ with it make another key, which goes through and lets go.
    @Test(arguments: [CGEventFlags.maskShift, .maskControl, .maskAlternate])
    func anotherModifierWithCommandZMakesItAnotherKey(_ modifier: CGEventFlags) {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("z", [.maskCommand, modifier]), in: Self.undoing) == .letGo(hold: 1))
    }

    /// The sending line showing takes nothing else with ⌘: `⌘1` and `⌘X` go through and let go; `z` alone is still
    /// Snooze.
    @Test func whileItShowsNoOtherKeyWithCommandIsThePanels() {
        var command = KeyReader(), plain = KeyReader()

        #expect(command.read(Self.typing("1", .maskCommand), in: Self.undoing) == .letGo(hold: 1))
        #expect(plain.read(Self.typing("z"), in: Self.undoing) == .take(.panel(.snooze)))
    }

    /// Taken whole: held, its repeats are dropped, so a held `⌘Z` undoes once, and its key-up goes nowhere.
    @Test func aHeldCommandZUndoesOnce() {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("z", .maskCommand), in: Self.undoing) == .take(.panel(.undo)))
        #expect(reader.read(Self.typing("z", .maskCommand, .again), in: Self.undoing) == .take(nil))
        #expect(reader.read(Self.typing("z", .maskCommand, .up), in: Self.holding) == .take(nil))
    }

    /// `o` or `⏎` while `⌘Z` is the panel's can't jump: it keeps the hold, either hold, ending none as it is handed on,
    /// so the `⌘Z` after it is still the panel's.
    @Test(arguments: [PanelKey.open, .enter], [false, true])
    func oOrReturnWhileTheSendingLineShowsKeepsTheHold(_ panelKey: PanelKey, takesAll: Bool) {
        var reader = KeyReader()
        let undoing = KeySnapshot.panel(hold: 1, undoes: true, takesAll: takesAll)

        #expect(reader.read(Self.jumping(panelKey), in: undoing) == .take(.panel(panelKey)))
        #expect(reader.read(Self.typing("z", .maskCommand), in: undoing) == .take(.panel(.undo)))
    }

    // MARK: The shortcut's hold

    private static let summoned = KeySnapshot.panel(hold: 1, takesAll: true)

    /// The shortcut's hold takes every key pressed alone: a key of the set acts as under a hover's hold, and any other,
    /// Shift's among them, is taken and does nothing, where a hover's hold lets it through.
    @Test func theShortcutsHoldTakesAKeyOutsideTheSetAndDoesNothingWithIt() {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("k"), in: Self.summoned) == .take(.panel(.up)))
        #expect(reader.read(Self.typing("a"), in: Self.summoned) == .take(nil))
        #expect(reader.read(Self.typing("0"), in: Self.summoned) == .take(nil))
        #expect(reader.read(Self.typing("A", .maskShift), in: Self.summoned) == .take(nil))
        #expect(reader.read(Self.code(KeyCode.down, flags: .maskShift), in: Self.summoned) == .take(nil))
        #expect(reader.read(Self.typing("z"), in: Self.summoned) == .take(.panel(.snooze)))
    }

    /// Taken whole, as any key taken: its repeats and its key-up go nowhere.
    @Test func aKeyTheShortcutsHoldTakesIsTakenWhole() {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("a"), in: Self.summoned) == .take(nil))
        #expect(reader.read(Self.typing("a", [], .again), in: Self.summoned) == .take(nil))
        #expect(reader.read(Self.typing("a", [], .up), in: .none) == .take(nil))
    }

    /// A key with ⌘, ⌃ or ⌥ goes through and ends the hold, which closes the panel; the keys after it go through too,
    /// though the main thread has yet to hear of it.
    @Test(arguments: [CGEventFlags.maskCommand, .maskControl, .maskAlternate, [.maskCommand, .maskShift]])
    func aKeyWithCommandControlOrOptionGoesThroughAndEndsTheShortcutsHold(_ modifier: CGEventFlags) {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("t", modifier), in: Self.summoned) == .letGo(hold: 1))
        #expect(reader.read(Self.typing("a"), in: Self.summoned) == .pass)
        #expect(reader.read(Self.typing("k"), in: Self.summoned) == .pass)
    }

    /// A key with Fn, the Globe key, is a chord, but for the keys that carry Fn of themselves, the arrows and those
    /// over them; and a function key is one alone: each goes through and ends the hold.
    @Test func fnChordsAndFunctionKeysEndTheShortcutsHoldAndTheArrowsCarryFn() {
        var reader = KeyReader(), function = KeyReader(), arrow = KeyReader()

        #expect(reader.read(Self.typing("e", .maskSecondaryFn), in: Self.summoned) == .letGo(hold: 1))
        #expect(function.read(TapKey(code: 96, flags: .maskSecondaryFn), in: Self.summoned) == .letGo(hold: 1))
        #expect(arrow.read(Self.code(KeyCode.right), in: Self.summoned) == .take(.panel(.right)))
        #expect(arrow.read(TapKey(code: 115, flags: .maskSecondaryFn), in: Self.summoned) == .take(nil))
    }

    /// A key read by its code is itself with Fn held: fn-Return on a laptop's keyboard sends keypad Enter with Fn, and
    /// goes under either hold, ending it, as `esc` with Fn closes.
    @Test(arguments: [KeyCode.keypadEnter, KeyCode.enter, KeyCode.escape], [Self.holding, Self.summoned])
    func aKeyReadByItsCodeIsItselfWithFnHeld(code: UInt16, snapshot: KeySnapshot) {
        var reader = KeyReader()

        #expect(
            reader.read(TapKey(code: code, flags: .maskSecondaryFn), in: snapshot)
                == .take(code == KeyCode.escape ? .panel(.escape) : .panel(.enter, ends: 1))
        )
    }

    /// Fn held makes a letter another key under a hover's hold too.
    @Test func fnHeldMakesALetterAnotherKey() {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("z", .maskSecondaryFn), in: Self.holding) == .letGo(hold: 1))
    }

    /// The shortcut's own chord goes through, ending no hold, so macOS hands it to SitRep and the hot key alone acts on
    /// it; the keys after it are the hold's still.
    @Test(arguments: [true, false])
    func theShortcutsChordGoesThroughEndingNoHold(takesAll: Bool) {
        var reader = KeyReader()
        let hotKey = TapChord(code: 1, flags: [.maskControl, .maskAlternate])
        let snapshot = KeySnapshot.panel(hold: 1, takesAll: takesAll).passing(hotKey)

        #expect(reader.read(Self.typing("s", [.maskControl, .maskAlternate]), in: snapshot) == .pass)
        #expect(reader.read(Self.typing("s", [.maskControl, .maskAlternate], .up), in: snapshot) == .pass)
        #expect(reader.read(Self.typing("k"), in: snapshot) == .take(.panel(.up)))
        #expect(
            reader.read(Self.typing("s", [.maskControl, .maskAlternate, .maskShift]), in: snapshot) == .letGo(hold: 1)
        )
    }

    /// `⌘Z` while an answer is sending is the panel's in the shortcut's hold too.
    @Test func commandZWhileSendingIsThePanelsInTheShortcutsHold() {
        var reader = KeyReader()

        #expect(
            reader.read(Self.typing("z", .maskCommand), in: .panel(hold: 1, undoes: true, takesAll: true))
                == .take(.panel(.undo))
        )
    }

    // MARK: A snooze menu on its own

    @Test func inASnoozeMenuItsDigitsChooseUpToItsLastAndPastItDoNothing() {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("1"), in: .menu(choices: 4)) == .take(.choose(1)))
        #expect(reader.read(Self.typing("4"), in: .menu(choices: 4)) == .take(.choose(4)))
        #expect(reader.read(Self.typing("5"), in: .menu(choices: 4)) == .take(nil))
        #expect(reader.read(Self.typing("1", [], .again), in: .menu(choices: 4)) == .take(nil))
        #expect(reader.read(Self.typing("1", [], .up), in: .menu(choices: 4)) == .take(nil))
    }

    @Test func inASnoozeMenuZClosesIt() {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("z"), in: .menu(choices: 4)) == .take(.closeMenu))
        #expect(reader.read(Self.typing("z", [], .up), in: .menu(choices: 4)) == .take(nil))
    }

    /// `k` and `j` go on as `↑` and `↓`, held and lifted alike, though the menu closed before the lift.
    @Test func inASnoozeMenuKAndJGoOnAsTheArrows() {
        var reader = KeyReader()

        #expect(reader.read(Self.typing("k"), in: .menu(choices: 4)) == .rewrite(to: KeyCode.up))
        #expect(reader.read(Self.typing("k", [], .again), in: .menu(choices: 4)) == .rewrite(to: KeyCode.up))
        #expect(reader.read(Self.typing("k", [], .up), in: .none) == .rewrite(to: KeyCode.up))
        #expect(reader.read(Self.typing("j"), in: .menu(choices: 4)) == .rewrite(to: KeyCode.down))
        #expect(reader.read(Self.typing("j", [], .up), in: .menu(choices: 4)) == .rewrite(to: KeyCode.down))
    }

    /// The arrows, Return and Esc are AppKit's own in the menu, as is every other key, a modifier's among them.
    @Test func inASnoozeMenuEveryOtherKeyIsAppKits() {
        var reader = KeyReader()
        let keys = [
            Self.code(KeyCode.up), Self.code(KeyCode.down), Self.code(KeyCode.enter), Self.code(KeyCode.escape),
            Self.typing("o"), Self.typing("s"), Self.typing("1", .maskCommand), Self.typing("k", .maskShift),
        ]

        for key in keys {
            #expect(reader.read(key, in: .menu(choices: 4)) == .pass)
        }
    }

    @Test func theMainThreadIsHandedWhatATakenKeyDoesAndALetGo() {
        #expect(KeyVerdict.take(.panel(.open)).action == .panel(.open))
        #expect(KeyVerdict.letGo(hold: 1).action == .letGo(hold: 1))
        #expect(KeyVerdict.take(nil).action == nil)
        #expect(KeyVerdict.pass.action == nil)
        #expect(KeyVerdict.rewrite(to: KeyCode.up).action == nil)
    }
}
