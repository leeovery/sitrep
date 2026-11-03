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
    var isMinimised = false
    /// Keyed as it orders front, as AppKit does while SitRep is active.
    var keysAsItOrders = false
    /// Focus given to the first of its key views as it orders front, as AppKit gives it with the Mac's Keyboard
    /// navigation on, where no view was made its initial first responder.
    var focusesAsItOrders = false

    static func made() -> RecordedWindow {
        let window = RecordedWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)

        window.isReleasedWhenClosed = false
        return window
    }

    var movesToActiveSpace: Bool { collectionBehavior.contains(.moveToActiveSpace) }

    override var isMiniaturized: Bool { isMinimised }

    override func deminiaturize(_ sender: Any?) {
        steps.append(.deminiaturize(movesToActiveSpace: movesToActiveSpace))
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        steps.append(.orderFront(movesToActiveSpace: movesToActiveSpace))
        if keysAsItOrders {
            becomeKey()
        }
        if focusesAsItOrders, let content = contentView {
            content.layoutSubtreeIfNeeded()
            recalculateKeyViewLoop()
            selectKeyView(following: content)
        }
    }

    override func activateApp() {
        steps.append(.activate(movesToActiveSpace: movesToActiveSpace))
    }
}
