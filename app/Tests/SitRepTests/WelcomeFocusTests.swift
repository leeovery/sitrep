import AppKit
@testable import SitRep
import SitRepMenu
import SitRepTestSupport
import Testing

/// Keyboard focus in the welcome window, made, never shown: on nothing as it opens, the window itself first responder,
/// so nothing shows a ring and Return presses Continue; Tab and Shift-Tab stepping through the controls in reading
/// order, the footer's last. Its buttons take focus only while the Mac's Keyboard navigation setting is on, so what
/// needs them runs only then. SwiftUI's own focus, and Tab from the window itself, only a live run shows
/// (`RecordedWindow`).
@MainActor
@Suite(.backstop)
struct WelcomeFocusTests {
    typealias Made = WelcomeWorld.Made

    /// Where AppKit, as the window orders in and as it keys, gives focus to its first key view, Skip setup at the first
    /// step: focus is on nothing all the same.
    @Test(.keyboardNavigationIsOn, .tags(.thisMac))
    func itOpensWithFocusOnNothing() async {
        let made = Made(focusing: true)

        #expect(made.recorded.firstResponder === made.recorded)
        _ = await made.settled()
        made.recorded.becomeKey()
        #expect(made.recorded.firstResponder === made.recorded)
    }

    /// Sent behind with focus on nothing and keyed again, as by ⌘-Tab, it is on nothing still, wherever AppKit puts it.
    @Test(.keyboardNavigationIsOn, .tags(.thisMac))
    func keyedAgainAfterGoingBehindOnNothingItStaysOnNothing() async {
        let made = Made(focusing: true)

        _ = await made.settled()
        made.recorded.becomeKey()
        made.recorded.resignKey()
        made.recorded.becomeKey()
        #expect(made.recorded.firstResponder === made.recorded)
    }

    /// Sent behind with a control focused and keyed again, focus stays on the control Lee gave it.
    @Test(.keyboardNavigationIsOn, .tags(.thisMac))
    func keyedAgainAfterGoingBehindOnAControlFocusStaysThere() async throws {
        let made = Made(focusing: true)

        _ = await made.settled()
        made.recorded.becomeKey()
        made.recorded.makeFirstResponder(made.recorded.contentView)
        Self.tab(made)

        let focused = try #require(Self.focused(made))

        made.recorded.resignKey()
        made.recorded.becomeKey()
        #expect(made.recorded.firstResponder === focused)
    }

    /// With Keyboard navigation off, AppKit gives no view focus as the window orders in: it is on nothing all the same.
    @Test func itOpensWithFocusOnNothingWhateverKeyboardNavigationSays() {
        let made = Made()

        #expect(made.recorded.firstResponder === made.recorded)
    }

    /// Lee's live path, Tab to Continue then the close button: the next visit, a window of its own, focuses nothing as
    /// it opens and as it keys.
    @Test(.keyboardNavigationIsOn, .tags(.thisMac))
    func tabbedToContinueAndClosedByItsButtonItOpensAgainWithFocusOnNothing() async throws {
        let made = Made(focusing: true)
        let isOnContinue = { Self.frame(made).map { abs($0.maxX - 824) <= 0.5 } == true }

        _ = await made.settled()
        made.recorded.becomeKey()
        made.recorded.makeFirstResponder(made.recorded.contentView)
        for _ in 0 ..< 3 where !isOnContinue() {
            Self.tab(made)
        }
        try #require(isOnContinue())

        let first = made.recorded

        first.performClose(nil)
        made.window.show()
        #expect(made.recorded !== first)
        #expect(made.recorded.firstResponder === made.recorded)
        _ = await made.settled()
        made.recorded.becomeKey()
        #expect(made.recorded.firstResponder === made.recorded)
    }

    /// Show Welcome Window while it shows brings it forward at its first step, a visit under way going on: focus stays
    /// where Lee put it, as it comes forward and as it is keyed again.
    @Test(.keyboardNavigationIsOn, .tags(.thisMac))
    func shownAgainWhileOpenFocusStaysWhereItWas() async throws {
        let made = Made(focusing: true)

        _ = await made.settled()
        made.recorded.becomeKey()
        made.recorded.makeFirstResponder(made.recorded.contentView)
        Self.tab(made)

        let focused = try #require(Self.focused(made))

        made.recorded.resignKey()
        made.window.show()
        #expect(made.recorded.firstResponder === focused)
        made.recorded.becomeKey()
        #expect(made.recorded.firstResponder === focused)
    }

    /// The chevron, dimmed at the first step, takes no focus there.
    @Test(.keyboardNavigationIsOn, .tags(.thisMac))
    func atTheFirstStepTabGoesToSkipSetupThenContinueAndRoundAgain() async throws {
        let made = Made()

        _ = await made.settled()
        let stops = Self.stops(made)

        #expect(stops.count == 2)
        expectEvery(stops) { $0.maxY <= WelcomeStyle.footer }
        #expect(stops.map(\.midX) == stops.map(\.midX).sorted())
        #expect(abs((stops.last?.maxX ?? 0) - 824) <= 0.5)
    }

