import AppKit
@testable import SitRep
import Testing

/// A window of SitRep's own goes to the Space Lee is on only while SitRep brings it forward. Never shown, nor SitRep
/// activated: each step `comeForward()` takes is recorded with whether the window moves to the active Space then.
@MainActor
struct ForwardWindowTests {
    @Test func atRestItStaysOnItsOwnSpace() {
        #expect(!Recorded.made().movesToActiveSpace)
    }

    /// The proven order: front first, on Lee's Space, then SitRep activates.
    @Test func itOrdersFrontOnLeesSpaceThenActivates() {
        let window = Recorded.made()

        window.comeForward()

        #expect(window.steps == [.orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true)])
    }

    @Test func minimisedItComesOutOfTheDockOnLeesSpaceBeforeOrderingFront() {
        let window = Recorded.made()

        window.isMinimised = true
        window.comeForward()

        #expect(window.steps.first == .deminiaturize(movesToActiveSpace: true))
        #expect(window.steps.dropFirst().first == .orderFront(movesToActiveSpace: true))
    }

    /// SitRep inactive, the window is keyed only as the activation lands, so it moves with Lee till then.
    @Test func itKeepsToLeesSpaceTillTheActivationKeysIt() {
        let window = Recorded.made()

        window.comeForward()
        #expect(window.movesToActiveSpace)

        window.becomeKey()
        #expect(!window.movesToActiveSpace)
    }

    /// SitRep already active, the window is keyed as it orders front, so it keeps to its Space at once.
    @Test func keyedAsItOrdersFrontItKeepsToItsSpaceOnceForward() {
        let window = Recorded.made()

        window.keysAsItOrders = true
        window.comeForward()

        #expect(!window.movesToActiveSpace)
    }

    /// AppKit may key it before ordering it front, when it is not yet on Lee's Space.
    @Test func keyedBeforeItOrdersFrontItStillOrdersFrontOnLeesSpace() {
        let window = Recorded.made()

        window.keysBeforeOrdering = true
        window.comeForward()

        #expect(window.steps.first == .orderFront(movesToActiveSpace: true))
        #expect(window.steps.last == .activate(movesToActiveSpace: true))
        #expect(!window.movesToActiveSpace)
    }

    @Test func alreadyKeyItKeepsToItsSpaceOnceForward() {
        let window = Recorded.made()

        window.isKey = true
        window.comeForward()

        #expect(!window.movesToActiveSpace)
    }

    /// Clicking a macOS notification activates SitRep, which keys the window without SitRep bringing it forward: it
    /// stays on its own Space, and is not ordered front.
    @Test func keyedByAnActivationOfItsOwnItStaysOnItsSpace() {
        let window = Recorded.made()

        window.becomeKey()

        #expect(!window.movesToActiveSpace)
        #expect(window.steps.isEmpty)
    }

    @Test func broughtForwardAgainItMovesToLeesSpaceAgain() {
        let window = Recorded.made()

        window.comeForward()
        window.becomeKey()
        window.steps = []
        window.comeForward()

        #expect(window.steps == [.orderFront(movesToActiveSpace: true), .activate(movesToActiveSpace: true)])
    }
}

/// A window whose steps are recorded rather than taken: it is never ordered front, and SitRep never activates.
@MainActor
private final class Recorded: ForwardWindow {
    enum Step: Equatable {
        case deminiaturize(movesToActiveSpace: Bool)
        case orderFront(movesToActiveSpace: Bool)
        case activate(movesToActiveSpace: Bool)
    }

    var steps: [Step] = []
    var isKey = false
    var isMinimised = false
    /// Keyed as it orders front, as AppKit does while SitRep is active.
    var keysAsItOrders = false
    /// Keyed within the order front, before it is ordered.
    var keysBeforeOrdering = false

    static func made() -> Recorded {
        Recorded(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
    }

    var movesToActiveSpace: Bool { collectionBehavior.contains(.moveToActiveSpace) }

    override var isKeyWindow: Bool { isKey }
    override var isMiniaturized: Bool { isMinimised }

    override func deminiaturize(_ sender: Any?) {
        steps.append(.deminiaturize(movesToActiveSpace: movesToActiveSpace))
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        if keysBeforeOrdering {
            key()
        }
        steps.append(.orderFront(movesToActiveSpace: movesToActiveSpace))
        if keysAsItOrders {
            key()
        }
    }

    override func activateApp() {
        steps.append(.activate(movesToActiveSpace: movesToActiveSpace))
    }

    private func key() {
        isKey = true
        becomeKey()
    }
}
