import AppKit
@testable import SitRep

/// A window whose steps are recorded rather than taken: it is never ordered front, and SitRep never activates. It says
/// it is visible from its order front until it closes, and as it orders in from hidden, works out its key view loop, as
/// AppKit does for a window with no initial first responder.
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
    /// Focus given to the first of its key views as it orders in from hidden, as AppKit gives it with the Mac's
    /// Keyboard navigation on, where no view was made its initial first responder: only from the window itself or a
    /// view outside the key view loop, never from a key view that has it, nor as a window showing comes forward.
    var focusesAsItOrders = false
    private var isOrderedIn = false

    static func made() -> RecordedWindow {
        let window = RecordedWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)

        window.isReleasedWhenClosed = false
        return window
    }

    var movesToActiveSpace: Bool { collectionBehavior.contains(.moveToActiveSpace) }

    override var isMiniaturized: Bool { isMinimised }

    override var isVisible: Bool { isOrderedIn }

    override func deminiaturize(_ sender: Any?) {
        steps.append(.deminiaturize(movesToActiveSpace: movesToActiveSpace))
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        steps.append(.orderFront(movesToActiveSpace: movesToActiveSpace))
        if keysAsItOrders {
            becomeKey()
        }
        if !isOrderedIn {
            orderIn()
        }
    }

    private func orderIn() {
        isOrderedIn = true
        guard let content = contentView else {
            return
        }

        content.layoutSubtreeIfNeeded()
        recalculateKeyViewLoop()
        if focusesAsItOrders, (firstResponder as? NSView)?.canBecomeKeyView != true {
            selectKeyView(following: content)
        }
    }

    override func close() {
        isOrderedIn = false
        super.close()
    }

    override func activateApp() {
        steps.append(.activate(movesToActiveSpace: movesToActiveSpace))
    }
}
