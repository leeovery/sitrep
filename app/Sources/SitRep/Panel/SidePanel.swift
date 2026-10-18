import AppKit

/// The side panel's window: a clear, borderless panel against the screen's edge, over the menu bar, on every Space.
/// It never takes the keyboard: borderless, it can't become key, and non-activating, a click on it never activates
/// SitRep, so Lee's keys stay with the window that had them.
@MainActor
final class SidePanel: NSPanel {
    /// Over full-screen apps too, as the notch is; the strip steps aside while an app is full screen: without
    /// `.fullScreenAuxiliary` it is on every ordinary Space but not on a full-screen app's.
    init(frame: CGRect, view: NSView, overFullScreen: Bool = true) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if overFullScreen {
            collectionBehavior.insert(.fullScreenAuxiliary)
        }
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        contentView = view
    }
}
