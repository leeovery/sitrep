import AppKit

/// An edge's window: a clear, borderless panel against the screen's edge, over the menu bar, on every Space. The
/// notch's, the strip's and the caption's stay on the screen once made (`onScreen`), hidden while they don't show.
/// It never takes the keyboard: borderless, it can't become key, and non-activating, a click on it never activates
/// SitRep, so Lee's keys stay with the window that had them. Clicks pass through it but over the shape.
@MainActor
final class EdgeWindow: NSPanel {
    /// Whether it shows. Hidden, it is clear, every click goes through it, and what Core Animation turns and sweeps
    /// for its layers in the render server stands still. Shown, it is drawn whole, takes the clicks `takesClicks`
    /// says, and its layers keep the display's time again, so a turn or a sweep is where it would have got to.
    var isShown = true {
        didSet {
            guard isShown != oldValue else {
                return
            }

            // Clear rather than ordered out: proven live on 26 October 2026, ordered out and back in round a
            // full-screen Space, it came back on that one Space only.
            alphaValue = isShown ? 1 : 0
            letClicks()
            runsAnimations(isShown)
        }
    }

    /// Whether it takes the clicks over the shape, as the frame has it; hidden, it takes none.
    var takesClicks = false {
        didSet {
            letClicks()
        }
    }

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
        // SitRep hidden would order it out and back in as it unhides, the round trip that pins it to one Space.
        canHide = false
        letClicks()
        acceptsMouseMovedEvents = true
        view.wantsLayer = true
        contentView = view
    }

    /// The notch's, the strip's or the caption's window, on the screen from now on, hidden until it is shown, and
    /// never ordered out.
    static func onScreen(frame: CGRect, view: NSView) -> EdgeWindow {
        let window = EdgeWindow(frame: frame, view: view)

        window.isShown = false
        window.orderFrontRegardless()
        return window
    }

    private func letClicks() {
        ignoresMouseEvents = !(isShown && takesClicks)
    }

    /// The content's layers on the display's time, or held at this moment: a layer tree's animations stop with its
    /// speed (Apple's QA1673).
    private func runsAnimations(_ runs: Bool) {
        guard let layer = contentView?.layer else {
            return
        }

        layer.timeOffset = runs ? 0 : layer.convertTime(CACurrentMediaTime(), from: nil)
        layer.speed = runs ? 1 : 0
    }
}
