import AppKit
@testable import SitRep

/// A window whose steps are recorded rather than taken: it is never ordered front, and SitRep never activates.
@MainActor
final class RecordedWindow: ForwardWindow {
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
    /// Keyed as it comes out of the Dock.
    var keysAsItRestores = false

    static func made() -> RecordedWindow {
        RecordedWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
    }

    var movesToActiveSpace: Bool { collectionBehavior.contains(.moveToActiveSpace) }

    override var isKeyWindow: Bool { isKey }
    override var isMiniaturized: Bool { isMinimised }

    override func deminiaturize(_ sender: Any?) {
        steps.append(.deminiaturize(movesToActiveSpace: movesToActiveSpace))
        if keysAsItRestores {
            key()
        }
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
