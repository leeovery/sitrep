import AppKit
import SwiftUI

/// The page's whole visible area, behind it, as AppKit knows the pointer over it: the page is held while it is, so a
/// closed ask keeps its place and nothing below it moves under the pointer (`WindowRun.pointer(overPage:from:at:)`).
/// It is the column's viewport, not what scrolls in it, and every page's, so a pick under a still pointer keeps it.
struct PagePointer: NSViewRepresentable {
    func makeNSView(context: Context) -> PagePointerView {
        let view = PagePointerView()

        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: PagePointerView, context: Context) {
        let act = context.environment.windowActions
        let region = ObjectIdentifier(view)

        view.told = { act.pointerOverPage($0, region) }
    }
}

/// Where the pointer is, told from AppKit's tracking, which hears the pointer cross in or out whether or not SitRep is
/// active; and found by asking the window where the pointer is as the view moves into it, as the window becomes key,
/// comes back from the Dock or shows again, and as a menu closes, when AppKit sends no entry for a pointer that has
/// not moved. Out of its window, or its window out of sight, the pointer is over it no longer. What it tells, it tells
/// after AppKit's change, never inside one of SwiftUI's updates.
final class PagePointerView: NSView {
    var told: @MainActor @Sendable (Bool) -> Void = { _ in }
    /// Where the pointer is in a window's coordinates: the window's word, unless a test gives one.
    var pointer: (NSWindow) -> NSPoint = { $0.mouseLocationOutsideOfEventStream }

    /// What its window posts that has it find the pointer.
    private static let windowAsks = [NSWindow.didBecomeKeyNotification, NSWindow.didDeminiaturizeNotification]
    private static let heard = windowAsks + [
        NSWindow.didChangeOcclusionStateNotification, NSMenu.didEndTrackingNotification,
    ]

    override init(frame: NSRect) {
        super.init(frame: frame)
        // Unclipped, a view's visible rect, and its tracking area with it, runs past its bounds into its superview's.
        clipsToBounds = true
        // Once: `inVisibleRect` follows its bounds, and an area added again with the pointer inside hears no entry.
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self
        ))
    }

    required init?(coder: NSCoder) {
        nil
    }

    /// Behind the page, it takes no press.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func mouseEntered(with event: NSEvent) {
        tell(true)
    }

    override func mouseExited(with event: NSEvent) {
        tell(false)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        for name in Self.heard {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }
        guard let window else {
            return tell(false)
        }

        let center = NotificationCenter.default

        for name in Self.windowAsks {
            center.addObserver(self, selector: #selector(asked), name: name, object: window)
        }
        center.addObserver(
            self, selector: #selector(windowChangedOcclusion), name: NSWindow.didChangeOcclusionStateNotification,
            object: window
        )
        // Any menu's, as a card's Snooze menu is no window's: the pointer may have left for it, and back from it, a
        // pointer that has not moved since the menu closed sends no entry.
        center.addObserver(self, selector: #selector(asked), name: NSMenu.didEndTrackingNotification, object: nil)
        findPointer()
    }

    @objc private func asked(_ notification: Notification) {
        findPointer()
    }

    /// Out of sight, as on another Space, its window sends no exit: the pointer is over it no longer, until it shows
    /// again.
    @objc private func windowChangedOcclusion(_ notification: Notification) {
        if window?.occlusionState.contains(.visible) == true {
            findPointer()
        } else {
            tell(false)
        }
    }

    /// Whether the pointer is over what of it shows, asked once the change under way has laid it out.
    private func findPointer() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window else {
                return
            }
            told(visibleRect.contains(convert(pointer(window), from: nil)))
        }
    }

    /// Told through what it tells to, not through the view, so the out of a view freed meanwhile still comes.
    private func tell(_ isOver: Bool) {
        let told = told

        DispatchQueue.main.async {
            told(isOver)
        }
    }
}
