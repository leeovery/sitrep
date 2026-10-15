import AppKit

/// The side panel's window: a clear, borderless panel against the screen's edge, over the menu bar, on every Space
/// and over full-screen apps. It never activates SitRep, and takes the keys only when Lee clicks on it, so Esc
/// closes a panel he pinned; until then his keys stay where they were.
@MainActor
final class SidePanel: NSPanel {
    init(frame: CGRect, view: NSView) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        acceptsMouseMovedEvents = true
        contentView = view
    }

    /// A borderless window can't become key by default: this one can, but only a click on it makes it so.
    override var canBecomeKey: Bool { true }

    override var canBecomeMain: Bool { false }

    /// Hands the keys back to the app that had them before Lee clicked on the panel. AppKit has no call to resign
    /// key: ordered out, the panel stops being key and the active app's key window takes the keys again, the panel
    /// never having activated SitRep; ordered straight back in without being made key, it leaves them there.
    func giveBackKeys() {
        guard isKeyWindow else {
            return
        }

        orderOut(nil)
        orderFrontRegardless()
    }
}
