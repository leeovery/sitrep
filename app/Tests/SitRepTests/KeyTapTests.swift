import CoreGraphics
@testable import SitRep
import SitRepEdge
import SitRepTestSupport
import Testing

/// The tap's shell on Quartz's events (DESIGN, "Keys"), on events made here and posted nowhere, so it needs no leave:
/// a key read as its code, what it types, its modifiers and its stroke; and `k` `j` in a snooze menu going on as the
/// arrow, held and lifted, as an arrow key's own event is.
@Suite(.backstop)
struct KeyTapTests {
    /// QWERTY's `k`, typing `typed`, down or up, repeating or not, with these modifiers, at this time.
    private static func k(
        typed: String = "k", isDown: Bool = true, repeats: Bool = false, flags: CGEventFlags = [], at time: UInt64 = 0
    ) throws -> CGEvent {
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: 40, keyDown: isDown))
        let units = Array(typed.utf16)

        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        event.flags = flags
        event.timestamp = time
        event.setIntegerValueField(.keyboardEventAutorepeat, value: repeats ? 1 : 0)
        return event
    }

    @Test func aKeyIsReadAsItsCodeWhatItTypesItsModifiersAndItsStroke() throws {
        #expect(TapKey(try Self.k(), isDown: true) == TapKey(code: 40, typed: "k", stroke: .down))
        #expect(TapKey(try Self.k(repeats: true), isDown: true).stroke == .again)
        #expect(TapKey(try Self.k(isDown: false), isDown: false).stroke == .up)
        #expect(TapKey(try Self.k(typed: "K", flags: .maskShift), isDown: true).flags.contains(.maskShift))
        #expect(TapKey(try Self.k(typed: "t"), isDown: true).typed == "t")
    }

    /// The arrow in `k`'s place: its code, down or up, the key's modifiers with the Fn and keypad flags an arrow
    /// carries, its repeat and its time.
    @Test(arguments: [true, false])
    func kGoesOnAsTheArrowItStandsFor(isDown: Bool) throws {
        let key = try Self.k(isDown: isDown, repeats: true, flags: .maskAlphaShift, at: 123_456_789)
        let arrow = try #require(KeyTap.arrow(KeyCode.up, for: key, isDown: isDown))

        #expect(arrow.type == (isDown ? .keyDown : .keyUp))
        #expect(arrow.getIntegerValueField(.keyboardEventKeycode) == Int64(KeyCode.up))
        #expect(arrow.flags.isSuperset(of: [.maskAlphaShift, .maskNumericPad, .maskSecondaryFn]))
        #expect(arrow.getIntegerValueField(.keyboardEventAutorepeat) == 1)
        #expect(arrow.timestamp == 123_456_789)
    }
}
