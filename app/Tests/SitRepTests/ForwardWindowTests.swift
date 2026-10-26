import AppKit
@testable import SitRep
import Testing

/// A window of SitRep's own goes to the Space Lee is on from when SitRep brings it forward until Lee next changes Space.
/// Never shown, nor SitRep activated: each step `comeForward()` takes is recorded with whether the window moves to the
/// active Space then.
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

    /// Cleared as the activation keyed it, macOS took Lee to the window's last Space all the same.
    @Test func keyedAsTheActivationLandsItStillMovesToLeesSpace() {
        let window = RecordedWindow.made()

        window.comeForward()
        window.becomeKey()

        #expect(window.movesToActiveSpace)
    }

    @Test func keyedAsItOrdersFrontItStillMovesToLeesSpace() {
        let window = RecordedWindow.made()

        window.keysAsItOrders = true
        window.comeForward()

        #expect(window.movesToActiveSpace)
    }

    /// Once Lee leaves its Space, the next notification's click moves it nowhere.
    @Test func itKeepsToItsSpaceOnceLeeChangesSpace() {
        let window = RecordedWindow.made()

        window.comeForward()
        Self.changeSpace()

        #expect(!window.movesToActiveSpace)
    }

    @Test func broughtForwardAgainItMovesToLeesSpaceAgainTillTheNextChange() {
        let window = RecordedWindow.made()

        window.comeForward()
        Self.changeSpace()
        window.steps = []
        window.comeForward()
        #expect(window.steps == [.orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true)])

        Self.changeSpace()
        #expect(!window.movesToActiveSpace)
    }

    /// Closed by its red light on one Space and opened again from another, it opens on Lee's.
    @Test func closedAndBroughtForwardAgainItMovesToLeesSpace() {
        let window = RecordedWindow.made()

        window.comeForward()
        window.close()
        Self.changeSpace()
        window.steps = []
        window.comeForward()

        #expect(window.steps == [.orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true)])
    }
}