    /// At a step with no controls of its own, the footer's alone: back, Skip setup and Continue, left to right; Tab past
    /// Continue goes round to back, and Shift-Tab from back to Continue.
    @Test(.keyboardNavigationIsOn, .tags(.thisMac))
    func tabGoesThroughTheFootersControlsInOrderAndShiftTabComesBack() async throws {
        let made = Made()

        made.at(.ask)
        _ = await made.settled()
        let stops = Self.stops(made)

        #expect(stops.count == 3)
        expectEvery(stops) { $0.maxY <= WelcomeStyle.footer }
        #expect(stops.map(\.midX) == stops.map(\.midX).sorted())
        #expect(stops.first?.size == CGSize(width: 28, height: 28))
        #expect(abs((stops.last?.maxX ?? 0) - 824) <= 0.5)

        try #require(Self.frame(made) == stops.first)
        Self.tab(made, back: true)
        #expect(Self.frame(made) == stops.last)
    }

    /// Your edge: the two tiles, the form's rows from the top, Show nothing at the edge, then the footer.
    @Test(.keyboardNavigationIsOn, .tags(.thisMac))
    func tabGoesThroughAStepsControlsInReadingOrderThenTheFooters() async throws {
        let made = Made()

        made.at(.edge)
        _ = await made.settled()
        let stops = Self.stops(made)
        let reading = stops.sorted { ($1.midY, $0.minX) < ($0.midY, $1.minX) }

        #expect(stops.count == 9)
        #expect(stops == reading)
        expectEvery(stops.suffix(3)) { $0.maxY <= WelcomeStyle.footer }
    }

    /// At Nothing, the form's rows take no presses and a line stands in Show nothing at the edge's place: Tab goes from
    /// the tiles to the footer.
    @Test(.keyboardNavigationIsOn, .tags(.thisMac))
    func atNothingTabGoesFromTheTilesToTheFooter() async throws {
        let made = Made()

        made.preferences.edit { $0.show = .nothing }
        made.at(.edge)
        _ = await made.settled()

        let stops = Self.stops(made)

        #expect(stops.count == 5)
        expectEvery(stops.prefix(2)) { $0.maxX < WelcomeStyle.column && $0.minY > WelcomeStyle.footer }
        expectEvery(stops.suffix(3)) { $0.maxY <= WelcomeStyle.footer }
    }

    /// Focus on a tile, and the step it was on gone: AppKit leaves the window itself first responder, on nothing.
    @Test(.keyboardNavigationIsOn, .tags(.thisMac))
    func aStepGoneWithTheControlFocusedLeavesFocusOnNothing() async throws {
        let made = Made()

        made.at(.edge)
        _ = await made.settled()
        made.recorded.makeFirstResponder(made.recorded.contentView)
        Self.tab(made)
        try #require(Self.frame(made).map { $0.maxX < WelcomeStyle.column } == true)
        made.welcome.goOn()
        _ = await made.settled()
        #expect(made.recorded.firstResponder === made.recorded)
    }

    @Test func returnPressesContinueWithFocusOnNothing() async throws {
        let made = Made()

        _ = await made.settled()
        try #require(made.recorded.firstResponder === made.recorded)
        #expect(made.recorded.performKeyEquivalent(with: try #require(Self.key(36, typing: "\r", in: made))))
        #expect(made.welcome.step == .ask)
    }

    // MARK: Helpers

    /// Where Tab stops from the content, in turn, until it comes round again, each in the window's points: from the
    /// content, as a window never keyed for real takes no Tab itself.
    private static func stops(_ made: Made) -> [CGRect] {
        var stops: [CGRect] = []

        made.recorded.makeFirstResponder(made.recorded.contentView)
        while stops.count < 20 {
            tab(made)
            guard let frame = frame(made), !stops.contains(frame) else {
                break
            }
            stops.append(frame)
        }
        return stops
    }

    /// Tab, or Shift-Tab, as the window sends it to what has focus.
    private static func tab(_ made: Made, back: Bool = false) {
        key(48, with: back ? .shift : [], typing: back ? "\u{19}" : "\t", in: made).map(made.recorded.sendEvent)
    }

    private static func key(
        _ code: UInt16, with modifiers: NSEvent.ModifierFlags = [], typing characters: String, in made: Made
    ) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
            windowNumber: made.recorded.windowNumber, context: nil, characters: characters,
            charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code
        )
    }

    /// The control with focus: a view in the content, never the content itself.
    private static func focused(_ made: Made) -> NSView? {
        (made.recorded.firstResponder as? NSView).flatMap { $0 === made.recorded.contentView ? nil : $0 }
    }

    private static func frame(_ made: Made) -> CGRect? {
        focused(made).map { $0.convert($0.bounds, to: nil) }
    }
}

extension Trait where Self == ConditionTrait {
    /// Run only with the Mac's Keyboard navigation setting on, by which buttons take focus: AppKit and SwiftUI read it
    /// themselves, and heed no stand-in for it in the process (`NSApplication.isFullKeyboardAccessEnabled` overridden,
    /// `AppleKeyboardUIMode` in the argument domain, tried 16 November 2026).
    fileprivate static var keyboardNavigationIsOn: Self {
        .enabled("Keyboard navigation is off on this Mac") {
            await MainActor.run { NSApplication.shared.isFullKeyboardAccessEnabled }
        }
    }
}
