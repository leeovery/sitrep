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
/// and as it comes back from the Dock, when AppKit sends no entry for a pointer that has not moved. Out of its window,
/// the pointer is over it no longer. What it tells, it tells after AppKit's change, never inside one of SwiftUI's
/// updates.
final class PagePointerView: NSView {
    var told: (Bool) -> Void = { _ in }
    /// Where the pointer is in a window's coordinates: the window's word, unless a test gives one.
    var pointer: (NSWindow) -> NSPoint = { $0.mouseLocationOutsideOfEventStream }

    private static let asked = [NSWindow.didBecomeKeyNotification, NSWindow.didDeminiaturizeNotification]

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
        for name in Self.asked {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }
        guard let window else {
            return tell(false)
        }
        for name in Self.asked {
            NotificationCenter.default.addObserver(self, selector: #selector(windowAsked), name: name, object: window)
        }
        findPointer()
    }

    @objc private func windowAsked(_ notification: Notification) {
        findPointer()
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

    private func tell(_ isOver: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.told(isOver)
        }
    }
}
