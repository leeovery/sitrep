import AppKit

/// An edge's window: a clear, borderless panel against the screen's edge, over the menu bar, on every Space, taken
/// off the screen while a full-screen app has its display. It never takes the keyboard: borderless, it can't become
/// key, and non-activating, a click on it never activates SitRep, so Lee's keys stay with the window that had them.
/// Clicks pass through it but over the shape.
@MainActor
final class EdgeWindow: NSPanel {
    init(frame: CGRect, view: NSView) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        contentView = view
    }
}
