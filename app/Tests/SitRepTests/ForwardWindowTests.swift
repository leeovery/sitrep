import AppKit
@testable import SitRep
import Testing

/// A window of SitRep's own goes to the Space Lee is on only while SitRep brings it forward. Never shown, nor SitRep
/// activated: each step `comeForward()` takes is recorded with whether the window moves to the active Space then.
@MainActor
struct ForwardWindowTests {
    /// What macOS posts as Lee changes Space, posted in this process alone.
    private static func changeSpace() {
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    /// The proven order: front first, on Lee's Space, then SitRep activates.
    @Test func itOrdersFrontOnLeesSpaceThenActivates() {
        let window = RecordedWindow.made()

        window.comeForward()

        #expect(window.steps == [.orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true)])
    }

    @Test func minimisedItComesOutOfTheDockOnLeesSpaceBeforeOrderingFront() {
        let window = RecordedWindow.made()

        window.isMinimised = true
        window.comeForward()

        #expect(window.steps.first == .deminiaturize(movesToActiveSpace: true))
        #expect(window.steps.dropFirst().first == .orderFront(movesToActiveSpace: true))
    }

    /// SitRep inactive, the window is keyed only as the activation lands, so it moves with Lee till then.
    @Test func itKeepsToLeesSpaceTillTheActivationKeysIt() {
        let window = RecordedWindow.made()

        window.comeForward()
        #expect(window.movesToActiveSpace)

        window.becomeKey()
        #expect(!window.movesToActiveSpace)
    }

    /// SitRep already active, the window is keyed as it orders front, so it keeps to its Space at once.
    @Test func keyedAsItOrdersFrontItKeepsToItsSpaceOnceForward() {
        let window = RecordedWindow.made()

        window.keysAsItOrders = true
        window.comeForward()

        #expect(!window.movesToActiveSpace)
    }

    /// AppKit may key it before ordering it front, when it is not yet on Lee's Space.
    @Test func keyedBeforeItOrdersFrontItStillOrdersFrontOnLeesSpace() {
        let window = RecordedWindow.made()

        window.keysBeforeOrdering = true
        window.comeForward()

        #expect(window.steps.first == .orderFront(movesToActiveSpace: true))
        #expect(window.steps.last == .activate(movesToActiveSpace: true))
        #expect(!window.movesToActiveSpace)
    }

    /// AppKit may key it as it comes out of the Dock, before it orders front.
    @Test func keyedAsItRestoresItStillOrdersFrontOnLeesSpace() {
        let window = RecordedWindow.made()

        window.isMinimised = true
        window.keysAsItRestores = true
        window.comeForward()

        #expect(window.steps.dropFirst().first == .orderFront(movesToActiveSpace: true))
        #expect(!window.movesToActiveSpace)
    }

    /// The activation declined, or About SitRep keyed instead, the window is on Lee's Space and never keyed: it keeps
    /// to that Space once he leaves it, so the next notification's click moves it nowhere.
    @Test func neverKeyedItKeepsToItsSpaceOnceLeeChangesSpace() {
        let window = RecordedWindow.made()

        window.comeForward()
        #expect(window.movesToActiveSpace)

        Self.changeSpace()
        #expect(!window.movesToActiveSpace)
    }

    @Test func broughtForwardAgainAfterAChangeOfSpaceItKeepsToItsSpaceAtTheNext() {
        let window = RecordedWindow.made()

        window.comeForward()
        Self.changeSpace()
        window.comeForward()
        #expect(window.movesToActiveSpace)

        Self.changeSpace()
        #expect(!window.movesToActiveSpace)
    }

    @Test func alreadyKeyItKeepsToItsSpaceOnceForward() {
        let window = RecordedWindow.made()

        window.isKey = true
        window.comeForward()

        #expect(!window.movesToActiveSpace)
    }

    @Test func broughtForwardAgainItMovesToLeesSpaceAgain() {
        let window = RecordedWindow.made()

        window.comeForward()
        window.becomeKey()
        window.steps = []
        window.comeForward()

        #expect(window.steps == [.orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true)])
    }
}
