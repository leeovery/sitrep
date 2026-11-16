import AppKit
@testable import SitRep

/// A window whose steps are recorded rather than taken: it is never ordered front, and SitRep never activates. It says
/// it is visible from its order front until it closes, and as it orders in from hidden, works out its key view loop, as
/// AppKit does for a window with no initial first responder. It becomes key only as a test keys it, as SitRep's
/// activation keys a window only after it has ordered in, its delegate told as AppKit tells it. What it can't show is
/// SwiftUI's own focus, which moves no responder, nor Tab from the window itself, which a window never keyed for real
/// ignores: only a live run shows those. It hears of Space changes from a centre of its own, which only its test posts to.
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
    /// Keyboard navigation on, where no view was made its initial first responder; and with `focusesAsItKeys`, as it
    /// becomes key, before its delegate hears, as AppKit gave it to Skip setup in the window reused live, which this
    /// does on every key, as a worst case. Only from the window itself or a view outside the key view loop, never from
    /// a key view that has it, nor as a window showing comes forward.
    var focusesAsItOrders = false
    var focusesAsItKeys = false
    private var isOrderedIn = false

    static func made() -> RecordedWindow {
        let window = RecordedWindow(
            contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true, spaces: NotificationCenter()
        )

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

    /// `NSWindow`'s own tells the delegate.
    override func becomeKey() {
        if focusesAsItKeys {
            focusFirstKeyView()
        }
        super.becomeKey()
    }

    private func orderIn() {
        isOrderedIn = true
        contentView?.layoutSubtreeIfNeeded()
        recalculateKeyViewLoop()
        if focusesAsItOrders {
            focusFirstKeyView()
        }
    }

    private func focusFirstKeyView() {
        if let content = contentView, (firstResponder as? NSView)?.canBecomeKeyView != true {
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

extension NSViewController {
    /// A controller over this view, for a window made in a test.
    static func with(_ view: NSView) -> NSViewController {
        let controller = NSViewController()

        controller.view = view
        return controller
    }
}
